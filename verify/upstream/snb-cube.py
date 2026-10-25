#!/usr/bin/env python3
"""Full upstream diff for the SNB cube datasets (source type "snb-cube").

For every ch_snb_* dataset this script
  1. fetches the raw cube from the endpoint in the datasheet's ## Access block
     (data.snb.ch /api/cube/{cube}/data/json/en), plus /dimensions/en (labels) and
     /lastUpdate (edition stamp);
  2. normalises it to (dimension codes, first-day-of-period date, value), applying
     ONLY the documented, intentional pipeline steps (null values dropped,
     REDUNDANT_LEVELS from R/pipeline.R removed, single-valued dims dropped, the
     devkum quote-unit label strip from R/labels.R);
  3. downloads the FULL dataset from the live API (/series.csv?dataset={id}) and its
     meta (/dataset/{id}/meta);
  4. compares every cell (rows only upstream / only API, value mismatches, duplicate
     keys) and the dimension codes and English labels;
  5. records one verdict per dataset in verify/out/verdicts/upstream-snb-cube.json.

It does not call any repo R code.

    python verify/upstream/snb-cube.py [--only id1,id2]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib  # noqa: E402

CHECK = "upstream-snb-cube"
SNB = "https://data.snb.ch/api/cube"

DATASETS = """ch_snb_amarbma ch_snb_ambeschkla ch_snb_ausshawarm ch_snb_auvekomq
ch_snb_auvercurrq ch_snb_auverdeptq ch_snb_auversecq ch_snb_babilpobm
ch_snb_bakredbetgrbm ch_snb_bakredinausbm ch_snb_bakredsekbm ch_snb_bopcapbalq
ch_snb_bopcurrq ch_snb_bopoverq ch_snb_bopservq ch_snb_capchstocki ch_snb_capweums
ch_snb_devkum ch_snb_devwkibiim ch_snb_devwkieffid ch_snb_plimoinchq ch_snb_plkopr
ch_snb_plkoprinfla ch_snb_rendeiduebd ch_snb_snbbipo ch_snb_snbiprogq ch_snb_snbkosiq
ch_snb_snbmoba ch_snb_snbmonagg ch_snb_snboffzisa ch_snb_zavegelade ch_snb_zavesic
ch_snb_zavezaka ch_snb_zavezaluba ch_snb_zavkuzaart ch_snb_zikredlauf ch_snb_zikrepro
ch_snb_zimoma""".split()

# Intentional build-time drops, copied from REDUNDANT_LEVELS in R/pipeline.R
# (transform levels the app recomputes on the fly).
REDUNDANT_LEVELS = {
    "ch_snb_devwkibiim": {"D2": ["V"]},
    "ch_snb_devwkieffid": {"D2": ["V"]},
    "ch_snb_snbmonagg": {"D0": ["VV"]},
    "ch_snb_plkopr": {"D0": ["VVP"]},
    "ch_snb_ausshawarm": {"D2": ["N"]},
}

# Intentional label cleanup, mirrors .SNB_LABEL_STRIP / LABEL_NOISE$quote_unit
# in R/pipeline.R and R/labels.R: the quotation unit moves into the level units.
QUOTE_UNIT_RULES = [(r"^(.+\S)\s+([A-Z]{3})\s+–\s+[0-9]+(\.-)?$", r"\1 – \2"),
                    (r"\s+[0-9]+(\.-)?$", "")]
LABEL_STRIP = {"ch_snb_devkum": QUOTE_UNIT_RULES}

REL_TOL = 1e-9
MAX_EXAMPLES = 5
ISO_DATE = r"\d{4}-\d{2}-\d{2}"


def access_endpoint(ds_id: str) -> tuple[str, str]:
    """Cube and endpoint from the datasheet ## Access block (fallback: the standard cube URL)."""
    cube = ds_id.removeprefix("ch_snb_")
    sheet = (lib.ROOT / "datasets" / f"{ds_id}.md").read_text(encoding="utf-8")
    m = re.search(r"^## Access\s*\n(.*?)(?=^## )", sheet, re.S | re.M)
    block = m.group(1) if m else ""
    cm = re.search(r"\*\*cube\*\*:\s*`([^`]+)`", block)
    if cm:
        cube = cm.group(1)
    em = re.search(r"\*\*endpoint\*\*:\s*`(https?://[^`]+)`", block)
    return cube, em.group(1) if em else f"{SNB}/{cube}/data/json/en"


