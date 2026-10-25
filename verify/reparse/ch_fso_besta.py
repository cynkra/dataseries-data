"""Independent re-parse of ch_fso_besta (FSO PX cube px-x-0602000000_101, fetched via the
DAM asset API) and cell-by-cell comparison with the live API.

The parser is written from the PX file format only: header entries KEYWORD[lang](args)=value;
then DATA= with the flattened cube, STUB dims then HEADING dims, last dim varying fastest.
Slice: Beschaeftigungsgrad=TOT, Geschlecht=TOT. The API rounds to whole jobs.
"""
import itertools
import math
import re
import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib

DATASET = "ch_fso_besta"
ORDER = "px-x-0602000000_101"
DIM = "Wirtschaftsabteilung"
SLICE = {"Beschäftigungsgrad": "TOT", "Geschlecht": "TOT"}
MISSING = {"", ".", "..", "...", "....", "-", ":"}


def quoted(s):
    return [x.replace('""', '"') for x in re.findall(r'"((?:[^"]|"")*)"', s)]


def header_entries(head):
    entries, buf, in_quote = [], [], False
    for ch in head:
        if ch == '"':
            in_quote = not in_quote
        if ch == ";" and not in_quote:
            entries.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
    return entries


def parse_px(path):
    raw = path.read_bytes()
    try:
        txt = raw.decode("utf-8")
    except UnicodeDecodeError:
        txt = raw.decode("cp1252")
    head, data = txt.split("DATA=", 1)
    kw = {}
    for e in header_entries(head):
        m = re.match(r"^([A-Z0-9-]+)(?:\[(\w+)\])?(?:\((.*?)\))?=(.*)$", e, re.S)
        if m:
            key, lang, arg, val = m.groups()
            kw[(key, lang or "de", tuple(quoted(arg)) if arg else None)] = val.replace("\r", "").replace("\n", "")
    dims = quoted(kw[("STUB", "de", None)]) + quoted(kw[("HEADING", "de", None)])
    codes = {d: quoted(kw[("CODES", "de", (d,))]) for d in dims}
    toks = re.findall(r'"[^"]*"|[^\s"]+', data.strip().rstrip(";"))
    sizes = [len(codes[d]) for d in dims]
    if len(toks) != math.prod(sizes):
        raise ValueError(f"DATA has {len(toks)} cells, expected {math.prod(sizes)} = {sizes}")
    return dims, codes, toks


def source_cells():
    master, _ = lib.fso_dam_master(ORDER)
    dims, codes, toks = parse_px(lib.download(master, f"{DATASET}.px"))
    if dims != [DIM, "Beschäftigungsgrad", "Geschlecht", "Quartal"]:
        raise ValueError(f"unexpected cube dimensions {dims}")
    for d, c in SLICE.items():
        if c not in codes[d]:
            raise ValueError(f"{d} has no item {c}")
    rows = []
    for idx, tup in enumerate(itertools.product(*[range(len(codes[d])) for d in dims])):
        cd = {d: codes[d][i] for d, i in zip(dims, tup)}
        if any(cd[d] != c for d, c in SLICE.items()):
            continue
        tok = toks[idx].strip('"')
        if tok in MISSING:
            continue
        m = re.fullmatch(r"(\d{4})Q([1-4])", cd["Quartal"])
        if not m:
            raise ValueError(f"unexpected quarter code {cd['Quartal']}")
        rows.append((cd[DIM], f"{m.group(1)}-{(int(m.group(2)) - 1) * 3 + 1:02d}-01", float(tok)))
    return pd.DataFrame(rows, columns=["code", "date", "value"])


def check():
    mine = source_cells()
    api = lib.api_csv(DATASET).rename(columns={DIM: "code"})
    return lib.compare(mine, api, ["code", "date"], rtol=0, atol=0.5)


if __name__ == "__main__":
    only = lib.only_arg(sys.argv[1:])
    verdicts = lib.Verdicts(f"reparse-{DATASET}")
    if only is None or DATASET in only:
        verdicts.run(DATASET, check)
    print(verdicts.write())
    for v in verdicts.items:
        print(v["dataset"], v["status"], v["summary"])
