"""Delivery-chain check ("chain"): does every layer hand users the same data?

For every dataset in the live /catalog it compares

  product      data/{id}.csv, data/{id}.json and data/catalog.json in this checkout
  API CSV      /series.csv (whole dataset and a few selections)
  API JSON     /series (same selections, full precision like the CSV)
  Python       the PyPI package `dataseries`
  R            the CRAN package `dataseries` (results written by chain.R)

plus edge-case probes (numeric codes, the literal SNB code "NA", from/to bounds,
multi-code selections, wide/ts output, discovery functions).

    python -I verify/chain/chain.py plan      # verify/out/chain/plan.json
    Rscript verify/chain/chain.R              # verify/out/chain/r/*.json
    python -I verify/chain/chain.py compare   # verify/out/verdicts/chain.json

Product and API legitimately differ until the server's hourly sync picks up a data
commit. Product-vs-API differences are `fail` only when the API's catalog `fetched`
stamp equals the product's; otherwise they are `lag`.
"""
from __future__ import annotations

import csv
import http.client
import importlib.metadata
import io
import json
import math
import sys
import time
import traceback
from pathlib import Path
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lib  # noqa: E402

DATA = lib.ROOT / "data"
WORK = lib.OUT / "chain"
PAUSE = 0.2
NOISE = 1e-12
SHOWN = 5

SINGLE_CODES = {
    "ch_fso_cpi": {"item": ["100_100"]},
    "ch_fso_cross_border_commuters": {"canton": ["1", "10"]},
    "ch_fso_jobs_sex": {"Grossregion": ["0"], "Wirtschaftssektor": ["2"], "Beschäftigungsgrad": ["4.1"],
                        "Geschlecht": ["TOT"]},
    "ch_snb_zavesic": {"D0": ["50009999990", "149990"]},
    "ch_fso_ppi": {"base": ["1963"]},
    "ch_snb_zikrepro": {"D0": ["025Q", "05Q"], "D1": ["11"]},
    "ch_fso_besta": {"Wirtschaftsabteilung": ["77+79-82"]},
    "ch_fso_trade_partner": {"partner": ["Korea (South)", "Hong Kong"], "flow": ["export"], "level": ["country"]},
    "ch_seco_gdp": {"seas_adj": ["na"], "type": ["real"], "structure": ["gdp"]},
}
BOUNDS = [
    ("ch_fso_cpi", {"item": "100_100"}, "2025-01-01", "2025-06-01"),
    ("ch_seco_gdp", {"type": "real", "structure": "gdp", "seas_adj": "csa"}, "2020-04-01", "2021-01-01"),
    ("ch_fso_pop", {"item": "pop_stock_jan"}, "2010-01-01", "2012-01-01"),
    ("ch_fso_cpi", {"item": "100_100"}, "2025-01-15", "2025-06-15"),
    ("ch_snb_devwkieffid", {"D0": "K", "D1": "G"}, "2026-01-05", "2026-01-09"),
]
WIDE = {
    "ch_fso_ppi": {"base": ["1963", "2020"]},
    "ch_fso_cpi": {"item": ["100_100", "100_10100", "100_9726"]},
    "ch_fso_jobs_sex": {"Grossregion": ["0"], "Wirtschaftssektor": ["TOT"], "Beschäftigungsgrad": ["TOT"],
                        "Geschlecht": ["1", "2"]},
}
MULTI = {
    "ch_fso_cpi": ("item", ["100_100", "100_1"], {}),
    "ch_seco_gdp": ("structure", ["gdp", "gva"], {"type": ["real"], "seas_adj": ["csa"]}),
    "ch_fso_trade_partner": ("partner", ["Korea (South)", "Hong Kong"], {"flow": ["export"], "level": ["country"]}),
}
DIM_NAMES = {
    "ch_fso_vacancies": {"Offene Stellen": "1", "Wirtschaftsabteilung": "5-96"},
    "ch_fso_jobs_sex": {"Grossregion": "0", "Wirtschaftssektor": "TOT", "Beschäftigungsgrad": "TOT",
                        "Geschlecht": "TOT"},
}
NA_CODE = "ch_snb_bopcapbalq"
ANCHOR = "ch_fso_cpi"