def to_iso(period: str) -> str:
    p = period.strip()
    if re.fullmatch(ISO_DATE, p):
        return p
    m = re.fullmatch(r"(\d{4})-?Q([1-4])", p)
    if m:
        return f"{m.group(1)}-{(int(m.group(2)) - 1) * 3 + 1:02d}-01"
    if re.fullmatch(r"\d{4}-\d{2}", p):
        return f"{p}-01"
    m = re.fullmatch(r"(\d{4})-?H([12])", p)
    if m:
        return f"{m.group(1)}-{'01' if m.group(2) == '1' else '07'}-01"
    if re.fullmatch(r"\d{4}", p):
        return f"{p}-01-01"
    raise ValueError(f"unrecognised period {period!r}")


def key_codes(key: str) -> list[str]:
    m = re.search(r"\{([^}]*)\}", key or "")
    return m.group(1).split(",") if m and m.group(1) else []


def flatten_items(items, out=None):
    out = {} if out is None else out
    for it in items or []:
        out[it["id"]] = it.get("name")
        flatten_items(it.get("dimensionItems"), out)
    return out


def num(x) -> float:
    if x is None:
        return np.nan
    if isinstance(x, (int, float)):
        return float(x)
    s = str(x).strip()
    return np.nan if s in ("", "NA", "NaN", "null") else float(s)


def strip_label(label: str | None, rules) -> str | None:
    if label is None:
        return None
    for pattern, repl in rules:
        label = re.sub(pattern, repl, label)
    return label


def upstream_frame(up_doc: dict, dim_ids: list[str]) -> tuple[pd.DataFrame, list[str]]:
    codes_rows, dates, values = [], [], []
    for ts in up_doc.get("timeseries", []):
        codes = key_codes(ts.get("metadata", {}).get("key", ""))
        if dim_ids and len(codes) != len(dim_ids):
            raise ValueError(f"series key {codes} does not match dimensions {dim_ids}")
        for obs in ts.get("values", []):
            v = num(obs.get("value"))
            if np.isnan(v):
                continue
            codes_rows.append(codes)
            dates.append(to_iso(obs["date"]))
            values.append(v)
    if not dim_ids and codes_rows:
        dim_ids = [f"D{i}" for i in range(len(codes_rows[0]))]
    df = pd.DataFrame(codes_rows, columns=dim_ids, dtype=object)
    df["date"] = dates
    df["value"] = np.array(values, dtype=float)
    return df, dim_ids


def compare_cells(up: pd.DataFrame, api: pd.DataFrame, key: list[str]) -> dict:
    m = up.merge(api, on=key, how="outer", suffixes=("_up", "_api"), indicator=True)
    both = m[m["_merge"] == "both"]
    a, b = both["value_up"].to_numpy(), both["value_api"].to_numpy()
    nan_differs = np.isnan(a) != np.isnan(b)
    with np.errstate(invalid="ignore"):
        off = (a != b) & ~np.isclose(a, b, rtol=REL_TOL, atol=REL_TOL)
    bad = both[nan_differs | off].copy()
    bad["abs_diff"] = (bad["value_up"] - bad["value_api"]).abs()
    bad = bad.sort_values("abs_diff", ascending=False, na_position="first")
    return {"cells_compared": len(both),
            "only_up": m[m["_merge"] == "left_only"],
            "only_api": m[m["_merge"] == "right_only"],
            "mismatches": bad}


def label_problems(meta: dict, dim_names: dict, dim_items: dict, api_codes: dict,
                   up_dims: list[str], dropped: dict, strip) -> list[str]:
    problems = []
    mdims = meta.get("dimensions", {}) or {}
    for dn in up_dims:
        md = mdims.get(dn)
        if md is None:
            problems.append(f"dimension {dn} missing from API meta")
            continue
        api_name = (md.get("label") or {}).get("en")
        up_name = dim_names.get(dn)
        if up_name and api_name and up_name.strip() != api_name.strip():
            problems.append(f"dimension {dn} label: upstream {up_name!r} vs API {api_name!r}")
        levels = md.get("levels", {}) or {}
        for code, name in dim_items.get(dn, {}).items():
            if code in dropped.get(dn, []):
                continue
            if code not in levels:
                problems.append(f"{dn} code {code!r} ({name!r}) missing from API meta levels")
                continue
            api_label = (levels[code].get("label") or {}).get("en")
            name = strip_label(name, strip) if strip else name
            if name and api_label and name.strip() != api_label.strip():
                problems.append(f"{dn} code {code!r} label: upstream {name!r} vs API {api_label!r}")
        for code in levels:
            if code not in dim_items.get(dn, {}):
                problems.append(f"{dn} code {code!r} in API meta but not upstream")
        for code in api_codes.get(dn, set()) - set(levels):
            problems.append(f"{dn} code {code!r} in API data but not in meta levels")
    return problems


