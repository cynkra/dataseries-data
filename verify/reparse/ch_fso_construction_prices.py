"""Independent re-parse of ch_fso_construction_prices (FSO DAM Excel cc-t-05.05.01),
compared cell by cell with the live API.

Parse (own reading of the workbook):
  - The unit in the API meta is "Index (October 2020 = 100)", so use sheet "2020"
    (row 4 '<BASE_2020>' 'Basis Oktober 2020 = 100').
  - Row 5 = German month names (Oktober / April), row 6 = year (str or int).
    Columns D.. are periods. Column C is the weight ('Gewicht in %').
  - Column A holds codes: '<REG_01>' = Schweiz starts the national block; within it
    'Baugewerbe : Total' -> total, 'Hochbau' -> hochbau, 'Tiefbau' -> tiefbau. The
    block ends at the next '<REG_..>' row.
  - '...' (three dots) = not available -> dropped.
"""
import sys
from pathlib import Path

import openpyxl
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib

DATASET = "ch_fso_construction_prices"
ORDER = "cc-t-05.05.01"
KEY = ["worktype", "date"]
TOL = 1e-9
MONTHS = {"oktober": 10, "april": 4}
MAP = {"Baugewerbe : Total": "total", "Hochbau": "hochbau", "Tiefbau": "tiefbau"}


def norm(s):
    return " ".join(str(s).replace("\xa0", " ").split())


def parse(path, sheet="2020"):
    wb = openpyxl.load_workbook(path, data_only=True)
    rows = list(wb[sheet].iter_rows(values_only=True))
    base = norm(rows[3][1])
    assert base == "Basis Oktober 2020 = 100", base
    months, years = rows[4], rows[5]
    periods = {}
    for j in range(3, len(months)):
        if months[j] is None and years[j] is None:
            continue
        periods[j] = f"{int(str(years[j]).strip()):04d}-{MONTHS[norm(months[j]).lower()]:02d}-01"
    start = next(i for i, r in enumerate(rows) if r[0] == "<REG_01>")
    assert norm(rows[start][1]) == "Schweiz"
    out, seen = [], set()
    for r in rows[start + 1:]:
        if r[0] and str(r[0]).startswith("<REG_"):
            break
        label = norm(r[1]) if r[1] is not None else ""
        if label in MAP:
            code = MAP[label]
            assert code not in seen, code
            seen.add(code)
            for j, d in periods.items():
                v = r[j]
                if v is None or (isinstance(v, str) and v.strip() in ("\u2026", "...", "")):
                    continue
                out.append((code, d, float(v)))
    assert seen == set(MAP.values()), seen
    return pd.DataFrame(out, columns=["worktype", "date", "value"])


def check():
    url, pubdate = lib.fso_dam_master(ORDER)
    src = parse(lib.download(url, f"{ORDER}.xlsx"))
    api = lib.api_csv(DATASET)
    status, summary, d = lib.compare(src, api, KEY, rtol=0, atol=TOL)
    d["source_published"] = pubdate
    return status, summary, d


def main():
    only = lib.only_arg(sys.argv)
    if only is not None and DATASET not in only:
        return
    v = lib.Verdicts(f"reparse-{DATASET}")
    v.run(DATASET, check)
    v.write()
    for item in v.items:
        print(item["status"], item["summary"])


if __name__ == "__main__":
    main()
