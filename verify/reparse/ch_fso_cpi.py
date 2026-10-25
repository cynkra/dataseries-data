"""Independent re-parse of ch_fso_cpi (FSO LIK master xlsx, order su-d-05.02.66),
compared cell by cell with the live API.

Parse: sheet INDEX_m, header row = the row whose first cell is 'Code'. Data rows are
rows whose Code cell looks like '<digits>_<digits>'. Date columns are the header cells
holding a datetime (monthly, first of month). '...' and empty cells = missing.
"""
import re
import sys
from datetime import datetime
from pathlib import Path

import openpyxl
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib

DATASET = "ch_fso_cpi"
ORDER = "su-d-05.02.66"
KEY = ["item", "date"]
TOL = 5e-5  # the API publishes 4 decimals
CODE_RE = re.compile(r"^\d+_\d+$")


def parse(path):
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    rows = list(wb["INDEX_m"].iter_rows(values_only=True))
    hi = next(i for i, r in enumerate(rows) if r and r[0] == "Code")
    header = rows[hi]
    col = {name: j for j, name in enumerate(header) if isinstance(name, str)}
    date_cols = [(j, h) for j, h in enumerate(header) if isinstance(h, datetime)]
    recs, labels, odd = [], {}, []
    for r in rows[hi + 1:]:
        code = r[0]
        if not isinstance(code, str) or not CODE_RE.match(code.strip()):
            continue
        code = code.strip()
        labels[code] = {lg: r[col[f"PosTxt_{lg[0].upper()}"]] for lg in ("de", "fr", "it", "en")}
        for j, d in date_cols:
            v = r[j] if j < len(r) else None
            if v is None or (isinstance(v, str) and v.strip() in ("...", "", "-")):
                continue
            if isinstance(v, str):
                odd.append((code, d.date().isoformat(), v))
                continue
            recs.append((code, d.date().isoformat(), float(v)))
    df = pd.DataFrame(recs, columns=["item", "date", "value"])
    # The sheet repeats Total + the 13 divisions in a summary block below the
    # tree. Keep one copy, but only if the repeats are identical.
    spread = df.groupby(KEY).value.nunique()
    if (spread > 1).any():
        raise ValueError(f"conflicting duplicate source cells: {spread[spread > 1].head().to_dict()}")
    return df.drop_duplicates(KEY), labels, odd


def check():
    url, pubdate = lib.fso_dam_master(ORDER)
    src, labels, odd = parse(lib.download(url, f"{ORDER}.xlsx"))
    api = lib.api_csv(DATASET)
    levels = lib.api_meta(DATASET)["dimensions"]["item"]["levels"]
    label_mism = [{"item": c, "lang": lg, "source": (lab[lg] or "").strip(),
                   "api": (levels[c]["label"].get(lg) or "").strip()}
                  for c, lab in labels.items() if c in levels for lg in lab
                  if (levels[c]["label"].get(lg) or "").strip() != (lab[lg] or "").strip()]
    problems = [f"{m['item']}: {m['lang']} label differs from the source" for m in label_mism]

    status, summary, d = lib.compare(src, api, KEY, rtol=0, atol=TOL, problems=problems)
    d.update(n_label_mismatch=len(label_mism), source_published=pubdate, odd_source_strings=odd[:5])
    if label_mism:
        d["examples"] = (d["examples"] + label_mism)[:5]
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
