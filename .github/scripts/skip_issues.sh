#!/usr/bin/env bash
#
# skip_issues.sh — file issues for fetch failures that ACTUALLY need a human; everything
# else lives on the dashboard, not in the issue tracker.
#
# Reads data/skips.json (written by R/uptime.R, which runs immediately before this in both
# etl.yml and etl-retry.yml). Each skip carries a `route`:
#
#   route="alarm"   -> an ACTIONABLE break: a 4xx, or a parse / validation error. The source
#                      changed in a way OUR parser must adapt to. Opens ONE deduped
#                      per-source issue labelled `etl-skip`, titled "Fetch skip: <id> failed"
#                      — immediately, because it won't self-heal.
#   route="outage"  -> a network / provider error (HTTP 5xx, a timeout, a connection failure
#                      — a provider outage or the admin.ch runner-IP block). There is NOTHING
#                      to do on our side, so it does NOT open an issue. It's visible on the
#                      dashboard (the red "upstream" badge -> UPTIME.md). It opens an issue
#                      ONLY once `escalated` (it has failed >= alert_after_days consecutive
#                      days) — then it joins ONE grouped issue labelled `etl-outage`.
#
# So a normal provider blip files nothing; a sustained outage files one grouped issue; a
# real format break files a per-source issue at once. Recovery is automatic: a per-source
# issue closes when its id is no longer an alarm; the grouped issue closes when nothing is
# escalated. See dev/etl-reliability-log.md (2026-06-18).
#
# MODES:
#   default        — open/refresh alarms + the grouped issue AND close recovered ones.
#   CLOSE_ONLY=1   — close genuinely-recovered issues only; never OPEN, never reclassify.
#                    Run by the morning etl.yml and the lunch retry (a fresh skip may clear
#                    on a later fresh-IP attempt); only the day's LAST pass opens issues.
#
# Falls back to data/run.json (every skip treated as `alarm`) if skips.json is absent.
# Dependencies: jq, gh. Auth: GH_TOKEN in env; the job needs `permissions: issues: write`.

set -euo pipefail

SKIPS_FILE="${SKIPS_FILE:-data/skips.json}"
RUN_FILE="${RUN_FILE:-data/run.json}"
LABEL_SKIP="etl-skip"
LABEL_OUTAGE="etl-outage"
OUTAGE_TITLE="ETL: sustained upstream outage"

server="${GITHUB_SERVER_URL:-https://github.com}"
repo="${GITHUB_REPOSITORY:-}"
run_id="${GITHUB_RUN_ID:-}"
if [[ -n "$repo" && -n "$run_id" ]]; then
  run_link="${server}/${repo}/actions/runs/${run_id}"
else
  run_link="(local run)"
fi

