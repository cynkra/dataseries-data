#!/usr/bin/env python3
"""Full upstream diff for the dataseries.org "fso-sdmx" datasets.

For every dataset: fetch the raw SDMX-CSV from disseminate.stats.swiss directly
(same key/slice the datasheet ## Access block names), normalise it to
(dimension codes, first-of-period date, value), download the FULL dataset from the
live API and compare every cell. The API meta levels are checked against the data
codes and the upstream SDMX codelists; labels are scanned for control characters.

Independent of the repo's R fetchers: the slice keys, NOGA keep-lists and the
code mappings (canton leading-zero strip, _U drop, redundant UNIT_MEASURE levels,
single-valued dims dropped) are re-stated here from the datasheets / pipeline.

Run: python verify/upstream/fso-sdmx.py [--only id1,id2]
Writes verify/out/verdicts/upstream-fso-sdmx.json.
"""
import io
import json
import re
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib  # noqa: E402

CHECK = "upstream-fso-sdmx"
SDMX = "https://disseminate.stats.swiss/rest"
CSV_ACCEPT = "application/vnd.sdmx.data+csv"
STRUCT_ACCEPT = "application/vnd.sdmx.structure+json"

RETAIL_NOGA = ["47", "4711", "4711_472", "4719", "4719_474-479", "472", "473", "474",
               "475", "476", "477", "478_479", "47P", "47P_Bekl", "47P_Food",
               "47P_Treib", "47P_UW", "47PxTreib", "47x473"]
PRODUCTION_NOGA = ["B-E", "B", "C", "D", "F", "41", "42", "43", "41_43"]
SERVICES_NOGA = ["G-NxK", "G", "H", "I", "J", "L", "M", "N"]


def keu(flow, noga, drop_units):
    def norm(raw):
        d = raw[raw["NOGA"].isin(noga)]
        d = d[~d["UNIT_MEASURE"].isin(drop_units)]
        return d[["NOGA", "ADJUSTMENT", "INDICATOR_KE", "UNIT_MEASURE", "TIME_PERIOD", "OBS_VALUE"]]
    return dict(agency="CH1.KEU", flow=flow, key="all", norm=norm,
                codelists={"NOGA": "CL_NOGA_KE", "ADJUSTMENT": "CL_SEASONAL_ADJUST",
                           "INDICATOR_KE": "CL_INDICATOR_KE",
                           "UNIT_MEASURE": "CL_PRICES_RESULT_TYPE"})


def nv(raw):
    d = raw.rename(columns={"UV_RV_FUEL": "fuel"})
    return d[["fuel", "TIME_PERIOD", "OBS_VALUE"]]


def nvc(raw):
    d = raw.rename(columns={"UV_HGDE_KT": "canton", "UV_RV_FUEL": "fuel"}).copy()
    d["canton"] = d["canton"].str.replace(r"^0+", "", regex=True)
    d = d[d["canton"] != "_U"]
    return d[["canton", "fuel", "TIME_PERIOD", "OBS_VALUE"]]


VAC_CODES = {"OBS": "V", "RATE": "PC"}


def vac(raw):
    d = raw[raw["MEASURE_DIMENSION"].isin(VAC_CODES)].copy()
    d["measure"] = d["MEASURE_DIMENSION"].map(VAC_CODES)
    return d[["measure", "TIME_PERIOD", "OBS_VALUE"]]


def gg(raw):
    return raw.rename(columns={"WORK_CANTON": "canton"})[["canton", "TIME_PERIOD", "OBS_VALUE"]]


def pop(raw):
    d = raw.rename(columns={"NATIONALITY_CATEGORY": "nationality", "SEX": "sex"})
    return d[["nationality", "sex", "TIME_PERIOD", "OBS_VALUE"]]


DATASETS = {
    "ch_fso_cross_border_commuters": dict(
        agency="CH1.GGS", flow="DF_GGS_1", key="_T._T.Q._T.", norm=gg,
        codelists={"canton": "WORK_CANTON"}),
    "ch_fso_new_vehicles": dict(
        agency="CH1.MFZ_IVS", flow="DF_IVS_0_GENERAL_M", key="_T._T.N.100..M", norm=nv,
        codelists={"fuel": "UV_RV_FUEL"}),
    "ch_fso_new_vehicles_canton": dict(
        agency="CH1.MFZ_IVS", flow="DF_IVS_0_GENERAL_M", key="._T.N.100..M", norm=nvc,
        codelists={"fuel": "UV_RV_FUEL", "canton": "UV_HGDE_KT"}),
    "ch_fso_pop_detail": dict(
        agency="CH1.STATPOP", flow="DF_STATPOP_REGLING_PERM", key="_T..._T.A", norm=pop,
        codelists={"nationality": "NATIONALITY_CATEGORY", "sex": "SEX"}),
    "ch_fso_production": keu("DF_KEU_Q1", PRODUCTION_NOGA, ["VARQ-4", "VARQ-1"]),
    "ch_fso_retail": keu("DF_KEU_M1", RETAIL_NOGA, ["VARM-12", "VARM-1"]),
    "ch_fso_services": keu("DF_KEU_Q1", SERVICES_NOGA, ["VARQ-4", "VARQ-1"]),
    "ch_fso_vacant_dwellings": dict(
        agency="CH1.LWZ", flow="DF_LWZ_1", version="1.1.0", key="8100._T._T..A", norm=vac,
        codelists={"measure": "MEASURE_DIMENSION"},
        recode={"measure": {v: k for k, v in VAC_CODES.items()}}),
}

