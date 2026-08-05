#!/usr/bin/env bash
#
# test_issues.sh — run the datasheet guards and REPORT failures instead of
# breaking the pipeline.
#
# The guards in tests/ check things the ETL itself cannot: that a datasheet and
# its generated output still agree, that no curated string has crept into the
# fetch code, that a translation still matches the English it was written from.
# Until now nothing ran them — six suites, each invoked by hand — so a datasheet
# edit that broke one stayed broken until somebody happened to look.
#
# They must not gate the data, though. A red guard means "a human should look at
# this", not "publish nothing today": the numbers are still correct and users
# still want them. So this runs every suite, lets the workflow succeed either
# way, and opens ONE deduped issue per failing suite, labelled `data-guard`.
# An issue whose suite passes again is closed automatically.
#
# Same shape as health_issues.sh — per-subject issue, dedupe by exact title,
# close stragglers — because a second alarm mechanism nobody recognises is worse
# than a familiar one.
#
# Dependencies: gh (present on GitHub-hosted runners), Rscript.
# Auth: GH_TOKEN in the environment; the job needs `permissions: issues: write`.
# Idempotent: running it twice adds a comment, never a duplicate issue.

set -uo pipefail   # deliberately NOT -e: a failing suite is the case we handle

LABEL="data-guard"
MAX_LOG=3000       # issue bodies are capped; keep the head, that is where R errors are

server="${GITHUB_SERVER_URL:-https://github.com}"
repo="${GITHUB_REPOSITORY:-}"
run_link=""
if [[ -n "$repo" && -n "${GITHUB_RUN_ID:-}" ]]; then
  run_link="${server}/${repo}/actions/runs/${GITHUB_RUN_ID}"
fi

mapfile -t suites < <(find tests -maxdepth 1 -name 'test_*.R' | sort)
if [[ ${#suites[@]} -eq 0 ]]; then
  echo "test_issues: no suites found — run me from the repo root." >&2
  exit 0
fi

# No gh, or no auth (a local run) -> still run the suites and report to stdout,
# then stop before every issue call fails one by one. DRY_RUN=1 forces this.
REPORTING=1
if [[ -n "${DRY_RUN:-}" ]] || ! command -v gh >/dev/null 2>&1 \
   || ! gh auth status >/dev/null 2>&1; then
  REPORTING=0
  echo "test_issues: no gh auth (or DRY_RUN) — running the suites, reporting to stdout only."
else
  gh label create "$LABEL" \
      --description "A tests/ guard is failing (reported, does not block the ETL)" \
      --color "D93F0B" 2>/dev/null \
    || echo "test_issues: label '$LABEL' already exists (or create skipped)."
fi

# --- 1. Run every suite, remembering which failed and why -------------------

declare -A FAILED=()
for f in "${suites[@]}"; do
  name="$(basename "$f")"
  echo "test_issues: running ${name}"
  if ! out="$(Rscript "$f" 2>&1)"; then
    echo "test_issues: ${name} FAILED"
    FAILED["$name"]="$out"
  fi
done

if [[ ${#FAILED[@]} -eq 0 ]]; then
  echo "test_issues: all ${#suites[@]} suites green."
fi

if [[ $REPORTING -eq 0 ]]; then
  for name in "${!FAILED[@]}"; do
    printf '\n--- %s ---\n%s\n' "$name" "${FAILED[$name]}"
  done
  echo "test_issues: done (${#FAILED[@]} failing of ${#suites[@]}); no issues filed."
  exit 0
fi

# --- 2. Open or refresh one issue per failing suite -------------------------

for name in "${!FAILED[@]}"; do
  issue_title="Data guard: ${name} is failing"
  log="${FAILED[$name]}"
  [[ ${#log} -gt $MAX_LOG ]] && log="${log:0:$MAX_LOG}
… (truncated — see the run log)"

  existing="$(gh issue list --label "$LABEL" --state open \
      --json number,title \
      --jq "map(select(.title == \"${issue_title}\")) | .[0].number // empty" 2>/dev/null)"

  if [[ -n "$existing" ]]; then
    echo "test_issues: #${existing} already tracks ${name} — adding a still-failing note."
    gh issue comment "$existing" \
      --body "$(printf '%s\n' "Still failing." "" '```' "$log" '```' \
                  ${run_link:+"" "Run log: ${run_link}"})" \
      || echo "test_issues: comment on #${existing} failed (non-fatal)." >&2
  else
    echo "test_issues: opening an issue for ${name}."
    body="$(printf '%s\n' \
      "\`tests/${name}\` is failing. The data was still refreshed and published — these guards report, they do not gate." \
      "" \
      '```' "$log" '```' \
      ${run_link:+"" "Run log: ${run_link}"} \
      "" \
      "Reproduce locally: \`Rscript tests/${name}\` (or \`Rscript tests/run_all.R\` for all of them)." \
      "" \
      "_Opened automatically by the daily ETL; closes itself once the guard passes again._")"
    gh issue create --title "$issue_title" --label "$LABEL" --body "$body" \
      || echo "test_issues: create for ${name} failed (non-fatal)." >&2
  fi
done

# --- 3. Close stragglers: open issues whose suite passes again --------------

open_issues="$(gh issue list --label "$LABEL" --state open \
    --json number,title --jq '.[] | [(.number | tostring), .title] | @tsv' 2>/dev/null)"

if [[ -n "$open_issues" ]]; then
  while IFS=$'\t' read -r number ititle; do
    [[ -z "$number" ]] && continue
    name="${ititle#Data guard: }"
    name="${name% is failing}"
    if [[ -z "${FAILED[$name]:-}" ]]; then
      echo "test_issues: ${name} passes again — closing #${number}."
      gh issue close "$number" \
        --comment "Resolved: \`tests/${name}\` passes again. Closing automatically." \
        || echo "test_issues: close of #${number} failed (non-fatal)." >&2
    fi
  done <<< "$open_issues"
fi

echo "test_issues: done (${#FAILED[@]} failing of ${#suites[@]})."
exit 0   # never break the pipeline
