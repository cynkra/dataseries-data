#!/usr/bin/env bash
#
# skip_issues.sh — alarms for failed source fetches ("skips"), ROUTED by cause.
#
# Reads data/skips.json (written by R/uptime.R, which runs immediately before this in
# both etl.yml and etl-retry.yml) and routes each skipped dataset by its `route` field:
#
#   route="alarm"    -> a HARD skip a human must look at: a 4xx (403 block / 404 moved),
#                       a transport failure we couldn't even connect through (DNS / refused
#                       / reset / connect timeout -- the admin.ch runner-IP block), a parse
#                       error, or a transient error that has PERSISTED past the escalation
#                       window. Opens ONE deduped per-source issue labelled `etl-skip`,
#                       titled "Fetch skip: <id> failed".
#   route="umbrella" -> a TRANSIENT upstream outage: the host was reachable but couldn't
#                       serve usable data right now (HTTP 429/5xx, or a read timeout after
#                       connect -- e.g. the 2026-06-18 BFS database outage: 12 FSO sources
#                       all 503/timeout). These are GROUPED into ONE deduped issue labelled
#                       `etl-outage` whose body is refreshed each run to the current member
#                       set. Not a per-source emergency; it auto-closes when all recover.
#
# Why the split: a broad provider outage used to open a dozen "act ASAP -- source changed
# format" issues AND break the run-through uptime streak. Neither was true: the data was
# preserved (previous values kept) and the fix was the provider's. Grouping the transient
# ones into a single auto-closing umbrella keeps the signal (a real format break / block
# still opens a loud per-source issue, and a transient that drags on >= 2 days escalates
# into one) without the noise. See dev/etl-reliability-log.md (2026-06-18).
#
# Recovery is automatic: any open `etl-skip` whose id is no longer an alarm closes -- it
# recovered, OR it was reclassified to the umbrella (closed with a pointer to it); the
# umbrella closes once no transient skips remain.
#
# MODES:
#   default        — open/refresh alarms + umbrella AND close recovered ones.
#   CLOSE_ONLY=1   — close recovered ones only; never OPEN. Run by the morning etl.yml and
#                    the lunch retry: a fresh skip may clear on a later fresh-IP / post-
#                    outage attempt, so only the day's LAST pass opens issues.
#
# Falls back to data/run.json (every skip treated as `alarm`) if skips.json is absent, so
# an older R layer still alarms safely. Dependencies: jq, gh. Auth: GH_TOKEN in env; the
# job must grant `permissions: issues: write`. Idempotent: re-running adds no churn beyond
# the periodic still-failing comment / umbrella body refresh.

set -euo pipefail

SKIPS_FILE="${SKIPS_FILE:-data/skips.json}"
RUN_FILE="${RUN_FILE:-data/run.json}"
LABEL_SKIP="etl-skip"
LABEL_OUTAGE="etl-outage"
OUTAGE_TITLE="ETL: transient upstream outage"

# Stable run link for issue bodies; bare fallback for local runs.
server="${GITHUB_SERVER_URL:-https://github.com}"
repo="${GITHUB_REPOSITORY:-}"
run_id="${GITHUB_RUN_ID:-}"
if [[ -n "$repo" && -n "$run_id" ]]; then
  run_link="${server}/${repo}/actions/runs/${run_id}"
else
  run_link="(local run)"
fi

# --- load this run's skip rows: id \t route \t error \t escalated \t consec --------------
if [[ -f "$SKIPS_FILE" ]]; then
  checked="$(jq -r '.ts // "unknown"' "$SKIPS_FILE")"
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

# Ensure the dedupe labels exist (swallow "already exists"; non-fatal otherwise).
gh label create "$LABEL_SKIP"   --description "Per-source fetch-skip alarm (hard failure)"      --color "D93F0B" 2>/dev/null \
  || echo "skip_issues: label '$LABEL_SKIP' already exists (or create skipped)."
gh label create "$LABEL_OUTAGE" --description "Grouped transient upstream outage (HTTP 5xx / timeout)" --color "FBCA04" 2>/dev/null \
  || echo "skip_issues: label '$LABEL_OUTAGE' already exists (or create skipped)."

declare -A ALARM_ERR=() ALARM_ESC=() ALARM_CONSEC=()
declare -A UMBRELLA_ERR=()