# --------------------------------------------------------------------------
# API access and parsing
# --------------------------------------------------------------------------

class ApiError(Exception):
    def __init__(self, path: str, status: int):
        super().__init__(f"HTTP {status} for {lib.API}{path}")
        self.status = status


def fetch(path: str) -> str:
    try:
        return lib.get(lib.API + path, pause=PAUSE, timeout=120).content.decode("utf-8")
    except lib.Unreachable as e:
        resp = getattr(e.__cause__, "response", None)
        if resp is not None:
            raise ApiError(path, resp.status_code) from e
        raise


def fetch_json(path: str):
    return json.loads(fetch(path))


def dims_spec(dims: dict) -> str:
    return ";".join(f"{k}={','.join(v)}" for k, v in dims.items())


def series_qs(i: str, dims: dict, frm: str | None = None, to: str | None = None) -> str:
    qs = [f"dataset={quote(i, safe='')}"]
    if dims:
        qs.append("dims=" + quote(dims_spec(dims), safe=""))
    if frm:
        qs.append(f"from={frm}")
    if to:
        qs.append(f"to={to}")
    return "&".join(qs)


def parse_csv(text: str):
    """Tidy CSV text -> (header, {(codes..., date): value string}, duplicate keys)."""
    rows = list(csv.reader(io.StringIO(text)))
    if not rows:
        return [], {}, 0
    out, dups = {}, 0
    for r in rows[1:]:
        k = tuple(r[:-1])
        dups += k in out
        out[k] = r[-1]
    return rows[0], out, dups


_product: dict = {}


def product_rows(i: str):
    if i not in _product:
        _product[i] = parse_csv((DATA / f"{i}.csv").read_text(encoding="utf-8"))
    return _product[i]


def filter_rows(hdr, rows, dims, frm=None, to=None):
    idx = {h: n for n, h in enumerate(hdr)}
    return {k: v for k, v in rows.items()
            if all(k[idx[d]] in codes for d, codes in dims.items())
            and not (frm and k[-1] < frm) and not (to and k[-1] > to)}


def aslist(x) -> list:
    """jsonlite unboxes length-1 vectors; undo that."""
    return [] if x is None else x if isinstance(x, list) else [x]


# --------------------------------------------------------------------------
# value comparison
# --------------------------------------------------------------------------

def fnum(s):
    if s is None:
        return None
    if isinstance(s, float):
        return None if math.isnan(s) else s
    s = str(s)
    return None if s in ("", "NA", "NaN", "nan", "null") else float(s)


def same(a, b) -> bool:
    x, y = fnum(a), fnum(b)
    if x is None or y is None:
        return x is y
    return x == y or abs(x - y) <= NOISE * max(abs(x), abs(y))


def diff_maps(a: dict, b: dict, na: str, nb: str, close=same) -> dict | None:
    """Compare {key: value} maps; None when equal, else counts and up to 5 examples."""
    only_a, only_b = sorted(set(a) - set(b)), sorted(set(b) - set(a))
    bad = [k for k in sorted(set(a) & set(b)) if not close(a[k], b[k])]
    if not (only_a or only_b or bad):
        return None
    examples = ([f"only in {na}: {'/'.join(k)}" for k in only_a[:2]]
                + [f"only in {nb}: {'/'.join(k)}" for k in only_b[:2]]
                + [f"{'/'.join(k)}: {na}={a[k]} {nb}={b[k]}" for k in bad[:SHOWN]])[:SHOWN]
    return {f"only_{na}": len(only_a), f"only_{nb}": len(only_b), "value_mismatch": len(bad),
            "examples": examples}


def deep_diff(a, b, path="", out=None, limit=SHOWN) -> list[str]:
    out = [] if out is None else out
    if len(out) >= limit:
        return out
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b), key=str):
            if k not in a:
                out.append(f"{path}/{k}: only in API")
            elif k not in b:
                out.append(f"{path}/{k}: only in product")
            else:
                deep_diff(a[k], b[k], f"{path}/{k}", out, limit)
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            out.append(f"{path}: list length {len(a)} (product) vs {len(b)} (API)")
        for n, (x, y) in enumerate(zip(a, b)):
            deep_diff(x, y, f"{path}[{n}]", out, limit)
    elif a != b and not (a is None and b == {}):
        out.append(f"{path}: {a!r} (product) vs {b!r} (API)")
    return out


