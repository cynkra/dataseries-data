#!/usr/bin/env python3
"""Full upstream diff for source type "fso-pxweb".

For each dataset: fetch the PX-Web cube directly (json-stat2 POST, chunked under the
5000-cell cap), normalise to (dim codes, first-of-period date, value), download the
full dataset from the live API, compare every cell, and check the level labels
(en/de/fr/it) of the API meta against the upstream valueTexts.

Independent of the repo's R fetchers: the queries below mirror R/pipeline.R only in
*what* they select (that is the dataset definition), not in how they are executed.

Run: python verify/upstream/fso-pxweb.py [--only id1,id2]
Writes verify/out/verdicts/upstream-fso-pxweb.json.
"""
import json
import math
import re
import sys
import unicodedata
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib  # noqa: E402

CHECK = "upstream-fso-pxweb"
PX = "https://www.pxweb.bfs.admin.ch/api/v1/{lang}/{t}/{t}.px"
CELL_CAP = 4500


# --------------------------------------------------------------------------- datasets
# selection: dim code -> list of item codes, or "*" for all. Dims not mentioned are
# eliminated by PX-Web (the source's own ELIMINATION level).
DATASETS = {
    "ch_fso_besta_outlook": dict(
        table="px-x-0602000000_105",
        select={"Wirtschaftsabteilung": "*",
                "Voraussichtliche Beschäftigungsentwicklung": ["5"],
                "Gewichtung": ["1"], "Quartal": "*"},
        time=("quarter", "Quartal"), noga="Wirtschaftsabteilung"),
    "ch_fso_hesta": dict(
        table="px-x-1003020000_103",
        select={"Jahr": "*", "Monat": [str(i) for i in range(1, 13)],
                "Tourismusregion": "*", "Indikator": ["2"]},
        time=("month", "Jahr", "Monat"), noga=None),
    "ch_fso_jobs_sex": dict(
        table="px-x-0602000000_102", select="auto",
        time=("quarter", "Quartal"), noga=None),
    "ch_fso_vacancies": dict(
        table="px-x-0602000000_103", select="auto",
        time=("quarter", "Quartal"), noga="Wirtschaftsabteilung"),
}


def px_meta(table, lang="en"):
    r = lib.get(PX.format(lang=lang, t=table), timeout=120)
    r.encoding = "utf-8"
    return r.json()


def parse_jsonstat(doc):
    ids = doc["id"]
    sizes = doc["size"]
    codes = []
    for d in ids:
        idx = doc["dimension"][d]["category"]["index"]
        if isinstance(idx, dict):
            codes.append([k for k, _ in sorted(idx.items(), key=lambda kv: kv[1])])
        else:
            codes.append(list(idx))
    assert [len(c) for c in codes] == sizes, "size mismatch"
    vals = doc["value"]
    status = doc.get("status") or {}
    if isinstance(vals, dict):  # sparse form
        n = math.prod(sizes)
        dense = [None] * n
        for k, v in vals.items():
            dense[int(k)] = v
        vals = dense
    if isinstance(status, list):
        status = {str(i): s for i, s in enumerate(status) if s}
    idx = pd.MultiIndex.from_product(codes, names=ids)
    df = idx.to_frame(index=False)
    df["value"] = pd.to_numeric(pd.Series(vals, dtype=object), errors="coerce")
    df["status"] = [status.get(str(i)) for i in range(len(df))] if status else None
    return df


