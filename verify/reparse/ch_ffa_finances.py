"""Independent re-parse of ch_ffa_finances (FFA main aggregates CSV from data.finance.admin.ch)
and cell-by-cell comparison with the live API.

Source columns: row number, hh (level), model, variable (indicator), jahr, value, source
(estimate type, German text). The published indicators are the ones listed in the datasheet's
indicator labels. The GDP row (variable bip) has no level, model or source in the CSV; per
the datasheet it is published as level=staat, model=gfs, estimate=rechnung.
"""
import re
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib

DATASET = "ch_ffa_finances"
CKAN = "https://opendata.swiss/api/3/action/package_show?id=hauptaggregate-und-prognosen-im-fs-und-gfs-modell"
CSV_FALLBACK = "https://www.data.finance.admin.ch/static/assets/datasets/fs_dashboard/main_extern.csv"
KEYS = ["level", "model", "indicator", "estimate", "date"]
ESTIMATE = {
    "Rechnung": "rechnung",
    "Hochrechnung": "hochrechnung",
    "Umfrage Budget": "umfrage_budget",
    "Budget/Finanzpläne": "budget",
    "Prognosen": "prognose",
    "Vorhandene Daten": "vorhanden",
}
GDP = {"level": "staat", "model": "gfs", "estimate": "rechnung"}


def published_indicators():
    block = False
    codes = set()
    for line in (lib.ROOT / "datasets" / f"{DATASET}.md").read_text(encoding="utf-8").splitlines():
        if line.startswith("- dim:"):
            block = line.split(":", 1)[1].strip() == "indicator"
        elif block:
            m = re.match(r"^  - ([a-z_]+):", line)
            if m and not m.group(1).startswith("grp_"):
                codes.add(m.group(1))
    if not codes:
        raise ValueError("no indicators found in the datasheet")
    return codes


def csv_url():
    try:
        resources = lib.get(CKAN).json()["result"]["resources"]
        return next(r["url"] for r in resources if "main_extern" in (r.get("url") or ""))
    except (lib.Unreachable, KeyError, StopIteration, ValueError):
        return CSV_FALLBACK


def source_cells():
    path = lib.download(csv_url(), f"{DATASET}.csv")
    d = pd.read_csv(path, dtype=str, keep_default_na=False, encoding="utf-8")
    if list(d.columns) != ["Unnamed: 0", "hh", "model", "variable", "jahr", "value", "source"]:
        raise ValueError(f"unexpected CSV columns {list(d.columns)}")
    d = d[d["variable"].isin(published_indicators()) & (d["value"] != "NA")].copy()
    gdp = d["variable"] == "bip"
    unknown = set(d.loc[~gdp, "source"]) - set(ESTIMATE)
    if unknown:
        raise ValueError(f"unknown estimate texts {sorted(unknown)}")
    out = pd.DataFrame({
        "level": d["hh"].where(~gdp, GDP["level"]),
        "model": d["model"].where(~gdp, GDP["model"]),
        "indicator": d["variable"],
        "estimate": d["source"].map(ESTIMATE).where(~gdp, GDP["estimate"]),
        "date": d["jahr"].str.strip() + "-01-01",
        "value": pd.to_numeric(d["value"], errors="raise"),
    })
    if out.duplicated(KEYS).any():
        raise ValueError("duplicate keys in source")
    return out.reset_index(drop=True)


def check():
    mine = source_cells()
    return lib.compare(mine, lib.api_csv(DATASET), KEYS, rtol=1e-9, atol=1e-9)


if __name__ == "__main__":
    only = lib.only_arg(sys.argv[1:])
    verdicts = lib.Verdicts(f"reparse-{DATASET}")
    if only is None or DATASET in only:
        verdicts.run(DATASET, check)
    print(verdicts.write())
    for v in verdicts.items:
        print(v["dataset"], v["status"], v["summary"])
