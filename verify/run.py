"""Run every check in verify/ and merge their verdicts.

  python verify/run.py                    all checks
  python verify/run.py --only snb,chain   checks whose name contains one of these

Writes verify/out/summary.json and verify/out/summary.md (also appended to
$GITHUB_STEP_SUMMARY when set). Always exits 0: verify/issues.py turns `fail`
and `error` verdicts into GitHub issues, the way the datasheet guards report
rather than gate.

Checks sharing an upstream host run one after another, so no host gets more
than one checker at a time; different hosts run in parallel.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lib  # noqa: E402

TIMEOUT = {"chain": 3600}
DEFAULT_TIMEOUT = 1800


def discover() -> list[tuple[str, list[str]]]:
    v = lib.ROOT / "verify"
    checks = [(f"upstream-{p.stem}", [sys.executable, str(p)]) for p in sorted((v / "upstream").glob("*.py"))]
    checks += [(f"reparse-{p.stem}", [sys.executable, str(p)]) for p in sorted((v / "reparse").glob("*.py"))]
    checks.append(("chain", ["sh", str(v / "chain" / "run.sh")]))
    return checks


def lane(name: str) -> str:
    """Checks in one lane hit the same upstream host and run sequentially."""
    if "fso" in name:
        return "admin.ch"
    if name.startswith("reparse-"):
        return "scraped"
    return name


def run_check(name: str, cmd: list[str], env: dict) -> dict:
    vfile = lib.OUT / "verdicts" / f"{name}.json"
    vfile.unlink(missing_ok=True)
    t0 = time.monotonic()
    try:
        p = subprocess.run(cmd, cwd=lib.ROOT, env=env, capture_output=True, text=True,
                           timeout=TIMEOUT.get(name, DEFAULT_TIMEOUT))
        code, tail = p.returncode, (p.stdout + p.stderr)[-1500:]
    except subprocess.TimeoutExpired:
        code, tail = "timeout", ""
    secs = round(time.monotonic() - t0)
    verdicts = json.loads(vfile.read_text())["verdicts"] if vfile.exists() else []
    if not verdicts:
        verdicts = [{"dataset": "*", "status": "error",
                     "summary": f"check wrote no verdicts (exit {code})",
                     "details": {"log_tail": tail}}]
    for v in verdicts:
        v["check"] = name
    print(f"{name:42s} {secs:5d}s  " + " ".join(
        f"{s}={sum(v['status'] == s for v in verdicts)}" for s in lib.STATUSES
        if any(v["status"] == s for v in verdicts)), flush=True)
    return {"check": name, "seconds": secs, "exit": code, "verdicts": verdicts}


def run_lane(items: list[tuple[str, list[str]]], env: dict) -> list[dict]:
    return [run_check(n, c, env) for n, c in items]


def markdown(results: list[dict]) -> str:
    allv = [v for r in results for v in r["verdicts"]]
    counts = {s: sum(v["status"] == s for v in allv) for s in lib.STATUSES}
    lines = ["# Data verification", "",
             f"{len(results)} checks, {len(allv)} verdicts: "
             + ", ".join(f"{n} {s}" for s, n in counts.items() if n), ""]
    bad = [v for v in allv if v["status"] != "ok"]
    if bad:
        lines += ["| Status | Dataset | Check | Summary |", "| --- | --- | --- | --- |"]
        order = {s: i for i, s in enumerate(("fail", "error", "unreachable", "lag"))}
        for v in sorted(bad, key=lambda v: (order.get(v["status"], 9), v["dataset"])):
            summary = str(v["summary"]).replace("|", "\\|").replace("\n", " ")
            lines.append(f"| {v['status']} | `{v['dataset']}` | {v['check']} | {summary} |")
    else:
        lines.append("Everything matches.")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> None:
    only = lib.only_arg(argv)
    checks = [c for c in discover() if not only or any(o in c[0] for o in only)]
    lanes: dict[str, list] = {}
    for c in checks:
        lanes.setdefault(lane(c[0]), []).append(c)

    env = dict(os.environ, VERIFY_CACHE=os.environ.get("VERIFY_CACHE") or tempfile.mkdtemp(prefix="ds-verify-"))
    lib.OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=len(lanes) or 1) as pool:
        results = [r for rs in pool.map(lambda items: run_lane(items, env), lanes.values()) for r in rs]
    results.sort(key=lambda r: r["check"])

    (lib.OUT / "summary.json").write_text(json.dumps(results, indent=1, default=str))
    md = markdown(results)
    (lib.OUT / "summary.md").write_text(md)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
            f.write(md)
    print("\n" + md)


if __name__ == "__main__":
    main(sys.argv[1:])