def fetch_upstream(cfg):
    t = cfg["table"]
    meta = px_meta(t, "en")
    vars_ = {v["code"]: v for v in meta["variables"]}
    sel = cfg["select"]
    if sel == "auto":
        sel = {c: "*" for c in vars_}
    resolved = {c: list(vars_[c]["values"]) if s == "*" else list(s) for c, s in sel.items()}
    chunk_dim = cfg["time"][1]
    per_period = math.prod(len(v) for c, v in resolved.items() if c != chunk_dim)
    chunk_size = max(1, CELL_CAP // per_period)
    allv = resolved[chunk_dim]
    parts = []
    for i in range(0, len(allv), chunk_size):
        q = [{"code": c, "selection": {"filter": "item",
                                       "values": v[i:i + chunk_size] if c == chunk_dim else v}}
             for c, v in resolved.items()]
        r = lib.post(PX.format(lang="en", t=t), timeout=120,
                     json={"query": q, "response": {"format": "json-stat2"}})
        parts.append(parse_jsonstat(json.loads(r.content.decode("utf-8", errors="replace"))))
    return meta, vars_, resolved, pd.concat(parts, ignore_index=True)


def to_date(df, timecfg):
    kind = timecfg[0]
    if kind == "quarter":
        q = df[timecfg[1]].astype(str)
        m = re.compile(r"^(\d{4})Q([1-4])$")
        ok = q.str.match(m)
        yr = q.str[:4]
        mo = ((q.str[5:6].where(ok, "1").astype(int) - 1) * 3 + 1)
        d = pd.to_datetime(yr + "-" + mo.map("{:02d}".format) + "-01", errors="coerce")
        d[~ok] = pd.NaT
    else:
        y, mth = df[timecfg[1]].astype(str), df[timecfg[2]].astype(str)
        ok = y.str.fullmatch(r"\d{4}") & mth.str.fullmatch(r"\d{1,2}")
        d = pd.to_datetime(y + "-" + mth.where(ok, "1").str.zfill(2) + "-01", errors="coerce")
        d[~ok] = pd.NaT
    return d.dt.strftime("%Y-%m-%d")


# --------------------------------------------------------------------------- labels
MOJIBAKE = re.compile(r"[\x80-\x9f�]|Ã[\x80-\xbf]|â€")


def norm_label(s):
    s = unicodedata.normalize("NFC", s or "").replace("’", "'").replace("`", "'")
    return re.sub(r"\s+", " ", s).strip().casefold()


def strip_noga(label, code):
    s = label.strip()
    if s.startswith(code + " "):
        s = s[len(code) + 1:]
    return s


def check_labels(cfg, api_meta, dims_kept, label_docs):
    issues, compared = [], 0
    for L, doc in label_docs.items():
        vmap = {v["code"]: v for v in doc["variables"]}
        for d in dims_kept:
            up = vmap.get(d)
            if up is None:
                continue
            upl = dict(zip(up["values"], up["valueTexts"]))
            levels = api_meta["dimensions"].get(d, {}).get("levels", {})
            for code, lv in levels.items():
                apil = (lv.get("label") or {}).get(L)
                if apil is None:
                    issues.append(dict(lang=L, dim=d, code=code, kind="missing_label"))
                    continue
                compared += 1
                if MOJIBAKE.search(apil):
                    issues.append(dict(lang=L, dim=d, code=code, kind="mojibake",
                                       api=apil, upstream=upl.get(code)))
                    continue
                u = upl.get(code)
                if u is None:
                    issues.append(dict(lang=L, dim=d, code=code, kind="code_not_upstream", api=apil))
                    continue
                if d == cfg.get("noga"):
                    u = strip_noga(u, code)
                if norm_label(u) != norm_label(apil):
                    issues.append(dict(lang=L, dim=d, code=code, kind="label_differs",
                                       api=apil, upstream=upl.get(code)))
    return compared, issues


def compare(up, api, keys):
    n_dup_up, n_dup_api = int(up.duplicated(keys).sum()), int(api.duplicated(keys).sum())
    if n_dup_up:
        raise RuntimeError(f"{n_dup_up} duplicate keys upstream after normalising (checker wrong?)")
    m = up.merge(api, on=keys, how="outer", suffixes=("_up", "_api"), indicator=True)
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
        "mismatch_examples": mism.head(5)[keys + ["value_up", "value_api"]].to_dict("records"),
        "missing_examples": missing.head(5)[keys + ["value_up"]].to_dict("records"),
        "only_api_examples": only_api.head(5)[keys + ["value_api"]].to_dict("records"),
    }
    return problems, len(newer), details


def check(ds_id):
    cfg = DATASETS[ds_id]
    meta, vars_, resolved, up = fetch_upstream(cfg)
    tcols = list(cfg["time"][1:])
    up["date"] = to_date(up, cfg["time"])
    up = up[up["date"].notna() & up["value"].notna()]
    dims = [c for c in resolved if c not in tcols]
    dims_kept = [c for c in dims if up[c].nunique() > 1]
    up = up[dims_kept + ["date", "value"]]

    api = lib.api_csv(ds_id)
    api_meta = lib.api_meta(ds_id)
    api_dims = [c for c in api.columns if c not in ("date", "value")]
    if sorted(api_dims) != sorted(dims_kept):
        return "fail", f"dimensions differ: API {api_dims} vs upstream {dims_kept}", {}
    n_api_empty = int(api["value"].isna().sum())
    api = api[api["value"].notna()]
    problems, n_newer, details = compare(up, api, dims_kept + ["date"])

    label_docs = {"en": meta}
    for lang in ("de", "fr", "it"):
        label_docs[lang] = px_meta(cfg["table"], lang)
    n_labels, issues = check_labels(cfg, api_meta, dims_kept, label_docs)
    for d in dims_kept:
        extra = sorted(set(api[d]) - set(vars_[d]["values"]))
        if extra:
            issues.append(dict(dim=d, kind="api_codes_not_upstream", codes=extra[:10]))
        no_level = sorted(set(api[d]) - set(api_meta["dimensions"].get(d, {}).get("levels", {})))
        if no_level:
            issues.append(dict(dim=d, kind="api_codes_missing_from_meta", codes=no_level[:10]))
    kinds = sorted({i["kind"] for i in issues})
    details.update(n_api_empty_values=n_api_empty, labels_compared=n_labels,
                   n_label_issues=len(issues), label_issue_examples=issues[:5])
    if issues:
        problems.append(f"{len(issues)} code/label issues ({', '.join(kinds)})")
    cells = details["cells_compared"]
    if problems:
        return "fail", f"{cells} cells compared; " + "; ".join(problems), details
    if n_newer:
        return ("lag", f"{cells} cells match; upstream has {n_newer} newer rows "
                f"(upstream {details['latest_upstream']}, API {details['latest_api']})", details)
    return "ok", f"{cells} cells and {n_labels} labels match upstream (latest {details['latest_api']})", details


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
