#!/usr/bin/env bash
#
# health_issues.sh — anti-rot alarm for the dataseries data catalog.
#
# Reads data/status.json (written by R/health.R) and, for every dataset whose
# `status` is "red" (stale), opens ONE deduped GitHub issue per dataset, labelled
# `data-health`, titled "Data health: <id> is stale". If such an issue is already
# open it is left alone (a short "still stale" comment is added). Any open
# `data-health` issue whose dataset is no longer red (now green, or gone from
# the catalog) is closed automatically. When there are zero reds, no issue is
# created — only stragglers get closed.
#
# Dependencies (both present on GitHub-hosted runners): jq, gh.
# Auth: expects GH_TOKEN in the environment (set in the workflow from
# secrets.GITHUB_TOKEN); the workflow job must grant `permissions: issues: write`.
#
# This script is intentionally self-contained and idempotent: running it twice in
# a row produces no extra issues or churn beyond the periodic comment.

set -euo pipefail

STATUS_FILE="${STATUS_FILE:-data/status.json}"
LABEL="data-health"

if [[ ! -f "$STATUS_FILE" ]]; then
  echo "health_issues: $STATUS_FILE not found — nothing to do." >&2
  exit 0
fi

# Build a stable web link to the health board for issue bodies. Falls back to a
# bare path if the GitHub env vars aren't set (e.g. local runs).
server="${GITHUB_SERVER_URL:-https://github.com}"
repo="${GITHUB_REPOSITORY:-}"
branch="${GITHUB_REF_NAME:-main}"
if [[ -n "$repo" ]]; then
  status_link="${server}/${repo}/blob/${branch}/STATUS.md"
else
  status_link="STATUS.md"
fi

# Ensure the dedupe label exists. `gh label create` fails if it already exists,
# so we swallow that case — any other failure is non-fatal here too (the issue
# create/list calls don't strictly need the label to pre-exist, but having it
# makes the board filterable).
if ! gh label create "$LABEL" \
      --description "Automated data-staleness alert from the daily ETL" \
      --color "B60205" 2>/dev/null; then
  echo "health_issues: label '$LABEL' already exists (or create skipped)."
fi

checked="$(jq -r '.checked // "unknown"' "$STATUS_FILE")"

# --- 1. Red datasets: open or refresh one issue each ------------------------

# Tab-separated rows for each red dataset: id, title, frequency, end, age_days.
red_rows="$(jq -r '
  .datasets
  | map(select(.status == "red"))
  | .[]
  | [.id, .title, (.frequency // "?"), (.end // "?"), (.age_days | tostring)]
  | @tsv
' "$STATUS_FILE")"

# Track which ids are currently red so we can close stragglers afterwards.
declare -A RED_IDS=()

if [[ -n "$red_rows" ]]; then
  while IFS=$'\t' read -r id title frequency end age_days; do
    [[ -z "$id" ]] && continue
    RED_IDS["$id"]=1

    issue_title="Data health: ${id} is stale"

    # Does an open data-health issue with exactly this title already exist?
    existing="$(gh issue list \
        --label "$LABEL" --state open \
        --json number,title \
        --jq "map(select(.title == \"${issue_title}\")) | .[0].number // empty")"

    if [[ -n "$existing" ]]; then
      echo "health_issues: #${existing} already tracks '${id}' — adding still-stale note."
      gh issue comment "$existing" \
        --body "Still stale as of ${checked}: \`${end}\` is the last observation (${age_days} days old)." \
        || echo "health_issues: comment on #${existing} failed (non-fatal)." >&2
    else
      echo "health_issues: opening new issue for stale dataset '${id}'."
      body="$(printf '%s\n' \
        "**\`${id}\`** has gone stale on the data-health board." \
        "" \
        "| field | value |" \
        "| --- | --- |" \
        "| id | \`${id}\` |" \
        "| title | ${title} |" \
        "| frequency | ${frequency} |" \
        "| last observation | ${end} |" \
        "| age (days) | ${age_days} |" \
        "| checked | ${checked} |" \
        "" \
        "Full health board: [STATUS.md](${status_link})" \
        "" \
        "_This issue is opened automatically by the daily ETL and closes itself once the dataset is fresh again._")"
      gh issue create \
        --title "$issue_title" \
        --label "$LABEL" \
        --body "$body" \
        || echo "health_issues: create for '${id}' failed (non-fatal)." >&2
    fi
  done <<< "$red_rows"
else
  echo "health_issues: no red datasets."
fi

# --- 2. Close stragglers: open data-health issues no longer red -------------

# Each open data-health issue's number + title, one per line (tab-separated).
open_issues="$(gh issue list \
    --label "$LABEL" --state open \
    --json number,title \
    --jq '.[] | [(.number | tostring), .title] | @tsv')"

if [[ -n "$open_issues" ]]; then
  while IFS=$'\t' read -r number ititle; do
    [[ -z "$number" ]] && continue
    # Recover the dataset id from the stable title pattern.
    id="${ititle#Data health: }"
    id="${id% is stale}"
    if [[ -z "${RED_IDS[$id]:-}" ]]; then
      echo "health_issues: '${id}' is fresh again — closing #${number}."
      gh issue close "$number" \
        --comment "Resolved: \`${id}\` is fresh again as of ${checked}. Closing automatically." \
        || echo "health_issues: close of #${number} failed (non-fatal)." >&2
    fi
  done <<< "$open_issues"
fi

echo "health_issues: done."