def py_map(df) -> dict:
    """Python ds() frame -> {(codes..., date): value}; a missing code shows as <NaN>."""
    dimcols = [c for c in df.columns if c not in ("date", "value")]
    out = {}
    for rec in df.to_dict("records"):
        codes = tuple(rec[c] if isinstance(rec[c], str) else "<NaN>" for c in dimcols)
        out[codes + (rec["date"].strftime("%Y-%m-%d"),)] = rec["value"]
    return out


def r_map(rj: dict) -> dict:
    if rj.get("null"):
        return {}
    cols, data = aslist(rj["columns"]), rj["data"]
    dimcols = [c for c in cols if c not in ("date", "value")]
    return {tuple("<NA>" if data[c][n] is None else data[c][n] for c in dimcols) + (data["date"][n],): data["value"][n]
            for n in range(len(aslist(data["date"])))}


class Package:
    """The Python package, with transient network errors retried and then reported as unreachable."""

    def __init__(self, module):
        self._module = module

    def __getattr__(self, name):
        fn = getattr(self._module, name)

        def call(*args, **kwargs):
            for attempt in range(3):
                try:
                    return fn(*args, **kwargs)
                except (http.client.HTTPException, TimeoutError) as e:
                    if attempt == 2:
                        raise lib.Unreachable(f"dataseries.{name}: {type(e).__name__}: {e}") from e
                    time.sleep(5 * (attempt + 1))
        return call


# --------------------------------------------------------------------------
# report
# --------------------------------------------------------------------------

class Report:
    """Problems found for one dataset. `lagging`: the API has not synced the product yet."""

    def __init__(self, lagging: bool):
        self.lagging = lagging
        self.issues: list[dict] = []
        self.lag: list[dict] = []
        self.notes: list[str] = []
        self.stats: dict = {}

    def fail(self, layers: str, problem: str, **evidence) -> None:
        self.issues.append({"layers": layers, "problem": problem, **evidence})

    def product_vs_api(self, problem: str, **evidence) -> None:
        (self.lag if self.lagging else self.issues).append(
            {"layers": "product,api", "problem": problem, **evidence})

    def verdict(self, fetched: dict, packages: dict):
        details = {"packages": packages, "fetched": fetched, **self.stats}
        if self.notes:
            details["notes"] = self.notes[:10]
        if self.issues:
            layers = sorted({layer for x in self.issues for layer in x["layers"].split(",")})
            first = "; ".join(x["problem"] for x in self.issues[:2])
            summary = f"{len(self.issues)} problem(s) across {', '.join(layers)}: {first}"
            return "fail", summary[:400], {**details, "issues": self.issues[:20], "lag": self.lag[:5]}
        if self.lag:
            summary = (f"server has not synced yet (product fetched {fetched['product']}, API {fetched['api']}); "
                       f"product differs from API: {self.lag[0]['problem']}")
            return "lag", summary[:400], {**details, "lag": self.lag[:10]}
        return "ok", "product, API CSV/JSON, Python and R agree", details


# --------------------------------------------------------------------------
# plan
# --------------------------------------------------------------------------

