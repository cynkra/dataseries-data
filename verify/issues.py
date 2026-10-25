"""Turn verify/out/summary.json into GitHub issues, labelled `data-verify`.

One issue per (dataset, check) with status `fail` or `error`, deduplicated by
title; a repeat adds a "still failing" comment. An issue closes once the same
check reports the dataset `ok` or `lag` again. A check that did not run, or
could not reach its source, leaves its issues open: no news is not good news.
Same shape as .github/scripts/test_issues.sh. Without gh auth (a local run, or
DRY_RUN=1) it only prints what it would do.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import lib  # noqa: E402

LABEL = "data-verify"
TITLE = "Data check: {dataset} ({check})"
TITLE_RE = re.compile(r"^Data check: (?P<dataset>\S+) \((?P<check>[^)]+)\)$")
MAX_DETAILS = 2500


def gh(*args: str) -> str:
    return subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout


def can_report() -> bool:
    if os.environ.get("DRY_RUN"):
        return False
    try:
        gh("auth", "status")
        return True
    except (OSError, subprocess.CalledProcessError):
        return False


def body(v: dict, run_link: str) -> str:
    details = json.dumps(v.get("details") or {}, indent=1, default=str)
    if len(details) > MAX_DETAILS:
        details = details[:MAX_DETAILS] + "\n… (truncated, see the run's verify-out artifact)"
    why = ("The checker itself broke; often the source changed its layout."
           if v["status"] == "error" else
           "What users receive differs from the source. If the source published a revision "
           "after this morning's refresh, the next run clears it; if it persists, it is real.")
    return "\n".join([
        f"**{v['status']}**: {v['summary']}", "", why, "",
        "```json", details, "```", "",
        *( [f"Run log: {run_link}", ""] if run_link else [] ),
        f"Reproduce: `python verify/run.py --only {v['check']}`", "",
        "_Opened by the weekly verify workflow; closes itself once the check passes again._",
    ])


def main() -> None:
    results = json.loads((lib.OUT / "summary.json").read_text())
    verdicts = [v for r in results for v in r["verdicts"]]
    failing = {(v["dataset"], v["check"]): v for v in verdicts
               if v["status"] in ("fail", "error") and not lib.known_failure(v)}
    for v in verdicts:
        if lib.known_failure(v):
            print(f"issues: known, not filed: {v['dataset']} ({v['check']})")
    passing = {(v["dataset"], v["check"]) for v in verdicts if v["status"] in ("ok", "lag")}
    ran_cleanly = {r["check"] for r in results if not any(v["dataset"] == "*" for v in r["verdicts"])}

    server, repo, run_id = (os.environ.get(k, "") for k in ("GITHUB_SERVER_URL", "GITHUB_REPOSITORY", "GITHUB_RUN_ID"))
    run_link = f"{server or 'https://github.com'}/{repo}/actions/runs/{run_id}" if repo and run_id else ""

    if not can_report():
        for (dataset, check), v in sorted(failing.items()):
            print(f"would open/refresh: {TITLE.format(dataset=dataset, check=check)}: {v['summary']}")
        print(f"issues: {len(failing)} failing; no gh auth (or DRY_RUN), nothing filed.")
        return

    subprocess.run(["gh", "label", "create", LABEL, "--color", "D93F0B", "--description",
                    "A weekly verify/ check found data that differs from its source"],
                   capture_output=True)
    open_issues = {i["title"]: i["number"] for i in json.loads(
        gh("issue", "list", "--label", LABEL, "--state", "open", "--limit", "500", "--json", "number,title"))}

    for (dataset, check), v in sorted(failing.items()):
        title = TITLE.format(dataset=dataset, check=check)
        text = body(v, run_link)
        try:
            if title in open_issues:
                gh("issue", "comment", str(open_issues[title]), "--body", "Still failing.\n\n" + text)
                print(f"issues: #{open_issues[title]} still failing: {title}")
            else:
                gh("issue", "create", "--title", title, "--label", LABEL, "--body", text)
                print(f"issues: opened {title}")
        except subprocess.CalledProcessError as e:
            print(f"issues: could not file {title}: {e.stderr}", file=sys.stderr)

    for title, number in open_issues.items():
        m = TITLE_RE.match(title)
        if not m:
            continue
        key = (m["dataset"], m["check"])
        resolved = key in passing or (m["dataset"] == "*" and m["check"] in ran_cleanly)
        if resolved and key not in failing:
            try:
                gh("issue", "close", str(number), "--comment",
                   f"Resolved: `{m['check']}` reports `{m['dataset']}` as matching again. Closing automatically.")
                print(f"issues: closed #{number} {title}")
            except subprocess.CalledProcessError as e:
                print(f"issues: could not close #{number}: {e.stderr}", file=sys.stderr)

    print(f"issues: done ({len(failing)} failing).")


if __name__ == "__main__":
    main()
