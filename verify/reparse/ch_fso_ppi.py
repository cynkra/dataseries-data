"""Independent re-parse of ch_fso_ppi (FSO DAM Excel su-q-05.04.03.01-ppi-ipp),
compared cell by cell with the live API.

Parse: sheet INDEX_m, header row = the row whose first cell is '<ORIGBAS>' with base
codes as '<YYYY>' in the following header cells; the row below holds the units. Data rows
carry a date in the third column.
"""
import datetime as dt
import re
import sys
from pathlib import Path

import openpyxl
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib

DATASET = "ch_fso_ppi"
ORDER = "su-q-05.04.03.01-ppi-ipp"
KEY = ["base", "date"]
TOL = 1e-9


def parse(xlsx):
    wb = openpyxl.load_workbook(xlsx, read_only=True, data_only=True)
    rows = list(wb["INDEX_m"].iter_rows(values_only=True))
    hdr_i = next(i for i, r in enumerate(rows) if r and r[0] == "<ORIGBAS>")
    hdr, unit_row = rows[hdr_i], rows[hdr_i + 1]
    cols = {}
    for j, c in enumerate(hdr):
        m = re.fullmatch(r"<(\d{4})>", str(c or ""))
        if m:
            cols[m.group(1)] = j
    units = {b: unit_row[j] for b, j in cols.items()}
    out, odd = [], []
    for i, r in enumerate(rows[hdr_i + 2:], start=hdr_i + 3):
        d = r[2] if len(r) > 2 else None
        if not isinstance(d, (dt.datetime, dt.date)):
            if any(x is not None for x in r[3:]) and r[0] is None:
                odd.append({"row": i, "values": [str(x) for x in r]})
            continue
        for b, j in cols.items():
            v = r[j]
            if isinstance(v, (int, float)):
                out.append((b, d.strftime("%Y-%m-01"), float(v)))
            else:
                odd.append({"row": i, "base": b, "date": str(d), "value": str(v)})
    return pd.DataFrame(out, columns=["base", "date", "value"]), units, odd


def check():
    url, pubdate = lib.fso_dam_master(ORDER)
    src, units, odd = parse(lib.download(url, f"{ORDER}.xlsx"))
    api = lib.api_csv(DATASET)
    months = {"Mai": "May", "Dez": "Dec"}
    levels = lib.api_meta(DATASET)["dimensions"]["base"]["levels"]
    unit_bad = []
    for b, u in units.items():
        label = levels.get(b, {}).get("label", {}).get("en") or ""
        u_en = " ".join(months.get(t, t) for t in str(u).split())
        if u_en not in label:
            unit_bad.append({"base": b, "source_unit": u, "api_label_en": label})
    problems = [f"base {u['base']}: unit {u['source_unit']} not in the API label" for u in unit_bad]

    status, summary, d = lib.compare(src, api, KEY, rtol=0, atol=TOL, problems=problems)
    d.update(n_unit_mismatch=len(unit_bad), source_published=pubdate, n_source_oddities=len(odd))
    if unit_bad:
        d["examples"] = (d["examples"] + unit_bad)[:5]
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