def make_plan(only):
    plan = []
    for d in fetch_json("/catalog"):
        i = d["id"]
        if (only and i not in only) or not (DATA / f"{i}.csv").exists():
            continue
        meta = fetch_json(f"/dataset/{quote(i, safe='')}/meta")
        dims = meta.get("dim_order") or []
        default = meta.get("default") if isinstance(meta.get("default"), dict) else {}
        sels = [("single", {})]
        if dims:
            base = {k: [v] for k, v in default.items() if k in dims}
            sels = [("default", dict(base))]
            split = meta.get("split")
            if split in dims:
                levels = [c for c, lv in meta["dimensions"][split]["levels"].items() if lv.get("data", True)]
                for label, code in (("split_first", levels[0]), ("split_last", levels[-1])):
                    s = {**base, split: [code]}
                    if all(s != x[1] for x in sels):
                        sels.append((label, s))
        hdr, rows, _ = product_rows(i)
        for label, s in sels:
            if label.startswith("split") and not filter_rows(hdr, rows, s):
                n = hdr.index(meta["split"])
                keys = sorted(k for k in rows if k[n] == s[meta["split"]][0])
                if keys:
                    s, label = {x: [keys[0][hdr.index(x)]] for x in dims}, label + "_fallback"
            plan.append({"id": i, "sel": label, "dims": s, "dim_order": dims})
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / "plan.json").write_text(json.dumps(plan, indent=1, ensure_ascii=False))
    print(f"plan: {len(plan)} selections over {len({p['id'] for p in plan})} datasets")


# --------------------------------------------------------------------------
# per-selection comparison
# --------------------------------------------------------------------------

def check_selection(rep: Report, i: str, p: dict, dsmod) -> int:
    sel, dims = p["sel"], p["dims"]
    where = f"{sel} dims={dims_spec(dims) or '-'}"
    qs = series_qs(i, dims)
    try:
        hdr, api, dups = parse_csv(fetch(f"/series.csv?{qs}"))
    except ApiError as e:
        rep.product_vs_api(f"API /series.csv failed for {where}: {e}")
        return 0
    if "value" not in hdr:
        rep.fail("api", f"API /series.csv for {where} has no value column", header=hdr)
        return 0
    if dups:
        rep.fail("api", f"{dups} duplicate (codes, date) keys in /series.csv for {where}")

    phdr, prows, _ = product_rows(i)
    if phdr != hdr:
        rep.product_vs_api(f"CSV header differs for {where}", product=phdr, api=hdr)
    diff = diff_maps(filter_rows(phdr, prows, dims), api, "product", "api")
    if diff:
        rep.product_vs_api(f"product and API CSV differ for {where}", **diff)

    try:
        j = json.loads(fetch(f"/series?{qs}"))
    except ApiError as e:
        rep.fail("api", f"API /series (JSON) failed for {where}: {e}")
    else:
        jcols = [c for c in j if c not in ("date", "value")]
        jm = {tuple(j[c][n] for c in jcols) + (j["date"][n],): j["value"][n] for n in range(len(j.get("date", [])))}
        diff = diff_maps(api, jm, "csv", "json")
        if diff:
            rep.fail("api", f"API CSV and JSON differ for {where}", **diff)

    if not api:
        rep.notes.append(f"{where}: API returns no rows (product has {len(filter_rows(phdr, prows, dims))})")
    try:
        df = dsmod.ds(i, dims=dims)
    except Exception as e:  # noqa: BLE001
        if api:
            rep.fail("python", f"Python ds() raised for {where}: {type(e).__name__}: {str(e)[:200]}")
    else:
        if df is not None and len(df) and list(df.columns) != hdr:
            rep.fail("python", f"Python columns differ from API header for {where}",
                     python=list(df.columns), api=hdr)
        diff = diff_maps(api, py_map(df) if df is not None and len(df) else {}, "api", "python")
        if diff:
            rep.fail("python,api", f"Python ds() differs from API CSV for {where}", **diff)

    path = WORK / "r" / f"{i}__{sel}.json"
    rj = json.loads(path.read_text()) if path.exists() else None
    if rj is None:
        raise RuntimeError(f"R result missing: {path.name}")
    rep.stats["r_version"] = rj.get("version")
    if rj.get("error"):
        if api:
            rep.fail("r", f"R ds() raised for {where}: {str(rj['error'])[:200]}")
    else:
        if not rj.get("null") and aslist(rj["columns"]) != hdr:
            rep.fail("r", f"R columns differ from API header for {where}", r=aslist(rj["columns"]), api=hdr)
        diff = diff_maps(api, r_map(rj), "api", "r")
        if diff:
            rep.fail("r,api", f"R ds() differs from API CSV for {where}", **diff)
    return len(api)


# --------------------------------------------------------------------------
# product / catalog / meta
# --------------------------------------------------------------------------