# --- load this run's skips: id \t route \t error \t escalated \t consec ------------------
alert_after_days="3"
if [[ -f "$SKIPS_FILE" ]]; then
  checked="$(jq -r '.ts // "unknown"' "$SKIPS_FILE")"
  alert_after_days="$(jq -r '.alert_after_days // 3' "$SKIPS_FILE")"
  rows="$(jq -r '(.skips // []) | .[]
    | [.id, (.route // "alarm"), (.error // ""), ((.escalated // false)|tostring), ((.consecutive_days // 1)|tostring)]
    | @tsv' "$SKIPS_FILE")"
elif [[ -f "$RUN_FILE" ]]; then
  echo "skip_issues: $SKIPS_FILE absent — falling back to $RUN_FILE (all skips -> alarm)." >&2
  checked="$(jq -r '.ts // "unknown"' "$RUN_FILE")"
  rows="$(jq -r '(.skipped // []) | .[] | [.id, "alarm", (.error // ""), "false", "1"] | @tsv' "$RUN_FILE")"
else
  echo "skip_issues: neither $SKIPS_FILE nor $RUN_FILE found — nothing to do." >&2
  exit 0
fi

gh label create "$LABEL_SKIP"   --description "Per-source fetch-skip alarm (actionable: a 4xx / parse error)" --color "D93F0B" 2>/dev/null \
  || echo "skip_issues: label '$LABEL_SKIP' already exists (or create skipped)."
gh label create "$LABEL_OUTAGE" --description "Sustained upstream outage (network skips past the alert window)" --color "FBCA04" 2>/dev/null \
  || echo "skip_issues: label '$LABEL_OUTAGE' already exists (or create skipped)."

declare -A ALARM_ERR=() ALARM_CONSEC=()   # actionable -> per-source issue now
declare -A OUTAGE_ESC_ERR=()              # network, escalated -> grouped issue
declare -A OUTAGE_ESC_CONSEC=()
declare -A ALL_SKIP=()                    # every id skipped this run (for the close pass)

if [[ -n "$rows" ]]; then
  while IFS=$'\t' read -r id route error escalated consec; do
    [[ -z "$id" ]] && continue
    ALL_SKIP["$id"]=1
    if [[ "$route" == "alarm" ]]; then
      ALARM_ERR["$id"]="$error"; ALARM_CONSEC["$id"]="$consec"
    elif [[ "$escalated" == "true" ]]; then
      OUTAGE_ESC_ERR["$id"]="$error"; OUTAGE_ESC_CONSEC["$id"]="$consec"
    fi
    # route=outage && !escalated -> dashboard-only; nothing tracked here.
  done <<< "$rows"
fi

# --- 1. per-source alarms (route=alarm): open or refresh one issue each ------------------
if [[ ${#ALARM_ERR[@]} -gt 0 && -z "${CLOSE_ONLY:-}" ]]; then
  for id in "${!ALARM_ERR[@]}"; do
    error="${ALARM_ERR[$id]}"
    issue_title="Fetch skip: ${id} failed"
    existing="$(gh issue list --label "$LABEL_SKIP" --state open --json number,title \
        --jq "map(select(.title == \"${issue_title}\")) | .[0].number // empty")"
    if [[ -n "$existing" ]]; then
      echo "skip_issues: #${existing} already tracks '${id}' — adding still-failing note."
      gh issue comment "$existing" --body "Still failing as of ${checked}: \`${error}\`" \
        || echo "skip_issues: comment on #${existing} failed (non-fatal)." >&2
    else
      echo "skip_issues: opening actionable alarm for '${id}'."
      body="**\`${id}\`** failed to fetch in the daily ETL — it was **skipped** (the run kept the previous data)."$'\n\n'
      body+="| field | value |"$'\n'"| --- | --- |"$'\n'
      body+="| id | \`${id}\` |"$'\n'"| error | \`${error}\` |"$'\n'"| run | ${checked} |"$'\n\n'
      body+="**Act now.** This is an *actionable* break — a 4xx (the URL moved / is forbidden) or a parse/validation error — meaning the source changed in a way our parser must adapt to. (Provider-side network outages, HTTP 5xx / timeouts, are NOT filed here; they show on the dashboard and only group into an \`${LABEL_OUTAGE}\` issue after ${alert_after_days} days.)"
      body+=$'\n\n'"Run log: ${run_link}"$'\n\n'"_Opened automatically by the daily ETL; closes itself once \`${id}\` fetches cleanly again._"
      gh issue create --title "$issue_title" --label "$LABEL_SKIP" --body "$body" \
        || echo "skip_issues: create for '${id}' failed (non-fatal)." >&2
    fi
  done
fi

# --- 2. grouped issue for escalated network outages (route=outage && escalated) ---------
umbrella_num="$(gh issue list --label "$LABEL_OUTAGE" --state open --json number,title \
    --jq "map(select(.title == \"${OUTAGE_TITLE}\")) | .[0].number // empty")"

if [[ ${#OUTAGE_ESC_ERR[@]} -gt 0 && -z "${CLOSE_ONLY:-}" ]]; then
  members=""
  for id in "${!OUTAGE_ESC_ERR[@]}"; do
    members+="| \`${id}\` | ${OUTAGE_ESC_CONSEC[$id]} | \`${OUTAGE_ESC_ERR[$id]}\` |"$'\n'
  done
  body="**${#OUTAGE_ESC_ERR[@]} source(s) have failed to fetch for ≥ ${alert_after_days} consecutive days.** Up to now this was a dashboard-only provider outage (nothing to do); it has now persisted long enough to warrant a look."$'\n\n'
  body+="| id | days failing | error |"$'\n'"| --- | ---: | --- |"$'\n'
  body+="${members}"$'\n'
  body+="**What to check:** is the provider still down (then keep waiting — the data is preserved), or has the outage turned into something we must act on — a moved endpoint, a changed payload, or the admin.ch runner-IP block (see \`dev/etl-reliability-log.md\`)? A short outage never reaches this issue; reaching it means the source has been unreachable for days."$'\n\n'
  body+="Last checked: ${checked}"$'\n'"Run log: ${run_link}"

  if [[ -n "$umbrella_num" ]]; then
    echo "skip_issues: refreshing grouped outage #${umbrella_num} (${#OUTAGE_ESC_ERR[@]} member(s))."
    gh issue edit "$umbrella_num" --body "$body" \
      || echo "skip_issues: edit of #${umbrella_num} failed (non-fatal)." >&2
  else
    echo "skip_issues: opening grouped outage issue (${#OUTAGE_ESC_ERR[@]} member(s))."
    created_url="$(gh issue create --title "$OUTAGE_TITLE" --label "$LABEL_OUTAGE" --body "$body" 2>/dev/null || true)"
    umbrella_num="$(grep -oE '/issues/[0-9]+' <<< "$created_url" | grep -oE '[0-9]+$' | tail -1)"
    if [[ -z "$umbrella_num" ]]; then
      echo "skip_issues: create returned no number — falling back to list." >&2
      umbrella_num="$(gh issue list --label "$LABEL_OUTAGE" --state open --json number,title \
          --jq "map(select(.title == \"${OUTAGE_TITLE}\")) | .[0].number // empty")"
    fi
  fi
fi

# --- 3. close recovered / reclassified --------------------------------------------------
# 3a. per-source `etl-skip` issues whose id is no longer an actionable alarm.
open_skip="$(gh issue list --label "$LABEL_SKIP" --state open --json number,title \
    --jq '.[] | [(.number | tostring), .title] | @tsv')"
if [[ -n "$open_skip" ]]; then
  while IFS=$'\t' read -r number ititle; do
    [[ -z "$number" ]] && continue
    id="${ititle#Fetch skip: }"; id="${id% failed}"
    [[ -n "${ALARM_ERR[$id]:-}" ]] && continue            # still an actionable alarm -> keep open
    if [[ -n "${ALL_SKIP[$id]:-}" ]]; then
      # Still failing, but a network/provider skip now -> dashboard-only; don't keep a
      # per-source issue. Skip this reclassification in CLOSE_ONLY (leave it to the afternoon).
      [[ -n "${CLOSE_ONLY:-}" ]] && continue
      echo "skip_issues: '${id}' is a provider-side fetch failure — closing per-source #${number} (now dashboard-only)."
      dash_link="${server}/${repo}/blob/main/UPTIME.md#current-run-through"
      gh issue close "$number" \
        --comment "Reclassified: \`${id}\` is a network/provider fetch failure (nothing for us to fix), now shown on the dashboard (the **upstream** badge → [UPTIME.md](${dash_link})) instead of a per-source issue. It will file a grouped \`${LABEL_OUTAGE}\` issue only if it persists ≥ ${alert_after_days} days. Closing automatically." \
        || echo "skip_issues: close of #${number} failed (non-fatal)." >&2
    else
      echo "skip_issues: '${id}' fetched cleanly again — closing #${number}."
      gh issue close "$number" \
        --comment "Resolved: \`${id}\` fetched cleanly again as of ${checked}. Closing automatically." \
        || echo "skip_issues: close of #${number} failed (non-fatal)." >&2
    fi
  done <<< "$open_skip"
fi

# 3b. grouped outage: close when nothing is escalated this run.
if [[ ${#OUTAGE_ESC_ERR[@]} -eq 0 && -n "$umbrella_num" ]]; then
  echo "skip_issues: nothing escalated — closing grouped outage #${umbrella_num}."
  gh issue close "$umbrella_num" \
    --comment "Resolved: no source is past the ${alert_after_days}-day outage window as of ${checked}. Closing automatically." \
    || echo "skip_issues: close of #${umbrella_num} failed (non-fatal)." >&2
fi

echo "skip_issues: done."
