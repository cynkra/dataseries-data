# Plan: expected-next-release safeguard (per-series overdue alarm)

**Status (2026-07-07): designed, not built.** Captured after the July SNB
question (see Motivation). Tackle when there's a clear slot; nothing is on fire,
the current 165-day stale wall still catches genuine deaths.

## Motivation

The daily health check (`R/health.R`) is purely lag-based: a monthly series only
trips red past ~165 days of silence, a quarterly past ~435, etc. That headroom is
deliberate (normal Swiss publication lag stays green), but it means the check
**cannot distinguish "on time" from "1-2 months late."** Both read green.

Concretely: on 2026-07-07 someone noticed only ~2 SNB datasets updated in early
July vs "many" in early June, and asked whether we missed some. We had not. The
SNB monthly bulk (monetary aggregates, bank lending, payments, CPI) publishes
around the 20th-23rd; the big June batch landed 06-22/06-23, and early June also
carried a catch-up backlog draining after the admin.ch IP-block outage (April obs
landed ~06-02, May obs ~06-22 for the same series, a double update). So early July
looked thin only because it was being compared against a distorted late-June. All
correct, but answering it took a manual git-history dig because STATUS.md's green
light says nothing about per-series cadence. This safeguard is the thing that
would have answered it automatically, and would page us if a series ever genuinely
skips its own release.

## Core decision: model the rule, not the date

Do **not** store a concrete "next release = 2026-07-12" per dataset. A list of
future dates goes stale the instant a release lands, needs constant regeneration,
and cannot self-correct after a late catch-up. Instead store a small, stable
**release rule** per dataset and compute the concrete expected date fresh on every
daily run. Rule + today's date regenerates the right answer every time and
auto-clears once the data shows up.

Because every observation is dated **period-start**, the rule needs three fields:

```
release:
  cadence: monthly     # length of one period (usually == frequency)
  lag: P1M12D          # ISO-8601 duration from period END to normal availability
  grace: P9D           # extra slack before we alarm
```

Daily evaluation is pure arithmetic over what `catalog.json` already carries:

```
latest end = 2026-05-01 (monthly) -> covers May, period_end = 2026-05-31
next period = June                -> next_period_end = 2026-06-30
expected    = next_period_end + lag  ~= 2026-07-12
alarm_after = expected + grace       ~= 2026-07-21
```

Alarm fires iff `today > alarm_after` **and** `end` has not advanced to the next
period.

Key subtlety: **measure lag from period END, not from the date stamp**, or you
alarm a full period early. Same trap the current `health.R` comments already flag.

This is a new **middle tier**, not a replacement. Keep the 165-day red as the
"genuinely dead" backstop. Add `overdue` (missed its own expected release + grace)
as the earlier, per-series-calibrated warning:

**green / overdue / stale / unknown**

## Data structure and where it lives

Two idiomatic options; pick one:

- **In each `datasets/*.md`** (hand-authored source of truth, next to the parsing
  recipe). Most discoverable, reviewed with the dataset, least drift. Preferred.
- **One `R/release_schedule.tsv`** (like `snb_cubes.tsv`). Lets you tune all ~70
  lags in a single diff; easier to bulk-seed. Fallback if per-md editing is noisy.

Either way the pipeline compiles the rule into `catalog.json` (add
`expected_next`, `alarm_after` per entry) and `health.R` consumes it exactly like
it reads thresholds today. The mechanism reuses the whole existing
catalog -> health -> STATUS.md -> "issue when actionable" chain. It is small; the
work is the schedule *content*, not the plumbing.

## Populating the schedule well (the actual work)

Do not hand-guess 70 lags.

1. **Learner (re-runnable script).** Read each series' observation dates (CSVs /
   git history) plus `fetched`/`updated`, compute the empirical distribution of
   `appeared - period_end`, propose `lag` at ~p80 and `grace` to cover ~p95. Emit
   the proposed lag/grace table for all ~70 for human sanity-check before wiring
   anything in. Re-running it later is itself a signal: if a source's real lag has
   drifted from its declared rule, that is worth knowing.
2. **Oddball overrides.** Irregular series (regional GDP every 1-2y, `devwkieffid`
   "whole month of daily at once", HICP long Eurostat lag, `zikredlauf` 3-4mo lag)
   need per-id rules. Reuse the exact list already in `health.R`'s `OVERRIDE`.
3. **Authoritative calendars (later graft).** FSO, SNB, SECO, KOF publish advance
   release agendas. Where a source exposes a real next-publication date, prefer it
   over the learned lag for high-value series (captures holidays / one-off shifts
   a fixed lag cannot). Per-source integration, so bolt it on after the learned
   model is running uniformly across all 70.

## Failure modes it must handle

1. **Period-start dating.** Lag measured from period end, not date stamp (above).
2. **Revisions vs new periods.** Key the check on `end` advancing to the next
   period, NOT on "the file changed." A revision moves `updated`/`fetched` without
   a new period and must not mask a missing release.
3. **Catch-up auto-clear.** Stateless daily recompute means a late arrival clears
   the alarm with no manual reset. This is exactly the June admin.ch backfill case.
4. **No flapping / alert fatigue.** Wire `overdue` into the existing "issue only
   when actionable" mechanism: one umbrella "overdue releases" issue, updated and
   auto-closed, never one page per series per day.

## Phasing

1. Add the `release` rule schema (in `datasets/*.md` or `R/release_schedule.tsv`)
   + the learner; hand-check the ~8 oddballs against `OVERRIDE`.
2. Extend `health.R` to compute `expected_next` / `alarm_after` and emit the new
   `overdue` tier into `status.json` and STATUS.md.
3. Hook `overdue` into the daily action's issue logic.
4. Later: graft authoritative source calendars for the series that matter most.

The artifact worth arguing over is the learner's proposed lag/grace table (step 1
output). Everything after it is plumbing.