def check_product(rep: Report, i: str, api_entry: dict, prod_entry: dict, api_meta: dict):
    prod_meta = json.loads((DATA / f"{i}.json").read_text())
    hdr, rows, dups = product_rows(i)
    dates = sorted({k[-1] for k in rows})
    if dups:
        rep.fail("product", f"{dups} duplicate (codes, date) keys in data/{i}.csv")
    dim_order = prod_meta.get("dim_order") or []
    if hdr[:-2] != dim_order:
        rep.fail("product", "data CSV dimension columns differ from meta dim_order", csv=hdr[:-2], meta=dim_order)
    for n, dim in enumerate(dim_order):
        unknown = sorted({k[n] for k in rows} - set(prod_meta["dimensions"][dim]["levels"]))
        if unknown:
            rep.fail("product", f"codes in data/{i}.csv missing from meta levels of {dim}", codes=unknown[:SHOWN])
    if dates and (prod_entry.get("start"), prod_entry.get("end")) != (dates[0], dates[-1]):
        rep.fail("product", "data/catalog.json start/end disagree with data CSV",
                 catalog=[prod_entry.get("start"), prod_entry.get("end")], csv=[dates[0], dates[-1]])

    for k in ("start", "end", "frequency"):
        if str(api_entry.get(k)) != str(api_meta.get(k)):
            rep.fail("api", f"/catalog {k} disagrees with /dataset/{i}/meta {k}",
                     catalog=api_entry.get(k), meta=api_meta.get(k))

    drop = lambda d: {k: v for k, v in d.items() if k != "fetched"}  # noqa: E731
    for what, prod, api in (("catalog entry", drop(prod_entry), drop(api_entry)),
                            ("meta", prod_meta, api_meta)):
        diff = deep_diff(prod, api)
        if diff:
            rep.product_vs_api(f"{what} differs between product and API", examples=diff)

    try:
        _, api_all, api_dups = parse_csv(fetch(f"/series.csv?dataset={quote(i, safe='')}"))
    except ApiError as e:
        rep.product_vs_api(f"API /series.csv?dataset={i} failed: {e}")
        return
    if api_dups:
        rep.fail("api", f"{api_dups} duplicate keys in whole-dataset /series.csv")
    diff = diff_maps(rows, api_all, "product", "api")
    if diff:
        rep.product_vs_api("whole dataset: product CSV and API CSV differ", **diff)
    rep.stats["cells_product"] = len(rows)
    rep.stats["cells_api"] = len(api_all)


# --------------------------------------------------------------------------
# Python edge-case probes
# --------------------------------------------------------------------------

def probe_codes(dsmod, i, want):
    df = dsmod.ds(i, dims=want)
    got = {c: sorted({repr(v) for v in df[c]}) for c in want if c in df.columns}
    wanted = {c: sorted(repr(v) for v in want[c]) for c in want}
    return None if got == wanted else f"requested codes {wanted}, got {got}"


def probe_na_code(dsmod):
    df = dsmod.ds(NA_CODE, D0="NA", D1="A")
    values = sorted({repr(v) for v in df["D0"]}) if df is not None else []
    problems = []
    if values != ["'NA'"]:
        problems.append(f'ds(D0="NA", D1="A") returns D0 values {values} ({0 if df is None else len(df)} rows)')
    try:
        dsmod.ds(NA_CODE, D0=["NA", "S"], D1="A", wide=True)
    except Exception as e:  # noqa: BLE001
        problems.append(f"wide=True with D0 in (NA, S) raised {type(e).__name__}: {str(e)[:120]}")
    return problems


def probe_bounds(dsmod, i, d, frm, to):
    df = dsmod.ds(i, start=frm, end=to, **d)
    py = [x.strftime("%Y-%m-%d") for x in df["date"]] if df is not None else []
    one = {k: [v] for k, v in d.items()}
    _, api, _ = parse_csv(fetch("/series.csv?" + series_qs(i, one, frm, to)))
    phdr, prows, _ = product_rows(i)
    prod = sorted({k[-1] for k in filter_rows(phdr, prows, one, frm, to)})
    return py, sorted({k[-1] for k in api}), prod