if [[ -n "$rows" ]]; then
  while IFS=$'\t' read -r id route error escalated consec; do
    [[ -z "$id" ]] && continue
    if [[ "$route" == "umbrella" ]]; then
      UMBRELLA_ERR["$id"]="$error"
    else
      ALARM_ERR["$id"]="$error"; ALARM_ESC["$id"]="$escalated"; ALARM_CONSEC["$id"]="$consec"
    fi
  done <<< "$rows"
fi

# --- 1. per-source alarms (route=alarm): open or refresh one issue each -------------------
if [[ ${#ALARM_ERR[@]} -gt 0 && -z "${CLOSE_ONLY:-}" ]]; then
  for id in "${!ALARM_ERR[@]}"; do
    error="${ALARM_ERR[$id]}"; escalated="${ALARM_ESC[$id]:-false}"; consec="${ALARM_CONSEC[$id]:-1}"
    issue_title="Fetch skip: ${id} failed"

    esc_note=""
    if [[ "$escalated" == "true" ]]; then
      esc_note="**Escalated** — \`${id}\` has failed ${consec} consecutive days. A transient upstream error (HTTP 5xx / timeout) that persists this long is no longer a passing outage: treat it as a real block or format change and investigate now."
    fi

    existing="$(gh issue list --label "$LABEL_SKIP" --state open --json number,title \
        --jq "map(select(.title == \"${issue_title}\")) | .[0].number // empty")"

    if [[ -n "$existing" ]]; then
      echo "skip_issues: #${existing} already tracks '${id}' — adding still-failing note."
      gh issue comment "$existing" --body "Still failing as of ${checked}: \`${error}\`.${esc_note:+ ${esc_note}}" \
        || echo "skip_issues: comment on #${existing} failed (non-fatal)." >&2
    else
      echo "skip_issues: opening alarm issue for '${id}'."
      body="**\`${id}\`** failed to fetch in the daily ETL — it was **skipped** (the run kept the previous data)."$'\n\n'
      body+="| field | value |"$'\n'"| --- | --- |"$'\n'
      body+="| id | \`${id}\` |"$'\n'"| error | \`${error}\` |"$'\n'"| run | ${checked} |"$'\n\n'
      body+="**Act now.** A hard skip means a source failed for a reason that won't self-heal: a changed format / column / URL, an auth or IP block (e.g. 403, or a connection we couldn't open — see \`dev/etl-reliability-log.md\`), or a parse error. (Transient upstream outages — HTTP 5xx or a read timeout from a reachable host — are grouped separately under the \`${LABEL_OUTAGE}\` issue and are not this.)"
      [[ -n "$esc_note" ]] && body+=$'\n\n'"$esc_note"
      body+=$'\n\n'"Run log: ${run_link}"$'\n\n'"_Opened automatically by the daily ETL; closes itself once \`${id}\` fetches cleanly again._"
      gh issue create --title "$issue_title" --label "$LABEL_SKIP" --body "$body" \
        || echo "skip_issues: create for '${id}' failed (non-fatal)." >&2
    fi
  done
fi

# --- 2. umbrella (route=umbrella): one grouped, body-refreshed issue ----------------------
# Find any existing open umbrella (also used by the close pass and the regroup pointer).
umbrella_num="$(gh issue list --label "$LABEL_OUTAGE" --state open --json number,title \
    --jq "map(select(.title == \"${OUTAGE_TITLE}\")) | .[0].number // empty")"

if [[ ${#UMBRELLA_ERR[@]} -gt 0 && -z "${CLOSE_ONLY:-}" ]]; then
  members=""
  for id in "${!UMBRELLA_ERR[@]}"; do
    members+="| \`${id}\` | \`${UMBRELLA_ERR[$id]}\` |"$'\n'
  done
  body="**${#UMBRELLA_ERR[@]} source(s) hit a transient upstream error** in the daily ETL and were **skipped** — the run kept the previous data, so the API and dashboard still serve last-good values."$'\n\n'
  body+="| id | error |"$'\n'"| --- | --- |"$'\n'
  body+="${members}"$'\n'
  body+="**What this means:** the host was reachable but could not serve usable data right now — an HTTP 5xx (e.g. 503 Service Unavailable, 502/504 gateway, 429 throttle) or a read timeout from an overloaded-but-alive server. This is an **upstream outage — not a problem with our pipeline and not a format change**, so there is nothing to fix on our side. It is excluded from the run-through uptime streak for the same reason."$'\n\n'
  body+="**Self-managing:** members are refreshed each retry; a source drops off when it fetches cleanly and this issue auto-closes once all recover. A source that keeps failing for **≥ 2 consecutive days** is promoted to its own \`${LABEL_SKIP}\` alarm (a sustained 5xx / hung connection can be a block in disguise)."$'\n\n'
  body+="Last checked: ${checked}"$'\n'"Run log: ${run_link}"

  if [[ -n "$umbrella_num" ]]; then
    echo "skip_issues: refreshing umbrella #${umbrella_num} (${#UMBRELLA_ERR[@]} member(s))."
    gh issue edit "$umbrella_num" --body "$body" \
      || echo "skip_issues: edit of umbrella #${umbrella_num} failed (non-fatal)." >&2
  else
    echo "skip_issues: opening umbrella outage issue (${#UMBRELLA_ERR[@]} member(s))."
    # Capture the number straight from create's URL: `gh issue list` is eventually
    # consistent, so re-querying right after create can miss the new issue and leave the
    # regroup step (3a) below with no umbrella to point at.
    created_url="$(gh issue create --title "$OUTAGE_TITLE" --label "$LABEL_OUTAGE" --body "$body" 2>/dev/null || true)"
    umbrella_num="$(grep -oE '/issues/[0-9]+' <<< "$created_url" | grep -oE '[0-9]+$' | tail -1)"
    if [[ -z "$umbrella_num" ]]; then
      echo "skip_issues: create of umbrella returned no issue number — falling back to list." >&2
      umbrella_num="$(gh issue list --label "$LABEL_OUTAGE" --state open --json number,title \
          --jq "map(select(.title == \"${OUTAGE_TITLE}\")) | .[0].number // empty")"
    fi
  fi
fi

# --- 3. close recovered / reclassified ---------------------------------------------------
# 3a. per-source `etl-skip` issues whose id is no longer an alarm.
open_skip="$(gh issue list --label "$LABEL_SKIP" --state open --json number,title \
    --jq '.[] | [(.number | tostring), .title] | @tsv')"
if [[ -n "$open_skip" ]]; then
  while IFS=$'\t' read -r number ititle; do
    [[ -z "$number" ]] && continue
    id="${ititle#Fetch skip: }"; id="${id% failed}"
    [[ -n "${ALARM_ERR[$id]:-}" ]] && continue           # still a hard alarm -> keep open
    if [[ -n "${UMBRELLA_ERR[$id]:-}" ]]; then
      # Still failing, but a transient upstream skip now -> fold into the umbrella.
      [[ -n "${CLOSE_ONLY:-}" ]] && continue             # leave regrouping to an open-capable run
      [[ -z "$umbrella_num" ]] && continue               # no umbrella to point at; keep open
      echo "skip_issues: '${id}' is a transient upstream skip — regrouping #${number} into #${umbrella_num}."
      gh issue close "$number" \
        --comment "Regrouped: \`${id}\` is a transient upstream outage (HTTP 5xx / timeout), now tracked together in #${umbrella_num}. Closing this per-source issue." \
        || echo "skip_issues: close of #${number} failed (non-fatal)." >&2
    else
      echo "skip_issues: '${id}' fetched cleanly again — closing #${number}."
      gh issue close "$number" \
        --comment "Resolved: \`${id}\` fetched cleanly again as of ${checked}. Closing automatically." \
        || echo "skip_issues: close of #${number} failed (non-fatal)." >&2
    fi
  done <<< "$open_skip"
fi

# 3b. umbrella: close when no transient skips remain this run (safe in CLOSE_ONLY too).
if [[ ${#UMBRELLA_ERR[@]} -eq 0 && -n "$umbrella_num" ]]; then
  echo "skip_issues: no upstream skips — closing umbrella #${umbrella_num}."
  gh issue close "$umbrella_num" \
    --comment "Resolved: every upstream source fetched cleanly again as of ${checked}. Closing automatically." \
    || echo "skip_issues: close of umbrella #${umbrella_num} failed (non-fatal)." >&2
fi

echo "skip_issues: done."
