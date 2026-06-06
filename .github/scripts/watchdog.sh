#!/usr/bin/env bash
#
# watchdog.sh — independent dead-man's-switch for the daily ETL.
#
# Runs on its OWN schedule ~2h after the ETL cron (see .github/workflows/watchdog.yml).
# It does NOT trust the ETL run's self-reported status: the inline failure alarm in
# etl.yml only fires on success()/failure(), and a job killed by `timeout-minutes`
# concludes `cancelled` — a third state that slips through (exactly what hid the
# 2026-06-05 miss). The watchdog instead checks the only thing that matters: did the
# pipeline commit a fresh row today?
#
# Ground truth = the latest date in data/uptime.csv. R/uptime.R upserts one row per
# UTC day on every completed run, so `latest == today` means "the ETL ran AND
# committed today". If not, open (or refresh) ONE deduped `watchdog` issue; once a
# fresh row lands again, close it automatically. Mirrors skip_issues.sh.
#
# Dependencies (present on GitHub-hosted runners): gh, jq, coreutils date.
# Auth: GH_TOKEN in env; workflow grants `issues: write` + `actions: read`. GH_REPO
# is set in the workflow so gh resolves the repo regardless of checkout state.
#
# Self-contained and idempotent: running it twice produces no extra issues or churn
# beyond the periodic "still stale" comment.

set -euo pipefail

CSV="${UPTIME_CSV:-data/uptime.csv}"
LABEL="watchdog"
TITLE="🔴 Daily ETL watchdog: data is stale"

today="$(date -u +%F)"

# Latest committed day = max valid date in the uptime history (the file is written
# date-sorted, but take the max defensively). Empty if the file is missing/empty.
latest=""
if [[ -f "$CSV" ]]; then
  latest="$(tail -n +2 "$CSV" | cut -d, -f1 | tr -d '"' \
            | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort | tail -1 || true)"
fi

echo "watchdog: today=${today} latest_committed=${latest:-<none>}"

# Best-effort context: the most recent scheduled etl run's conclusion + link.
run_line=""
if run_json="$(gh run list --workflow etl.yml --limit 1 \
      --json conclusion,status,createdAt,url 2>/dev/null)"; then
  concl="$(jq -r '.[0].conclusion // .[0].status // "unknown"' <<<"$run_json")"
  rurl="$(jq -r '.[0].url // ""' <<<"$run_json")"
  rwhen="$(jq -r '.[0].createdAt // ""' <<<"$run_json")"
  [[ -n "$rurl" ]] && run_line="Most recent \`etl\` run: **${concl}** (${rwhen}) — ${rurl}"
fi

# Ensure the dedupe label exists (non-fatal if it already does).
gh label create "$LABEL" \
    --description "Independent watchdog: ETL did not refresh data" \
    --color "B60205" 2>/dev/null \
  || echo "watchdog: label '$LABEL' already exists (or create skipped)."

existing="$(gh issue list --label "$LABEL" --state open \
    --json number,title \
    --jq "map(select(.title == \"${TITLE}\")) | .[0].number // empty")"

if [[ -n "$latest" && "$latest" == "$today" ]]; then
  # Fresh: the pipeline committed today. Close any open watchdog alarm.
  if [[ -n "$existing" ]]; then
    echo "watchdog: data fresh again (${today}) — closing #${existing}."
    gh issue close "$existing" \
      --comment "Resolved: \`data/uptime.csv\` advanced to ${today}; the ETL committed a fresh row. Closing automatically." \
      || echo "watchdog: close of #${existing} failed (non-fatal)." >&2
  else
    echo "watchdog: data fresh (${today}) — nothing to do."
  fi
  exit 0
fi

# Stale: no row for today ~2h after the scheduled run. Alarm.
body="$(printf '%s\n' \
  "The daily ETL has **not committed fresh data today** (\`${today}\`)." \
  "" \
  "| check | value |" \
  "| --- | --- |" \
  "| today (UTC) | \`${today}\` |" \
  "| latest committed day | \`${latest:-<none>}\` |" \
  "" \
  "${run_line}" \
  "" \
  "The watchdog runs ~2h after the ETL cron and checks the one thing that matters:" \
  "did \`data/uptime.csv\` gain a row for today. It hasn't — so the run is missing," \
  "**cancelled** (e.g. it hit \`timeout-minutes\`), or failed before the commit step." \
  "The inline ETL alarm only fires on success/failure, so a cancellation can slip" \
  "through; this watchdog is the independent backstop." \
  "" \
  "_Opened automatically; closes itself once a fresh \`data/uptime.csv\` row lands._")"

if [[ -n "$existing" ]]; then
  echo "watchdog: still stale — refreshing #${existing}."
  gh issue comment "$existing" \
    --body "Still stale as of ${today} (latest committed: \`${latest:-<none>}\`). ${run_line}" \
    || echo "watchdog: comment on #${existing} failed (non-fatal)." >&2
else
  echo "watchdog: opening stale-data issue."
  gh issue create --title "$TITLE" --label "$LABEL" --body "$body" \
    || echo "watchdog: create failed (non-fatal)." >&2
fi

echo "watchdog: done."