def probe_wide(dsmod, i, d):
    long, wide = dsmod.ds(i, dims=d), dsmod.ds(i, dims=d, wide=True)
    dimcols = [c for c in long.columns if c not in ("date", "value")]
    bad = sum(wide.loc[r["date"], ".".join(r[c] for c in dimcols)] != r["value"] for r in long.to_dict("records"))
    return bad, int(wide.notna().sum().sum()), len(long)


def probe_multi(dsmod, i, dim, codes, rest):
    both = py_map(dsmod.ds(i, dims={**rest, dim: codes}))
    union = {}
    for c in codes:
        part = dsmod.ds(i, dims={**rest, dim: [c]})
        if part is not None:
            union.update(py_map(part))
    return diff_maps(both, union, "multi", "union")


def python_probes(rep: Report, i: str, dsmod, metas: dict) -> None:
    def run(name, fn):
        try:
            fn()
        except lib.Unreachable:
            raise
        except Exception as e:  # noqa: BLE001
            rep.fail("python", f"probe {name} raised {type(e).__name__}: {str(e)[:200]}",
                     traceback=traceback.format_exc()[-600:])

    def codes():
        problem = probe_codes(dsmod, i, SINGLE_CODES[i])
        if problem:
            rep.fail("python", f"Python ds() alters dimension codes: {problem}")

    def na_code():
        for problem in probe_na_code(dsmod):
            rep.fail("python", f'dimension code "NA" is lost: {problem}')

    def bounds():
        for d_i, d, frm, to in BOUNDS:
            if d_i != i:
                continue
            py, api, prod = probe_bounds(dsmod, i, d, frm, to)
            if py != api:
                rep.fail("python,api", f"from/to {frm}..{to}: Python dates differ from API", python=py[:SHOWN], api=api[:SHOWN])
            if api != prod:
                rep.product_vs_api(f"from/to {frm}..{to}: API dates differ from product (inclusive bounds)",
                                   api=api[:SHOWN], product=prod[:SHOWN])

    def wide():
        bad, nonnull, rows = probe_wide(dsmod, i, WIDE[i])
        if bad or nonnull != rows:
            rep.fail("python", "wide=True misaligns values", misaligned=bad, non_null_cells=nonnull, long_rows=rows)

    def multi():
        diff = probe_multi(dsmod, i, *MULTI[i])
        if diff:
            rep.fail("python", "multi-code selection differs from union of single-code selections", **diff)

    def dim_names():
        df = dsmod.ds(i, dims=DIM_NAMES[i])
        if list(df.columns) != list(metas[i]["dim_order"]) + ["date", "value"]:
            rep.fail("python", "Python columns differ from meta dim_order", columns=list(df.columns))

    def missing():
        _, api, _ = parse_csv(fetch(f"/series.csv?dataset={i}"))
        n_api = sum(v in ("", "NA", "NaN", "null") for v in api.values())
        n_py = int(dsmod.ds(i)["value"].isna().sum())
        if n_api != n_py:
            rep.fail("python,api", "missing values differ", api_empty=n_api, python_nan=n_py)

    if i in SINGLE_CODES:
        run("numeric_codes", codes)
    if i == NA_CODE:
        run("na_code", na_code)
    if any(b[0] == i for b in BOUNDS):
        run("from_to", bounds)
    if i in WIDE:
        run("wide", wide)
    if i in MULTI:
        run("multi_code", multi)
    if i in DIM_NAMES:
        run("dim_names", dim_names)
    if i == "ch_fso_ppi":
        run("missing_values", missing)

    def notes():
        for name, call in (("unknown code", lambda: dsmod.ds(ANCHOR, item="nonexistent")),
                           ("integer code", lambda: dsmod.ds("ch_fso_cross_border_commuters", canton=1))):
            try:
                call()
            except Exception as e:  # noqa: BLE001
                rep.notes.append(f"Python {name}: {type(e).__name__}: {str(e)[:120]}")

    if i == ANCHOR:
        notes()