_raw: dict[str, pd.DataFrame] = {}
_struct: dict[str, tuple] = {}


def sdmx_get(url, accept):
    return lib.get(url, timeout=300, headers={"Accept": accept})


def to_iso(p):
    p = str(p).strip()
    if re.fullmatch(r"\d{4}", p):
        return f"{p}-01-01"
    m = re.fullmatch(r"(\d{4})-(\d{2})", p)
    if m:
        return f"{m[1]}-{m[2]}-01"
    m = re.fullmatch(r"(\d{4})-Q([1-4])", p)
    if m:
        return f"{m[1]}-{(int(m[2]) - 1) * 3 + 1:02d}-01"
    m = re.fullmatch(r"(\d{4})-S([12])", p)
    if m:
        return f"{m[1]}-{'01' if m[2] == '1' else '07'}-01"
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", p):
        return p
    return None


def compare(up, api, dims):
    """Cell-by-cell comparison; returns (problems, lag_note, details)."""
    key = dims + ["date"]
    n_dup_up, n_dup_api = int(up.duplicated(key).sum()), int(api.duplicated(key).sum())
    if n_dup_up:
        raise RuntimeError(f"{n_dup_up} duplicate keys upstream after normalising (checker wrong?)")
    m = up.merge(api, on=key, how="outer", suffixes=("_up", "_api"), indicator=True)
    both = m[m["_merge"] == "both"].copy()
    only_up = m[m["_merge"] == "left_only"]
    only_api = m[m["_merge"] == "right_only"]
    latest_api = api["date"].max()
    newer = only_up[only_up["date"] > latest_api]
    missing = only_up[only_up["date"] <= latest_api]
    both["absdiff"] = (both["value_up"] - both["value_api"]).abs()
    tol = 1e-9 * both[["value_up", "value_api"]].abs().max(axis=1).clip(lower=1.0)
    mism = both[both["absdiff"] > tol].sort_values("absdiff", ascending=False)

    problems = []
    if len(mism):
        problems.append(f"{len(mism)} value mismatches")
    if len(missing):
        problems.append(f"{len(missing)} upstream rows missing from API within its date range")
    if len(only_api):
        problems.append(f"{len(only_api)} rows only in API")
    if n_dup_api:
        problems.append(f"{n_dup_api} duplicate keys in API")
    details = {
        "cells_compared": int(len(both)), "n_value_mismatch": int(len(mism)),
        "n_only_upstream": int(len(only_up)), "n_only_api": int(len(only_api)),
        "n_newer_upstream": int(len(newer)), "n_dup_api": n_dup_api,
        "latest_upstream": up["date"].max(), "latest_api": latest_api,
        "mismatch_examples": mism.head(5)[key + ["value_up", "value_api"]].to_dict("records"),
        "missing_examples": missing.head(5)[key + ["value_up"]].to_dict("records"),
        "only_api_examples": only_api.head(5)[key + ["value_api"]].to_dict("records"),
    }
    return problems, len(newer), details


def codelist_labels(doc):
    cls = {}
    for cl in doc["data"].get("codelists", []):
        cls[cl["id"]] = {c["id"]: (c.get("name") or (c.get("names") or {}).get("en") or c["id"])
                         for c in cl.get("codes", [])}
    dim2cl = {}
    for ds in doc["data"].get("dataStructures", []):
        for dd in ds["dataStructureComponents"]["dimensionList"]["dimensions"]:
            enum = (dd.get("localRepresentation") or {}).get("enumeration", "")
            m = re.search(r"Codelist=[^:]+:([^()]+)\(", enum)
            if m:
                dim2cl[dd["id"]] = m.group(1)
    return cls, dim2cl


C1_CONTROL = re.compile("[\u0080-\u009f]")


