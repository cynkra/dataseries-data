"""Shared helpers for the verify/ checks.

Contract every check script follows (verify/run.py relies on it):

- Runs from anywhere with no required arguments: `python verify/<group>/<name>.py`.
  An optional `--only id1,id2` limits the datasets.
- No absolute paths. Repo files resolve from ROOT; downloads go to CACHE.
- Compares the upstream source with the LIVE API (DS_API, default
  https://dataseries.org), never with the local data/ files.
- Ends by writing verify/out/verdicts/<check>.json through Verdicts.write():
  one verdict per dataset, status one of
    ok           everything users receive matches (float noise, documented
                 intentional exclusions and recodings are fine)
    fail         a value, row, code, date or label users receive is wrong
    lag          upstream has periods newer than the API's latest; nothing else wrong
    unreachable  upstream could not be fetched (HTTP error, timeout, block)
    error        the checker itself broke (often: the source changed its layout)
  `fail` and `error` open a GitHub issue; `lag` and `unreachable` are reported only.
"""
from __future__ import annotations

import datetime as dt
import io
import json
import os
import tempfile
import time
import traceback
from pathlib import Path
from urllib.parse import quote, urlparse

import numpy as np
import pandas as pd
import requests

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "verify" / "out"
API = os.environ.get("DS_API", "https://dataseries.org").rstrip("/")
CACHE = Path(os.environ.get("VERIFY_CACHE") or tempfile.mkdtemp(prefix="ds-verify-"))
STATUSES = ("ok", "fail", "lag", "unreachable", "error")
HEADERS = {"User-Agent": "dataseries-verify (+https://github.com/cynkra/dataseries-data)"}

_last_hit: dict[str, float] = {}


class Unreachable(Exception):
    """The upstream source could not be fetched."""


def get(url: str, **kw) -> requests.Response:
    """GET with a per-host pause and retries; raises Unreachable when it gives up."""
    return _request("GET", url, **kw)


def post(url: str, **kw) -> requests.Response:
    """POST (e.g. a PxWeb query), same pause and retries as get()."""
    return _request("POST", url, **kw)


def _request(method: str, url: str, *, timeout: float = 90, pause: float = 1.1, retries: int = 2,
             headers: dict | None = None, **kw) -> requests.Response:
    host = urlparse(url).netloc
    for attempt in range(retries + 1):
        wait = _last_hit.get(host, 0.0) + pause - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        try:
            r = requests.request(method, url, timeout=timeout, headers={**HEADERS, **(headers or {})}, **kw)
            _last_hit[host] = time.monotonic()
            r.raise_for_status()
            return r
        except requests.RequestException as e:
            _last_hit[host] = time.monotonic()
            if attempt == retries:
                raise Unreachable(f"{url}: {e}") from e
            time.sleep(5 * (attempt + 1))
    raise AssertionError("unreachable")


def download(url: str, name: str) -> Path:
    """Download url into CACHE/name (reused within one run)."""
    path = CACHE / name
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(get(url).content)
    return path


def api_csv(dataset: str, **params: str) -> pd.DataFrame:
    """A dataset (or selection) from the live API. Codes stay strings, so a code
    such as "NA" is never read as missing; value is float, empty = NaN."""
    q = "&".join(f"{k}={quote(str(v), safe='')}" for k, v in {"dataset": dataset, **params}.items())
    r = get(f"{API}/series.csv?{q}", pause=0.2)
    # The API sends text/csv without a charset; requests would then decode as Latin-1.
    df = pd.read_csv(io.StringIO(r.content.decode("utf-8")), dtype=str, keep_default_na=False)
    df["value"] = pd.to_numeric(df["value"].replace("", None), errors="coerce")
    return df


def api_meta(dataset: str) -> dict:
    return get(f"{API}/dataset/{dataset}/meta", pause=0.2).json()


def fso_dam_master(order_nr: str) -> tuple[str, str | None]:
    """FSO order number -> (master download URL, publication date). Mirrors
    fso_asset_master() in R/source_fso_excel.R."""
    doc = get("https://dam-api.bfs.admin.ch/hub/api/dam/assets"
              f"?orderNr={quote(order_nr, safe='')}&lifecycleGroup=CURRENT").json()
    entries = doc.get("data") or []
    hit = next((e for e in entries if (e.get("shop") or {}).get("orderNr") == order_nr),
               entries[0] if entries else None)
    if hit is None:
        raise Unreachable(f"no FSO DAM asset for order number {order_nr}")
    master = next((l["href"] for l in hit.get("links", []) if l.get("rel") == "master"), None)
    if master is None:
        raise Unreachable(f"no master link for FSO order number {order_nr}")
    embargo = (hit.get("bfs") or {}).get("embargo")
    return master, (embargo[:10] if embargo else None)