def python_discovery(dsmod, api_cat: list, scope: set, meta) -> dict[str, list[str]]:
    """Problems of ds_catalog / ds_search / ds_meta, keyed by dataset id."""
    found: dict[str, list[str]] = {}

    def add(i, msg):
        if i in scope:
            found.setdefault(i, []).append(msg)

    api = {d["id"]: d for d in api_cat}
    for row in dsmod.ds_catalog().itertuples(index=False):
        d = api[row.id]
        expected = (("title", d["title"]["en"]), ("frequency", d["frequency"]), ("start", d["start"]),
                    ("end", d["end"]), ("n_series", d.get("n_series")), ("topic", d["topic"]["key"]),
                    ("source", d["source"]["name"]["en"] if isinstance(d["source"], dict) else d["source"]),
                    ("concept", d["concept"].get("en") if isinstance(d.get("concept"), dict) else d.get("concept")),
                    ("license", d.get("license") if isinstance(d.get("license"), str) else None))
        for col, want in expected:
            got = getattr(row, col)
            if not (got == want or (isinstance(got, float) and math.isnan(got) and want is None)):
                add(row.id, f"ds_catalog() {col}={got!r}, API /catalog {want!r}")
    searchable = set()
    for row in dsmod.ds_search().itertuples(index=False):
        if row.dataset not in scope:
            continue
        searchable.add((row.dataset, row.dim, row.code))
        levels = meta(row.dataset)["dimensions"].get(row.dim, {}).get("levels", {}) if row.dim else {}
        if row.dim and row.code not in levels:
            add(row.dataset, f"ds_search() lists code {row.code!r} of {row.dim} that meta does not have")
        elif row.dim and levels[row.code]["label"]["en"] != row.label:
            add(row.dataset, f"ds_search() label {row.label!r} for {row.dim}={row.code} differs from meta")
    for i in scope:
        m = meta(i)
        split = m.get("split")
        for c in ([c for c, lv in m["dimensions"][split]["levels"].items() if lv.get("data", True)] if split else []):
            if (i, split, c) not in searchable:
                add(i, f"ds_search() misses {split}={c}")
        if dsmod.ds_meta(i) != m:
            add(i, "ds_meta() differs from the API meta")
    return found


# --------------------------------------------------------------------------
# R edge-case probes (results written by chain.R)
# --------------------------------------------------------------------------

def r_probes(rep: Report, i: str, E: dict, api_dates: dict) -> None:
    def part(name, key=None):
        v = E.get(name, {})
        if "exception" in v:
            rep.fail("r", f"R probe {name} raised: {str(v['exception'])[:200]}")
            return None
        return v if key is None else v.get(key)

    v = part("numeric_codes_strings", i)
    if v is not None and not v.get("ok"):
        rep.fail("r", "R ds() alters dimension codes", requested=v.get("requested"), got=v.get("got"))

    if i == NA_CODE:
        v = part("na_code")
        if v is not None:
            values = aslist(v.get("D0_values"))
            if values != ["NA"]:
                rep.fail("r", 'dimension code "NA" is lost in R ds()',
                         rows=v.get("rows"), D0_values=values, D0_is_na=v.get("D0_is_na"))
            if str(v.get("ts_colnames", "")).startswith("ERROR"):
                rep.fail("r", 'class="ts" fails for the code "NA"', error=v["ts_colnames"])

    for key, v in (part("from_to_inclusive") or {}).items():
        if key.split()[0] != i:
            continue
        r_dates = aslist(v.get("dates_chr"))
        if not v.get("same"):
            rep.fail("r", f"from/to {key}: character and Date bounds give different results")
        if key in api_dates and r_dates != api_dates[key]:
            rep.fail("r,api", f"from/to {key}: R dates differ from API", r=r_dates[:SHOWN], api=api_dates[key][:SHOWN])

    v = part("multi_code", i)
    if v is not None and not v.get("equal"):
        rep.fail("r", "multi-code selection differs from union of single-code selections",
                 n_multi=v.get("n_multi"), n_union=v.get("n_union"))
    v = part("wide_ts", i)
    if v is not None and not v.get("ok"):
        rep.fail("r", 'class="ts" misaligns values', misaligned=v.get("misaligned"), non_null=v.get("nonnull"),
                 long_rows=v.get("long_rows"))

    v = part("ts_frequency", i)
    if v is not None and aslist(v.get("tsp"))[2:3] == [4] and i == "ch_fso_construction_prices":
        rep.notes.append("R class='ts' turns the semi-annual series into a quarterly ts padded with NA")

    v = part("discovery")
    if v is not None:
        for m in aslist(v.get("field_mismatches")):
            if m.get("id") == i:
                rep.fail("r", f"ds_catalog() {m.get('col')}={m.get('got')!r}, API /catalog {m.get('want')!r}")
        if i in aslist(v.get("meta_not_identical")):
            rep.fail("r", "ds_meta() differs from the API meta")
        if i in aslist(v.get("search_na_datasets")):
            rep.fail("r", "ds_search() returns a missing code (the literal code \"NA\" is lost)")
    if i == ANCHOR:
        v = part("errors")
        if v is not None:
            rep.notes.append(f"R unknown code: {str(v.get('unknown_code'))[:120]}")


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------

