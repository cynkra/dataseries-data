#!/usr/bin/env bash
#
# skip_issues.sh — immediate alarm for a failed source fetch (a "skip").
#
# Reads data/run.json (written by R/pipeline.R) and, for every dataset in this run's
# `skipped` list, opens ONE deduped GitHub issue labelled `etl-skip`, titled
# "Fetch skip: <id> failed". If such an issue is already open it is left alone (a
# short "still failing" comment is added). Any open `etl-skip` issue whose dataset is
# NOT in this run's skip list — i.e. it fetched cleanly again — is closed
# automatically. When there are zero skips, no issue is created; stragglers close.
#
# A skip is the LEADING signal: a parser breaks the day a source changes format,
# weeks before the data would age into staleness. The auto-close keeps it quiet: a
# real format break stays open until fixed; a recovered source closes itself.
#
# MODES:
#   default        — open/refresh an issue per current skip AND close recovered ones.
#                    Run by the afternoon retry (etl-retry.yml), off the post-retry
#                    run.json, so only a source that STILL fails after a ~6h-later
#                    second attempt opens an issue (a transient blip never does).
#   CLOSE_ONLY=1   — close recovered issues only; never OPEN one. Run by the MORNING
#                    etl (etl.yml): the morning must not alarm on a fresh skip (it may
#                    just be a passing outage), but it must still close the issue of a
#                    source that recovered on a day the afternoon retry doesn't run.
#
# Dependencies (both present on GitHub-hosted runners): jq, gh.
# Auth: expects GH_TOKEN in the environment (set in the workflow from
# secrets.GITHUB_TOKEN); the workflow job must grant `permissions: issues: write`.
#
# Intentionally self-contained and idempotent: running it twice produces no extra
# issues or churn beyond the periodic comment. Mirrors health_issues.sh.

set -euo pipefail

RUN_FILE="${RUN_FILE:-data/run.json}"
LABEL="etl-skip"

if [[ ! -f "$RUN_FILE" ]]; then
  echo "skip_issues: $RUN_FILE not found — nothing to do." >&2
  exit 0
fi

# Stable run link for issue bodies; bare fallback for local runs.
server="${GITHUB_SERVER_URL:-https://github.com}"
repo="${GITHUB_REPOSITORY:-}"
run_id="${GITHUB_RUN_ID:-}"
if [[ -n "$repo" && -n "$run_id" ]]; then
  run_link="${server}/${repo}/actions/runs/${run_id}"
else
  run_link="(local run)"
fi

# Ensure the dedupe label exists (swallow "already exists"; non-fatal otherwise).
if ! gh label create "$LABEL" \
      --description "Automated fetch-skip alert from the daily ETL" \
      --color "D93F0B" 2>/dev/null; then
  echo "skip_issues: label '$LABEL' already exists (or create skipped)."
fi

checked="$(jq -r '.ts // "unknown"' "$RUN_FILE")"

# --- 1. Skipped datasets: open or refresh one issue each --------------------

# Tab-separated rows for each skipped dataset: id, error.
skip_rows="$(jq -r '
  (.skipped // [])
  | .[]
  | [.id, (.error // "")]
  | @tsv
' "$RUN_FILE")"

declare -A SKIP_IDS=()

if [[ -n "$skip_rows" ]]; then
  while IFS=$'\t' read -r id error; do
    [[ -z "$id" ]] && continue
    SKIP_IDS["$id"]=1

    # Close-only mode (morning run): record the still-failing id so the straggler
    # sweep below keeps its issue open, but never OPEN a new one here — opening is the
    # afternoon retry's job, after a transient outage has had time to clear.
    [[ -n "${CLOSE_ONLY:-}" ]] && continue

    issue_title="Fetch skip: ${id} failed"

    existing="$(gh issue list \
        --label "$LABEL" --state open \
        --json number,title \
        --jq "map(select(.title == \"${issue_title}\")) | .[0].number // empty")"

    if [[ -n "$existing" ]]; then
      echo "skip_issues: #${existing} already tracks '${id}' — adding still-failing note."
      gh issue comment "$existing" \
        --body "Still failing as of ${checked}: \`${error}\`" \
        || echo "skip_issues: comment on #${existing} failed (non-fatal)." >&2
    else
      echo "skip_issues: opening new issue for skipped dataset '${id}'."
      body="$(printf '%s\n' \
        "**\`${id}\`** failed to fetch in the daily ETL — it was **skipped** (the run kept the previous data)." \
        "" \
        "| field | value |" \
        "| --- | --- |" \
        "| id | \`${id}\` |" \
        "| error | \`${error}\` |" \
        "| run | ${checked} |" \
        "" \
        "**Act ASAP** — a skip usually means the source changed format (new column/header/URL) and the parser needs updating, well before the data would show as stale." \
        "" \
        "Run log: ${run_link}" \
        "" \
        "_Opened automatically by the daily ETL; closes itself once \`${id}\` fetches cleanly again._")"
      gh issue create \
        --title "$issue_title" \
        --label "$LABEL" \
        --body "$body" \
        || echo "skip_issues: create for '${id}' failed (non-fatal)." >&2
    fi
  done <<< "$skip_rows"
else
  echo "skip_issues: no skips this run."
fi

# --- 2. Close stragglers: open etl-skip issues no longer skipping ------------

open_issues="$(gh issue list \
    --label "$LABEL" --state open \
    --json number,title \
    --jq '.[] | [(.number | tostring), .title] | @tsv')"

if [[ -n "$open_issues" ]]; then
  while IFS=$'\t' read -r number ititle; do
    [[ -z "$number" ]] && continue
    # Recover the dataset id from the stable title pattern.
    id="${ititle#Fetch skip: }"
    id="${id% failed}"
    if [[ -z "${SKIP_IDS[$id]:-}" ]]; then
      echo "skip_issues: '${id}' fetched cleanly again — closing #${number}."
      gh issue close "$number" \
        --comment "Resolved: \`${id}\` fetched cleanly again as of ${checked}. Closing automatically." \
        || echo "skip_issues: close of #${number} failed (non-fatal)." >&2
    fi
  done <<< "$open_issues"
fi

echo "skip_issues: done."
