#!/usr/bin/env python3
"""Full upstream diff for source type "seco-kof-eurostat".

For each dataset, fetch the raw upstream file straight from the public endpoint
(SECO scheduler CSVs, KOF tsdb API, Eurostat SDMX), normalise it to
(dimension codes, date, value), download the full dataset from the live API and
compare every cell. Dimension codes in the data are checked against the levels
declared in the API meta. One verdict per dataset goes to
verify/out/verdicts/upstream-seco-kof-eurostat.json.

    python verify/upstream/seco-kof-eurostat.py [--only id1,id2]
"""
from __future__ import annotations

import io
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib  # noqa: E402

CHECK = "upstream-seco-kof-eurostat"
REL_TOL = 1e-9
ABS_TOL = 1e-9
MAX_EXAMPLES = 5

SECO = "https://scheduler.swissdatas.ch/scheduled"
KOF = "https://tsdb-api.kof.ethz.ch/v2"
ESTAT = "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1"
COICOP = ["TOTAL"] + [f"CP{i:02d}" for i in range(1, 14)]


def fetch_csv(url: str, name: str) -> pd.DataFrame:
    text = lib.download(url, name).read_bytes().decode("utf-8-sig")
    return pd.read_csv(io.StringIO(text), dtype=str, keep_default_na=False)


def to_num(s: pd.Series) -> pd.Series:
    return pd.to_numeric(s.replace({"": None, "NA": None, "NaN": None}), errors="coerce")


def iso_date(s: pd.Series) -> pd.Series:
    return pd.to_datetime(s).dt.strftime("%Y-%m-%d")


def up_seco(data_file: str, drop_const=()):
    def fetch():
        df = fetch_csv(f"{SECO}/{data_file}", data_file)
        df = df.drop(columns=list(drop_const))
        df["date"] = iso_date(df["date"])
        df["value"] = to_num(df["value"])
        return df
    return fetch


def up_kof_ts(key: str):
    def fetch():
        df = fetch_csv(f"{KOF}/ts?keys={key}&mime=csv&access_type=public", f"{key}.csv")
        value_col = [c for c in df.columns if c != "date"][0]
        df = df.rename(columns={value_col: "value"})
        df["date"] = iso_date(df["date"])
        df["value"] = to_num(df["value"])
        return df[["date", "value"]]
    return fetch


def up_kof_collection(coll: str, dim: str = "indicator"):
    def fetch():
        wide = fetch_csv(f"{KOF}/collections/public/{coll}/ts?mime=csv&access_type=public",
                         f"{coll}.csv")
        df = wide.melt(id_vars="date", var_name=dim, value_name="value")
        df["date"] = iso_date(df["date"])
        df["value"] = to_num(df["value"])
        return df[[dim, "date", "value"]]
    return fetch


def up_hicp():
    key = "+".join(COICOP)
    raw = fetch_csv(f"{ESTAT}/data/prc_hicp_minr/M.I15.{key}.CH/?format=SDMX-CSV",
                    "prc_hicp_minr_CH.csv")
    return pd.DataFrame({
        "coicop": raw["coicop18"].replace({"TOTAL": "CP00"}),
        "date": iso_date(raw["TIME_PERIOD"] + "-01"),
        "value": to_num(raw["OBS_VALUE"]),
    })


DATASETS = {
    "ch_seco_concon": up_seco("ks-q.csv"),
    "ch_seco_gdp": up_seco("ch-seco-gdp.csv"),
    "ch_seco_wwa": up_seco("wwa.csv", drop_const=("type", "seas_adj")),
    "ch_kof_barometer": up_kof_ts("ch.kof.barometer"),
    "ch_kof_esi": up_kof_collection("ogd_ch.kof.esi"),
    "ch_fso_hicp": up_hicp,
}


def examples(df: pd.DataFrame, n: int = MAX_EXAMPLES) -> list[dict]:
    return df.head(n).astype(object).where(df.head(n).notna(), None).to_dict("records")