def compare(only):
    import dataseries

    dsmod = Package(dataseries)

    packages = {"python": importlib.metadata.version("dataseries"), "r": None}
    session = WORK / "r" / "_session.json"
    if session.exists():
        packages["r"] = json.loads(session.read_text()).get("version")
    plan = json.loads((WORK / "plan.json").read_text())
    r_edge = json.loads((WORK / "r" / "_edge.json").read_text())

    api_cat = fetch_json("/catalog")
    api = {d["id"]: d for d in api_cat}
    prod = {d["id"]: d for d in json.loads((DATA / "catalog.json").read_text())}
    ids = sorted(i for i in set(api) | set(prod) if not only or i in only)
    metas: dict = {}

    def meta(i):
        if i not in metas:
            metas[i] = fetch_json(f"/dataset/{quote(i, safe='')}/meta")
        return metas[i]

    scope = {i for i in ids if i in api and i in prod}
    reports = {i: Report(lagging=api.get(i, {}).get("fetched") != prod.get(i, {}).get("fetched")) for i in ids}
    discovery, discovery_error = {}, None
    try:
        discovery = python_discovery(dsmod, api_cat, scope, meta)
    except Exception as e:  # noqa: BLE001
        discovery_error = e

    api_dates: dict = {}
    for d_i, d, frm, to in BOUNDS:
        if d_i in scope:
            _, rows, _ = parse_csv(fetch("/series.csv?" + series_qs(d_i, {k: [v] for k, v in d.items()}, frm, to)))
            api_dates[f"{d_i} {frm} {to}"] = sorted({k[-1] for k in rows})

    verdicts = lib.Verdicts("chain")

    def check(i):
        rep = reports[i]
        fetched = {"product": prod.get(i, {}).get("fetched"), "api": api.get(i, {}).get("fetched")}
        if i not in scope:
            where = "API" if i in api else "product"
            rep.product_vs_api(f"dataset only in the {where} catalog")
            return rep.verdict(fetched, packages)
        if i == ANCHOR and discovery_error:
            raise discovery_error
        cells = sum(check_selection(rep, i, p, dsmod) for p in plan if p["id"] == i)
        rep.stats.update(selections=[p["sel"] for p in plan if p["id"] == i], cells_in_selections=cells)
        check_product(rep, i, api[i], prod[i], meta(i))
        python_probes(rep, i, dsmod, metas)
        r_probes(rep, i, r_edge, api_dates)
        for msg in discovery.get(i, []):
            rep.fail("python", msg)
        return rep.verdict(fetched, packages)

    for i in ids:
        verdicts.run(i, lambda i=i: check(i))
    path = verdicts.write()
    counts = {s: sum(v["status"] == s for v in verdicts.items) for s in lib.STATUSES}
    print(f"wrote {path}: " + " ".join(f"{s}={n}" for s, n in counts.items() if n))
    for v in verdicts.items:
        if v["status"] != "ok":
            print(f"[{v['status']}] {v['dataset']}: {v['summary'][:200]}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "compare"
    only = lib.only_arg(sys.argv)
    make_plan(only) if cmd == "plan" else compare(only)