def compare(src: pd.DataFrame, api: pd.DataFrame, keys: list[str], *, rtol: float = 1e-9,
            atol: float = 1e-6, problems: list[str] | tuple = ()) -> tuple[str, str, dict]:
    """Compare a parsed source with the API cell by cell -> (status, summary, details).

    Both frames carry `keys` (codes, `date` as ISO string) and a float `value`.
    Empty API values count as missing. Source cells after the API's latest date
    are `lag`; any other difference, or an entry in `problems`, is `fail`."""
    api = api.dropna(subset=["value"])
    src = src.dropna(subset=["value"])
    n_dup = int(src.duplicated(keys).sum() + api.duplicated(keys).sum())
    m = src[keys + ["value"]].merge(api[keys + ["value"]], on=keys, how="outer",
                                     suffixes=("_src", "_api"), indicator=True)
    both = m[m["_merge"] == "both"]
    bad = both[~np.isclose(both["value_src"], both["value_api"], rtol=rtol, atol=atol)]
    only_src = m[m["_merge"] == "left_only"]
    only_api = m[m["_merge"] == "right_only"]
    latest_src, latest_api = src["date"].max(), api["date"].max()
    ahead = only_src[only_src["date"] > latest_api]
    missing = only_src[only_src["date"] <= latest_api]

    def ex(df, *cols):
        d = df[keys + list(cols)].head(2)
        return d.astype(object).where(d.notna(), None).to_dict("records")

    details = {"n_compared": len(both), "n_value_mismatch": len(bad),
               "n_only_source": len(missing), "n_only_api": len(only_api),
               "n_newer_in_source": len(ahead), "n_duplicate_keys": n_dup,
               "latest_source": latest_src, "latest_api": latest_api,
               "problems": list(problems),
               "examples": (ex(bad, "value_src", "value_api") + ex(missing, "value_src")
                            + ex(only_api, "value_api"))[:5]}
    n = len(both)
    if len(bad) or len(missing) or len(only_api) or n_dup or problems:
        return "fail", (f"{n} cells compared: {len(bad)} value mismatches, {len(missing)} source cells "
                        f"missing in API, {len(only_api)} extra API cells, {n_dup} duplicate keys"
                        + (f"; {'; '.join(problems)[:200]}" if problems else "")), details
    if len(ahead):
        return "lag", (f"{n} cells match; source has {len(ahead)} newer cells "
                       f"(source latest {latest_src}, API latest {latest_api})"), details
    return "ok", f"{n} cells match (latest {latest_api})", details


def only_arg(argv: list[str]) -> set[str] | None:
    """Parse an optional `--only id1,id2` from argv."""
    if "--only" in argv:
        i = argv.index("--only")
        if i + 1 < len(argv):
            return {x for x in argv[i + 1].split(",") if x}
    return None


class Verdicts:
    """Collects one verdict per dataset and writes verify/out/verdicts/<check>.json."""

    def __init__(self, check: str):
        self.check = check
        self.items: list[dict] = []

    def add(self, dataset: str, status: str, summary: str, **details) -> None:
        if status not in STATUSES:
            raise ValueError(f"unknown status {status!r}")
        self.items.append({"dataset": dataset, "status": status, "summary": summary,
                           "details": details})

    def run(self, dataset: str, fn) -> None:
        """Call fn() -> (status, summary, details_dict) and record its verdict,
        mapping Unreachable to `unreachable` and any other exception to `error`."""
        try:
            status, summary, details = fn()
            self.add(dataset, status, summary, **(details or {}))
        except Unreachable as e:
            self.add(dataset, "unreachable", str(e)[:300])
        except Exception as e:  # the checker broke: worth a human look
            self.add(dataset, "error", f"{type(e).__name__}: {e}"[:300],
                     traceback=traceback.format_exc()[-2000:])

    def write(self) -> Path:
        path = OUT / "verdicts" / f"{self.check}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({
            "check": self.check,
            "run_utc": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "api": API,
            "verdicts": self.items,
        }, indent=1, default=str))
        return path