def check_meta(ds_id, cfg, api, meta):
    """Levels vs data codes, level codes vs upstream codelists, label hygiene.
    Level labels are curated in the datasheets, so English wording that differs
    from the upstream codelist is only counted, not failed."""
    url = f"{SDMX}/dataflow/{cfg['agency']}/{cfg['flow']}/{cfg.get('version', '1.0.0')}?references=all"
    if url not in _struct:
        _struct[url] = codelist_labels(json.loads(sdmx_get(url, STRUCT_ACCEPT).content))
    cls, dim2cl = _struct[url]
    problems, n_levels, n_reworded = [], 0, 0
    for d in [c for c in api.columns if c not in ("date", "value")]:
        levels = (meta.get("dimensions", {}).get(d) or {}).get("levels", {})
        missing = sorted(set(api[d]) - set(levels))
        if missing:
            problems.append(f"{d}: codes in data but not in meta: {missing[:5]}")
        src = cfg["codelists"].get(d, d)
        cl = cls.get(dim2cl.get(src, src), {})
        for code, ent in levels.items():
            up_code = cfg.get("recode", {}).get(d, {}).get(code, code)
            if ds_id == "ch_fso_new_vehicles_canton" and d == "canton" and code.isdigit():
                up_code = code.zfill(2) if code.zfill(2) in cl else code
            n_levels += 1
            labels = ent.get("label") or {}
            if not labels.get("en"):
                problems.append(f"{d}={code}: no English label")
            for lang, text in labels.items():
                if C1_CONTROL.search(text or ""):
                    problems.append(f"{d}={code}: control character in {lang} label {text!r}")
            if code in set(api[d]) and up_code not in cl:
                problems.append(f"{d}={code}: code not in upstream codelist")
            elif up_code in cl and not labels.get("en", "").casefold() in cl[up_code].casefold():
                n_reworded += 1
    return problems, n_levels, n_reworded


def check(ds_id):
    cfg = DATASETS[ds_id]
    url = f"{SDMX}/data/{cfg['agency']},{cfg['flow']},{cfg.get('version', '1.0.0')}/{cfg['key']}?detail=dataonly"
    if url not in _raw:
        _raw[url] = pd.read_csv(io.BytesIO(sdmx_get(url, CSV_ACCEPT).content),
                                dtype=str, keep_default_na=False)
    n = cfg["norm"](_raw[url]).copy()
    n["date"] = n["TIME_PERIOD"].map(to_iso)
    if n["date"].isna().any():
        raise RuntimeError(f"unparsed periods: {n[n['date'].isna()]['TIME_PERIOD'].unique()[:5].tolist()}")
    empty = n["OBS_VALUE"].str.strip().isin(["", "NaN", "NA", "nan"])
    n["value"] = pd.to_numeric(n["OBS_VALUE"].where(~empty), errors="coerce")
    n = n[n["value"].notna()].drop(columns=["TIME_PERIOD", "OBS_VALUE"])
    dims = [c for c in n.columns if c not in ("date", "value")]
    dims = [d for d in dims if n[d].nunique() > 1]
    up = n[dims + ["date", "value"]].reset_index(drop=True)

    api = lib.api_csv(ds_id)
    api_dims = [c for c in api.columns if c not in ("date", "value")]
    if sorted(api_dims) != sorted(dims):
        return "fail", f"dimensions differ: API {api_dims} vs upstream {dims}", {}
    n_api_empty = int(api["value"].isna().sum())
    api = api[api["value"].notna()]

    problems, n_newer, details = compare(up, api, dims)
    meta_problems, n_levels, n_reworded = check_meta(ds_id, cfg, api, lib.api_meta(ds_id))
    details.update(n_api_empty_values=n_api_empty, levels_checked=n_levels,
                   n_labels_reworded=n_reworded, n_meta_problems=len(meta_problems),
                   meta_problem_examples=meta_problems[:5])
    if meta_problems:
        problems.append(f"{len(meta_problems)} code/label problems in meta")
    cells = details["cells_compared"]
    if problems:
        return "fail", f"{cells} cells compared; " + "; ".join(problems), details
    if n_newer:
        return ("lag", f"{cells} cells match; upstream has {n_newer} newer rows "
                f"(upstream {details['latest_upstream']}, API {details['latest_api']})", details)
    return "ok", f"{cells} cells match upstream, {n_levels} levels checked (latest {details['latest_api']})", details


def main():
    only = lib.only_arg(sys.argv)
    verdicts = lib.Verdicts(CHECK)
    for ds_id in DATASETS:
        if only and ds_id not in only:
            continue
        print(f"== {ds_id}", file=sys.stderr, flush=True)
        verdicts.run(ds_id, lambda ds_id=ds_id: check(ds_id))
        v = verdicts.items[-1]
        print(f"   {v['status']}: {v['summary']}", file=sys.stderr, flush=True)
    print(f"wrote {verdicts.write()}", file=sys.stderr)


if __name__ == "__main__":
    main()
