# Self-healing ETL (concept — not yet built)

A design sketch for closing the loop between the **uptime tracker** and the
**daily scrape**: when a source breaks, an AI agent fixes the parser, opens a PR,
and (once trusted) the fix merges and re-runs the same day — so the day still
counts green.

This is a concept note, parked for later. Nothing here is implemented. The
companion mechanics already exist: the [uptime tracker](../UPTIME.md) (`R/uptime.R`),
the skip alarm (`.github/scripts/skip_issues.sh`), and the daily Action
(`.github/workflows/etl.yml`).

---

## Why here, and why now

Self-healing only works when failures are **narrow, typed, and cheaply
verifiable**. This repo has all three, which is what makes it a good first place
to try it:

- **Narrow.** Each source is its own parser (`R/source_seco.R`, `R/source_snb.R`,
  `R/source_fso_*.R`, …). A skip is almost always *one* of these breaking because
  an upstream changed format. The fix is a small, local diff in one file.
- **Typed trigger.** `skip_issues.sh` already opens an `etl-skip` issue carrying
  the dataset id and the exact fetch error. That issue *is* the work order — no
  detection layer to build.
- **Cheap to verify.** `R/pipeline.R` + `R/health.R` already fetch and validate a
  source. And the data is disposable (regenerated daily), so a bad merge is a
  `git revert`, not a data-loss event. The repo is public, so Actions are free.

## The loop

```
etl-skip issue opens
   │  (carries: dataset id + fetch error)
   ▼
AI agent — given the issue + the one source_*.R it names
   • diagnoses the format change
   • edits the parser
   • re-runs pipeline for that source, confirms health.R passes
   ▼
opens a PR  ──▶  [confidence dial]  ──▶  merge
   ▼
re-run etl workflow (same day)
   ▼
uptime.R upserts today's row  ──▶  🟢  (same-day fix = green)
```

The last hop is the existing **same-day rule**: `R/uptime.R` keeps one row per day
keyed on date, so a re-run after a fix overwrites the red row with green. The AI
fix only *keeps the day green* if fix → merge → re-run all land before midnight.

## The tension to decide up front

"Open a PR, auto-merge if no human reacts after a while" **fights the green
streak.** If the wait is 24 h, the fix lands tomorrow and today goes red anyway
(it self-heals as a 1-day blip, but the streak breaks). So there is a fork, and
you cannot have both a slow human-safety window *and* an unbroken green line:

- **Streak-first** — auto-merge *fast* on green CI (minutes); the human veto is a
  revert.
- **Caution-first** — human-in-the-loop merge; accept that AI-fixed incidents
  still show a 1-day red dip that recovered.

The brag-worthy 90-day green streak implicitly wants the aggressive setting.

## The confidence dial

The autonomy level is a dial you **turn up with evidence**, not set on day one.
What earns each step up is a track record of good fixes plus a strong CI gate —
auto-merge is only ever as safe as what blocks it.

1. **PR-only.** AI proposes, a human always merges. Watch 3–5 real incidents.
   Builds trust; breaks streaks.
2. **Auto-merge on green CI, narrow scope.** AI may only touch `R/source_*.R` (a
   path allowlist); CI must pass; auto-merge is fast. Core pipeline / health /
   uptime logic stays human-only.
3. **Direct commit.** Once parser fixes are boringly reliable.

### What the CI gate must assert (to earn step 2)

Auto-merge is only as safe as the checks that block it. Before a fix may merge
itself, CI should confirm the fix produced *plausible* data, not just *some* data:

- the named source actually fetches (no skip);
- row count is non-trivial and within sane bounds of the previous run (no silent
  collapse to a handful of rows);
- the schema / dimension columns are unchanged;
- `health.R` is green for that dataset.

Most of this already lives in `R/health.R`; it would want a "did this fix produce
plausible data" assertion as the explicit merge gate.

## Guardrails

- **Path allowlist.** The agent may edit only `R/source_*.R`. The pipeline core,
  `health.R`, `uptime.R`, and the workflows are off-limits to auto-fix.
- **Small, explained diffs.** The PR body should state which upstream format
  change was detected and how the parser was adjusted.
- **Revert, not rollback ceremony.** A bad merge is a `git revert`; data is
  regenerated on the next run regardless.

## Smallest viable first build

A `.github/workflows/autofix.yml` triggered by `on: issues: [labeled]`, filtered
to the `etl-skip` label, that runs an AI coding agent with:

- the issue body (dataset id + error),
- the named `R/source_*.R`,
- instructions to **fix → verify with the pipeline/health check → open a PR**,

scoped to parsers only, **PR-only, no auto-merge**. Run it against a few real
skips, read its diffs, and *then* decide whether to turn the dial.

## Relationship to "exit beta"

Exit-beta is narrative, not automation. The plan: run the pipeline green for
90 days, then drop the `beta` tag on `dataseries.org`
(`web/src/main.ts`, the `<span class="tag">beta</span>` in the wordmark) and
change how the project is described. The 90-day green streak is the proof; the tag
removal is a one-line manual flip when the number is worth bragging about.
Self-healing is what makes that streak *achievable* — it is the means, not a
prerequisite to automate.
