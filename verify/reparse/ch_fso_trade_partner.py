"""Independent re-parse of ch_fso_trade_partner (two FSO DAM Excel masters, exports and imports),
compared cell by cell with the live API. Does not use the repo's R parser.

Layout (read from the files): one sheet each; a header row with integer years; label cells in the
first columns (exports: continent in col A, country in col B; imports: everything in col A);
labels carry footnote markers ("Total 1 2 4", "Belgium ³"); missing values are "…"/"….".
Rows end at the first footnote line (col A an int or superscript).
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib

import openpyxl
import pandas as pd

DS = "ch_fso_trade_partner"
ASSETS = {"export": "36664830", "import": "36664836"}
GROUPS = {"Total", "Europe", "EU", "Asia", "North America",
          "Central and South America", "Africa", "Oceania"}
SUPERS = "⁰¹²³⁴⁵⁶⁷⁸⁹"


def clean_label(s):
    s = str(s).strip().rstrip(SUPERS + " ")
    s = re.sub(r"(\s+\d)+$", "", s)
    return s.strip()


def parse(path, flow):
    ws = openpyxl.load_workbook(path, data_only=True).worksheets[0]
    rows = [list(r) for r in ws.iter_rows(values_only=True)]
    hdr_i = next(i for i, r in enumerate(rows)
                 if sum(isinstance(x, int) and 1900 < x < 2100 for x in r) > 10)
    ycols = {j: x for j, x in enumerate(rows[hdr_i]) if isinstance(x, int) and 1900 < x < 2100}
    first_y = min(ycols)
    out, parents, problems = [], {}, []
    cur_group = None
    for r in rows[hdr_i + 1:]:
        a = r[0]
        if isinstance(a, int) or (isinstance(a, str) and a.strip() and a.strip()[0] in SUPERS):
            break
        labs = [x for x in r[:first_y] if isinstance(x, str) and x.strip()]
        if not labs:
            if any(r[j] is not None for j in ycols):
                problems.append(f"{flow}: data row without label: {r[:5]}")
            continue
        if len(labs) != 1:
            raise ValueError(f"{flow}: ambiguous label cells {r[:first_y]}")
        partner = clean_label(labs[0])
        level = "group" if partner in GROUPS else "country"
        if level == "group" and partner not in ("Total", "EU"):
            cur_group = partner
        elif partner != "Total":
            parents[partner] = cur_group
        for j, y in ycols.items():
            v = r[j]
            if v is None or (isinstance(v, str) and set(v.strip()) <= set("….")):
                continue
            if isinstance(v, str):
                v = float(v.replace("'", "").replace(" ", ""))
            out.append({"flow": flow, "partner": partner, "level": level,
                        "date": f"{y}-01-01", "value": float(v)})
    return out, parents, problems


def api_parents(meta):
    par = {}
    for cont, kids in meta["dimensions"]["partner"]["hierarchy"]["Total"].items():
        par[cont] = "Total"
        for k in kids:
            par[k] = cont
    return par


def check():
    recs, problems, src_parents = [], [], {}
    for flow, asset in ASSETS.items():
        path = lib.download(f"https://dam-api.bfs.admin.ch/hub/api/dam/assets/{asset}/master",
                            f"{DS}_{asset}.xlsx")
        r, parents, p = parse(path, flow)
        recs += r
        problems += p
        for partner, group in parents.items():
            src_parents.setdefault(partner, {})[flow] = group
    ap = api_parents(lib.api_meta(DS))
    for partner, by_flow in sorted(src_parents.items()):
        for flow, group in by_flow.items():
            if ap.get(partner) != group:
                problems.append(f"{flow}: {partner} sits under {group} in the source "
                                f"but under {ap.get(partner)} in the API hierarchy")
    return lib.compare(pd.DataFrame(recs), lib.api_csv(DS), ["flow", "partner", "level", "date"],
                       problems=problems)


if __name__ == "__main__":
    only = lib.only_arg(sys.argv[1:])
    if only is None or DS in only:
        v = lib.Verdicts(f"reparse-{DS}")
        v.run(DS, check)
        v.write()
        print(v.items[0]["status"], v.items[0]["summary"])