def check(ds_id: str):
    cube, endpoint = access_endpoint(ds_id)
    lu_doc = lib.get(f"{SNB}/{cube}/lastUpdate", timeout=30).json()
    dims_doc = lib.get(f"{SNB}/{cube}/dimensions/en").json()
    up_doc = lib.get(endpoint, timeout=180).json()
    api_df = lib.api_csv(ds_id)
    meta = lib.api_meta(ds_id)

    dims = dims_doc.get("dimensions", [])
    dim_ids = [d["id"] for d in dims]
    dim_names = {d["id"]: d.get("name") for d in dims}
    dim_items = {d["id"]: flatten_items(d.get("dimensionItems")) for d in dims}

    up, dim_ids = upstream_frame(up_doc, dim_ids)
    spec = REDUNDANT_LEVELS.get(ds_id, {})
    for dn, codes in spec.items():
        up = up[~up[dn].isin(codes)]
    keep = [d for d in dim_ids if up[d].nunique() > 1]
    up = up[keep + ["date", "value"]]

    if list(api_df.columns[-2:]) != ["date", "value"]:
        raise ValueError(f"unexpected API header {list(api_df.columns)}")
    api_dims = list(api_df.columns[:-2])
    problems = []
    if set(api_dims) != set(keep):
        problems.append(f"dimension columns differ: API {api_dims} vs upstream {keep}")
    common = [d for d in keep if d in api_dims]
    key = common + ["date"]

    if not api_df["date"].str.fullmatch(ISO_DATE).all():
        problems.append("API has dates that are not YYYY-MM-DD")
    n_dup_up = int(up.duplicated(key).sum())
    n_dup_api = int(api_df.duplicated(key).sum())
    if n_dup_up:
        problems.append(f"{n_dup_up} duplicate upstream keys")
    if n_dup_api:
        problems.append(f"{n_dup_api} duplicate API keys")

    cmp = compare_cells(up[key + ["value"]].drop_duplicates(key, keep="last"),
                        api_df[key + ["value"]].drop_duplicates(key, keep="last"), key)
    latest_up = up["date"].max()
    latest_api = api_df["date"].max()
    only_up, only_api, mism = cmp["only_up"], cmp["only_api"], cmp["mismatches"]
    missing = only_up[only_up["date"] <= latest_api]
    newer = only_up[only_up["date"] > latest_api]

    if len(mism):
        problems.append(f"{len(mism)} value mismatches")
    if len(missing):
        problems.append(f"{len(missing)} upstream rows missing from the API within its date range")
    if len(only_api):
        problems.append(f"{len(only_api)} API rows not in upstream")

    api_codes = {d: set(api_df[d]) for d in api_dims}
    problems += label_problems(meta, dim_names, dim_items, api_codes, keep, spec,
                               LABEL_STRIP.get(ds_id))

    edition = lu_doc.get("editionDate")
    edition_fmt = None
    if edition and re.fullmatch(r"\d{8}_\d{4}", edition):
        edition_fmt = f"{edition[0:4]}-{edition[4:6]}-{edition[6:8]} {edition[9:11]}:{edition[11:13]}"

    examples = [{**{k: r[k] for k in key}, "upstream": r["value_up"], "api": r["value_api"]}
                for _, r in mism.head(MAX_EXAMPLES).iterrows()]
    details = {"cells_compared": cmp["cells_compared"], "n_value_mismatch": len(mism),
               "n_only_upstream": len(only_up), "n_missing_in_api_range": len(missing),
               "n_newer_than_api": len(newer), "n_only_api": len(only_api),
               "n_dup_upstream": n_dup_up, "n_dup_api": n_dup_api,
               "latest_upstream": latest_up, "latest_api": latest_api,
               "upstream_edition": edition_fmt, "api_updated": meta.get("updated"),
               "mismatch_examples": examples, "problems": problems[:20]}
    if problems:
        return "fail", "; ".join(problems[:3])[:300], details
    if len(newer):
        return ("lag", f"upstream has {len(newer)} rows after the API's latest {latest_api} "
                       f"(upstream latest {latest_up})", details)
    return "ok", f"{cmp['cells_compared']} cells match; latest {latest_api}", details


def main(argv: list[str]) -> None:
    only = lib.only_arg(argv)
    verdicts = lib.Verdicts(CHECK)
    for ds in DATASETS:
        if only is not None and ds not in only:
            continue
        verdicts.run(ds, lambda ds=ds: check(ds))
        v = verdicts.items[-1]
        print(f"{ds:24s} {v['status']:12s} {v['summary']}", flush=True)
    print("wrote", verdicts.write())


if __name__ == "__main__":
    main(sys.argv[1:])
