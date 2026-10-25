#!/usr/bin/env python3
"""Full upstream diff for source type "fso-dam-csv".

For each dataset: resolve the FSO DAM order number (from the datasheet ## Access
block) to its CSV master, download it directly, normalise it independently of the
repo's R fetchers to (dims, date=first day of period, value), download the full
dataset from the live API and compare every cell. The API meta levels are checked
against the data codes and scanned for control characters in labels.

Run: python verify/upstream/fso-dam-csv.py [--only id1,id2]
Writes verify/out/verdicts/upstream-fso-dam-csv.json.
"""
import io
import re
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib  # noqa: E402

CHECK = "upstream-fso-dam-csv"
C1_CONTROL = re.compile("[\u0080-\u009f]")


def order_from_datasheet(ds_id):
    md = (lib.ROOT / "datasets" / f"{ds_id}.md").read_text(encoding="utf-8")
    acc = md.split("## Access", 1)[1].split("\n## ", 1)[0]
    return re.search(r"\*\*order number\*\*:\s*`([^`]+)`", acc).group(1)


def read_master(order):
    master, _ = lib.fso_dam_master(order)
    path = lib.download(master, f"{order}.master.csv")
    return pd.read_csv(path, encoding="utf-8-sig", dtype=str, keep_default_na=False)


def num(s):
    return pd.to_numeric(s.replace("", None), errors="coerce")


def require_mapped(name, mapped):
    if mapped.isna().any():
        raise RuntimeError(f"unmapped upstream {name} values (source layout changed?)")
    return mapped


def norm_labour_productivity(raw):
    ind = {"GDP": "gdp", "Actual hours worked": "hours", "Productivity": "productivity"}
    return pd.DataFrame({
        "indicator": require_mapped("INDICATOR", raw.INDICATOR.map(ind)),
        "date": raw.PERIOD.str.strip() + "-01-01",
        "value": num(raw.VALUE)})


def norm_ets(raw):
    sexmap = {"Total": "total", "Männer": "male", "Frauen": "female"}
    q = raw[raw.FREQ == "Q"]
    m = q.PERIOD.str.extract(r"^(\d{4})-Q([1-4])$")
    if m[0].isna().any():
        raise RuntimeError(f"unparsed quarterly periods: {q.PERIOD[m[0].isna()].unique()[:5].tolist()}")
    month = (m[1].astype(int) - 1) * 3 + 1
    return pd.DataFrame({
        "sector": q.INDICATORS_HRCHY,
        "sex": require_mapped("GENDER_DE", q.GENDER_DE.map(sexmap)),
        "date": m[0] + "-" + month.map("{:02d}".format) + "-01",
        "value": num(q.VALUE)})


def norm_gfcf(raw):
    m = raw[raw.UNIT_MEAS == "MCHF"]
    return pd.DataFrame({"sector": m.SECTOR, "asset": m.CLASSIFICATION,
                         "date": m.PERIOD.str.strip() + "-01-01", "value": num(m.VALUE)})


def norm_hours(raw):
    sl = raw[(raw.NAT == "_T") & (raw.NOGA1 == "_T") & (raw.SECTOR == "_T")
             & (raw.EMP_STATUS == "_T") & (raw.REGION == "_T")]
    parts = [pd.DataFrame({"sex": sl.SEX, "worktime": sl.WORKTIME, "measure": code,
                           "date": sl.TIME_PERIOD.str.strip() + "-01-01", "value": num(sl[col])})
             for col, code in [("VALUE", "volume"), ("VALUE_Y", "annual"), ("VALUE_W", "weekly")]]
    return pd.concat(parts, ignore_index=True)


DATASETS = {
    "ch_fso_labour_productivity": norm_labour_productivity,
    "ch_fso_ets": norm_ets,
    "ch_fso_gfcf_detail": norm_gfcf,
    "ch_fso_hours_worked": norm_hours,
}


def compare(up, api, dims):
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


def check_meta(api, dims, meta):
    problems = []
    if set(meta.get("dim_order", [])) != set(dims):
        problems.append(f"meta dim_order {meta.get('dim_order')} != data dims {dims}")
    for d in dims:
        levels = (meta.get("dimensions", {}).get(d) or {}).get("levels", {})
        missing = sorted(set(api[d]) - set(levels))
        if missing:
            problems.append(f"{d}: codes in data but not in meta: {missing[:5]}")
        for code, ent in levels.items():
            for lang, text in (ent.get("label") or {}).items():
                if C1_CONTROL.search(text or ""):
                    problems.append(f"{d}={code}: control character in {lang} label {text!r}")
    return problems


def check(ds_id):
    up = DATASETS[ds_id](read_master(order_from_datasheet(ds_id)))
    dims = [c for c in up.columns if c not in ("date", "value")]
    up = up[up["value"].notna()].reset_index(drop=True)

    api = lib.api_csv(ds_id)
    api_dims = [c for c in api.columns if c not in ("date", "value")]
    if sorted(api_dims) != sorted(dims):
        return "fail", f"dimensions differ: API {api_dims} vs upstream {dims}", {}
    n_api_empty = int(api["value"].isna().sum())
    api = api[api["value"].notna()]

    problems, n_newer, details = compare(up, api, dims)
    meta_problems = check_meta(api, dims, lib.api_meta(ds_id))
    details.update(n_api_empty_values=n_api_empty, n_meta_problems=len(meta_problems),
                   meta_problem_examples=meta_problems[:5])
    if meta_problems:
        problems.append(f"{len(meta_problems)} code/label problems in meta")
    cells = details["cells_compared"]
    if problems:
        return "fail", f"{cells} cells compared; " + "; ".join(problems), details
    if n_newer:
        return ("lag", f"{cells} cells match; upstream has {n_newer} newer rows "
                f"(upstream {details['latest_upstream']}, API {details['latest_api']})", details)
    return "ok", f"{cells} cells match upstream (latest {details['latest_api']})", details


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
