"""Independent re-parse of ch_fso_wage_idx (FSO DAM Excel je-e-03.04.03.00.04),
compared cell by cell with the live API.

Workbook layout (as observed 2026-10-25):
  sheet T1.93 = nominal wage index, sheet T2.93 = real wage index.
  Each sheet has two side-by-side blocks (1993-2010 NOGA02 in cols A..T,
  2011-2025 NOGA08 in cols U..AL). Each block has an "Index 1993=100" part
  and a "Variation in % compared with previous year" part. Only the index
  part is parsed. Rows are identified by the label column (3rd col of each
  block): TOTAL / Men / Women / SECTOR 2 / Construction / SECTOR 3.
"""
import sys
from pathlib import Path

import openpyxl
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib

DATASET = "ch_fso_wage_idx"
ORDER = "je-e-03.04.03.00.04"
KEY = ["breakdown", "adjustment", "date"]
TOL = 1e-9
SHEETS = {"T1.93": "nominal", "T2.93": "real"}
ROWMAP = {
    "total": "tot",
    "men": "m",
    "women": "f",
    "sector 2": "bf1",
    "construction": "f41",
    "sector 3": "gs4",
}
BLOCKS = [(2, 3, 19), (22, 23, 37)]  # (label col, first year col, last col)


def parse_block(ws, label_col, first_year_col, last_col):
    """Return list of (code, year, value) for the index part of one block."""
    out, odd = [], []
    rows = list(ws.iter_rows(values_only=True))
    hdr_i = None
    for i, r in enumerate(rows):
        c = r[label_col - 2]
        if isinstance(c, str) and c.strip().upper().startswith("NOGA"):
            hdr_i = i
            break
    assert hdr_i is not None, "header row not found"
    unit_cell = rows[hdr_i - 1][first_year_col]
    assert unit_cell and "1993=100" in str(unit_cell), unit_cell
    years = {j: int(str(rows[hdr_i][j]).strip())
             for j in range(first_year_col, last_col + 1) if rows[hdr_i][j] is not None}
    for r in rows[hdr_i + 1:]:
        lab = r[label_col]
        if lab is None:
            if r[first_year_col] is not None and "Variation" in str(r[first_year_col]):
                break
            continue
        key = str(lab).strip().lower()
        if key not in ROWMAP:
            odd.append(str(lab))
            continue
        for j, y in years.items():
            v = r[j]
            if v is None:
                continue
            if not isinstance(v, (int, float)):
                odd.append(f"{lab}/{y}: {v!r}")
                continue
            out.append((ROWMAP[key], y, float(v)))
    return out, odd


def parse(path):
    wb = openpyxl.load_workbook(path, data_only=True)
    recs, odd = [], []
    for sheet, adj in SHEETS.items():
        for lc, fy, last in BLOCKS:
            r, o = parse_block(wb[sheet], lc, fy, last)
            recs += [(b, adj, f"{y}-01-01", v) for b, y, v in r]
            odd += [f"{sheet}: {x}" for x in o]
    df = pd.DataFrame(recs, columns=["breakdown", "adjustment", "date", "value"])
    dup = int(df.duplicated(KEY).sum())
    if dup:
        raise ValueError(f"{dup} duplicate source keys")
    return df, odd


def check():
    url, pubdate = lib.fso_dam_master(ORDER)
    src, odd = parse(lib.download(url, f"{ORDER}.xlsx"))
    api = lib.api_csv(DATASET)
    status, summary, d = lib.compare(src, api, KEY, rtol=0, atol=TOL)
    d.update(source_published=pubdate, odd_source_strings=odd[:5])
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
