"""Independent re-parse of ch_fso_gdp_region (FSO DAM Excel je-e-04.02.06.01), compared cell by
cell with the live API. Does not use the repo's R parser."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib

import openpyxl
import pandas as pd

DS = "ch_fso_gdp_region"
ORDER = "je-e-04.02.06.01"


def parse_sheet(ws):
    """(label, year, value) for the 'In CHF million' block of one sheet."""
    rows = list(ws.iter_rows(values_only=True))
    hdr_i = next(i for i, r in enumerate(rows) if r[0] in ("Canton", "Region"))
    years = [int(str(c).strip().rstrip("p")) if c is not None else None for c in rows[hdr_i][1:]]
    start = next(i for i, r in enumerate(rows)
                 if isinstance(r[0], str) and r[0].startswith("In CHF million"))
    out = []
    for r in rows[start + 1:]:
        lab = r[0]
        if lab is None or str(lab).strip() == "":
            break
        for y, v in zip(years, r[1:]):
            if y is None or v is None or v == ".":
                continue
            out.append((str(lab).strip(), y, float(v)))
    return out


def check():
    master, _ = lib.fso_dam_master(ORDER)
    xlsx = lib.download(master, f"{DS}.xlsx")

    dim = lib.api_meta(DS)["dimensions"]["region"]
    levels, hier = dim["levels"], dim["hierarchy"]
    regions = set(hier["ch"])
    cantons = {k for r in hier["ch"].values() for k in r}
    lab2code = {
        "GDP per canton": {levels[c]["label"]["en"]: c for c in cantons | {"ch"}},
        "GDP per region": {levels[c]["label"]["en"]: c for c in regions | {"ch"}},
    }

    wb = openpyxl.load_workbook(xlsx, data_only=True)
    recs, problems = [], []
    for sheet, mapping in lab2code.items():
        for lab, yr, v in parse_sheet(wb[sheet]):
            code = mapping.get(lab)
            if code is None:
                problems.append(f"{sheet}: source label {lab!r} has no region code in the API")
                continue
            recs.append({"region": code, "date": f"{yr}-01-01", "value": v})
    mine = pd.DataFrame(recs)

    conflicts = mine.groupby(["region", "date"])["value"].nunique()
    for (reg, d) in conflicts[conflicts > 1].index:
        problems.append(f"{reg} {d}: the two sheets disagree")
    problems = sorted(set(problems))
    mine = mine.drop_duplicates(["region", "date"])
    return lib.compare(mine, lib.api_csv(DS), ["region", "date"], problems=problems)


if __name__ == "__main__":
    only = lib.only_arg(sys.argv[1:])
    if only is None or DS in only:
        v = lib.Verdicts(f"reparse-{DS}")
        v.run(DS, check)
        v.write()
        print(v.items[0]["status"], v.items[0]["summary"])
