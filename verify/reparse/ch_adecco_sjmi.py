"""Independent re-parse of ch_adecco_sjmi (Adecco Group Swiss Job Market Index, UZH) and
cell-by-cell comparison with the live API.

Source: the xlsx linked from https://www.stellenmarktmonitor.uzh.ch/de/indices/asjmi.html
(sheet "Gesamtindex": wide layout, row "Jahr" (merged over quarters), row "Erhebungsmonat"
(Mrz/Jun/Sep/Dez), row "Quartal" (I..IV), then one row per series; trailing columns hold
quarterly and yearly changes and carry no quarter). Quarters are dated by their first month.
"""
import re
import sys
from pathlib import Path

import openpyxl
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib

DATASET = "ch_adecco_sjmi"
PAGE = "https://www.stellenmarktmonitor.uzh.ch/de/indices/asjmi.html"
SURVEY_MONTH = {"Mrz": 3, "Jun": 6, "Sep": 9, "Dez": 12}
QUARTER_START = {"I": 1, "II": 4, "III": 7, "IV": 10}
ROWS = [
    (re.compile(r"^adecco group swiss job market index$", re.I), "gesamt"),
    (re.compile(r"^saisonbereinigte indexwerte$", re.I), "gesamt_sa"),
    (re.compile(r"^internet-stellenportale$", re.I), "internet"),
    (re.compile(r"^unternehmens-webseiten$", re.I), "company"),
    (re.compile(r"^presse \(zeitungen", re.I), "press"),
]


def xlsx_path():
    href = re.search(r'/dam/[^"]+?\.xlsx', lib.get(PAGE).text)
    if not href:
        raise ValueError(f"no .xlsx link on {PAGE}")
    return lib.download("https://www.stellenmarktmonitor.uzh.ch" + href.group(0), f"{DATASET}.xlsx")


def source_cells():
    ws = openpyxl.load_workbook(xlsx_path(), data_only=True)["Gesamtindex"]
    rows = list(ws.iter_rows(values_only=True))
    head = {r[0]: r for r in rows if r and isinstance(r[0], str)}
    years, months, quarters = head["Jahr"], head["Erhebungsmonat"], head["Quartal"]
    coldate, year = {}, None
    for j in range(1, len(years)):
        if isinstance(years[j], (int, float)):
            year = int(years[j])
        if months[j] is None or quarters[j] is None:
            continue
        q = str(quarters[j]).strip()
        if SURVEY_MONTH[str(months[j]).strip()] != QUARTER_START[q] + 2:
            raise ValueError(f"column {j}: month {months[j]} and quarter {quarters[j]} disagree")
        coldate[j] = f"{year:04d}-{QUARTER_START[q]:02d}-01"
    out, seen = [], set()
    for r in rows:
        if not isinstance(r[0], str):
            continue
        code = next((c for rx, c in ROWS if rx.search(r[0].strip())), None)
        if code is None or code in seen:
            continue
        seen.add(code)
        out += [(code, d, float(r[j])) for j, d in coldate.items() if r[j] not in (None, "")]
    missing = {c for _, c in ROWS} - seen
    if missing:
        raise ValueError(f"rows not found in the sheet: {sorted(missing)}")
    df = pd.DataFrame(out, columns=["index", "date", "value"])
    if df.duplicated(["index", "date"]).any():
        raise ValueError("duplicate keys in source")
    return df


def check():
    mine = source_cells()
    return lib.compare(mine, lib.api_csv(DATASET), ["index", "date"], rtol=0, atol=1e-9)


if __name__ == "__main__":
    only = lib.only_arg(sys.argv[1:])
    verdicts = lib.Verdicts(f"reparse-{DATASET}")
    if only is None or DATASET in only:
        verdicts.run(DATASET, check)
    print(verdicts.write())
    for v in verdicts.items:
        print(v["dataset"], v["status"], v["summary"])