def compare(up: pd.DataFrame, api: pd.DataFrame, key: list[str]) -> dict:
    m = up.dropna(subset=["value"]).drop_duplicates(key, keep="last").merge(
        api.dropna(subset=["value"]).drop_duplicates(key, keep="last"),
        on=key, how="outer", suffixes=("_up", "_api"), indicator=True)
    both = m[m["_merge"] == "both"].copy()
    both["abs_diff"] = (both["value_up"] - both["value_api"]).abs()
    off = (both["value_up"] != both["value_api"]) & ~np.isclose(
        both["value_up"], both["value_api"], rtol=REL_TOL, atol=ABS_TOL)
    mism = both[off].sort_values("abs_diff", ascending=False)
    return {"cells_compared": len(both),
            "only_up": m[m["_merge"] == "left_only"],
            "only_api": m[m["_merge"] == "right_only"],
            "mismatches": mism}


def check(ds_id: str):
    up = DATASETS[ds_id]()
    api = lib.api_csv(ds_id)
    meta = lib.api_meta(ds_id)
    dims = list(meta.get("dim_order") or [])

    absent = [c for c in dims + ["date", "value"] if c not in api.columns]
    if absent:
        return "fail", f"API series.csv lacks columns {absent}", {"api_columns": list(api.columns)}
    missing_up = [c for c in dims + ["date"] if c not in up.columns]
    if missing_up:
        raise ValueError(f"upstream lacks columns {missing_up}; has {list(up.columns)}")
    key = dims + ["date"]
    up = up[key + ["value"]]
    api = api[key + ["value"]]

    problems = []
    n_dup_up = int(up.duplicated(key).sum())
    n_dup_api = int(api.duplicated(key).sum())
    if n_dup_up:
        problems.append(f"{n_dup_up} duplicate upstream keys")
    if n_dup_api:
        problems.append(f"{n_dup_api} duplicate API keys")

    cmp = compare(up, api, key)
    only_up, only_api, mism = cmp["only_up"], cmp["only_api"], cmp["mismatches"]
    latest_up = up.dropna(subset=["value"])["date"].max()
    latest_api = api["date"].max()
    missing = only_up[only_up["date"] <= latest_api]
    newer = only_up[only_up["date"] > latest_api]
    if len(mism):
        problems.append(f"{len(mism)} value mismatches")
    if len(missing):
        problems.append(f"{len(missing)} upstream rows missing from the API within its date range")
    if len(only_api):
        problems.append(f"{len(only_api)} API rows not in upstream")

    for d in dims:
        declared = set((meta.get("dimensions", {}).get(d, {}).get("levels") or {}))
        not_declared = sorted(set(api[d]) - declared)
        if not_declared:
            problems.append(f"{d} codes in API data but not in meta levels: {not_declared[:5]}")
        no_data = sorted(c for c in declared - set(api[d])
                         if (meta["dimensions"][d]["levels"][c] or {}).get("data", True))
        if no_data:
            problems.append(f"{d} meta levels flagged with data but absent from API data: {no_data[:5]}")
        gone = sorted(set(up.loc[up["value"].notna(), d]) - set(api[d]))
        if gone and not len(newer):
            problems.append(f"{d} upstream codes absent from the API: {gone[:5]}")

    shown = mism.rename(columns={"value_up": "upstream", "value_api": "api"})
    details = {"cells_compared": cmp["cells_compared"], "n_value_mismatch": len(mism),
               "n_only_upstream": len(only_up), "n_missing_in_api_range": len(missing),
               "n_newer_than_api": len(newer), "n_only_api": len(only_api),
               "n_dup_upstream": n_dup_up, "n_dup_api": n_dup_api,
               "n_upstream_na": int(up["value"].isna().sum()),
               "latest_upstream": latest_up, "latest_api": latest_api,
               "api_updated": meta.get("updated"),
               "mismatch_examples": examples(shown[key + ["upstream", "api"]]),
               "problems": problems[:20]}
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
        print(f"{ds:20s} {v['status']:12s} {v['summary']}", flush=True)
    print("wrote", verdicts.write())


if __name__ == "__main__":
    main(sys.argv[1:])
