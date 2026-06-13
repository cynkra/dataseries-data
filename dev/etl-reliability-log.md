# ETL reliability log

A running journal of ETL reliability incidents (timeouts, cancellations, broad
source outages) and the candidate fixes we've considered — **not** a spec for a
fix we've committed to.

The point is to be evidence-driven. Each incident here is bounded mitigation
already shipped (or none) plus the open question it raises. We deliberately
**don't** build the big robustness solution yet: the right design depends on
which failure mode actually recurs. A broad `admin.ch` outage that happens once a
quarter needs a different (cheaper, or no) fix than one that hits weekly, or than
a slow creep of per-source parser breaks. So we log, watch, and revisit the
"Candidate solutions" section once the pattern is clear.

If you're here because the ETL just timed out again: add an entry to **Incident
log** (template below), check it against the existing entries, and only then ask
whether the pattern now justifies one of the candidate solutions.

## How to add an entry

Copy this template to the top of the Incident log (newest first):

```
### YYYY-MM-DD — one-line symptom

- **Run:** <run id / link>, trigger (schedule|dispatch), conclusion.
- **Symptom:** what was observed.
- **Root cause:** the actual mechanism, with numbers if you have them.
- **Why mitigations didn't catch it:** which existing guard was supposed to help and why it didn't.
- **Blast radius:** what data/alerts were affected.
- **Action taken this time:** what we did to recover (often: just re-ran).
- **Pattern bucket:** broad-outage | single-host-outage | parser-break | runner/infra | other.
```

## Decision status

**Superseded 2026-06-13 — stay on GitHub-hosted runners; beat the partial-IP block with
repeated fresh-IP draws instead of moving egress off-runner.** The block is a *partial*
Azure-range null-route (06-11 probe: 2/10 runner IPs dropped, all Azure), and crucially
**each scheduled GHA run draws a fresh egress IP** — so retrying the failed sources in
separate runs is itself a fix, without leaving the single-repo / all-GHA architecture.
Shipped (06-13): no-retry-on-dead-host (a blocked run completes-with-skips, not cancels) +
two targeted fresh-IP retry passes (lunch + afternoon) + broad-outage in-run-retry gate +
stale-keep. See the 06-13 incident and the SHIPPED items in Candidate solutions.

This **supersedes the 2026-06-11 decision** to move CH-source execution off GitHub
(worker-on-Hetzner → push, written up in [`etl-offload-plan.md`](etl-offload-plan.md)).
Off-runner is now the **escalation of last resort**, justified only if the block widens
from a *subset* of Azure IPs to *most* of them (p→1), where fresh-IP draws stop helping —
re-probe the runner IPs (06-11 method) before reviving it.

Posture: a blocked morning self-heals on a later fresh-IP retry; recover manually (full
local run from a Swiss IP) only on the rare all-day, all-IP block, which the watchdog flags.

(History: "open — collecting evidence" 2026-06-08→06-11; "move off-runner, deferred one
cycle" 2026-06-11→06-13; "watch 06-12" resolved clean, but 06-13 re-block showed the
recurrence is the steady state → chose the in-model fix.)

## Candidate solutions (considered, not decided)

Captured so the analysis isn't re-derived each time. Tiers are cost/risk, low to
high. See the 2026-06-08 incident for why the *per-source* caps we already have
don't bound a *broad* outage.

**Tier A — cheap, targeted, no architecture change:**

- **Per-host circuit breaker.** After host H fails K times this run, short-circuit
  H's remaining sources instantly instead of re-paying the full timeout each.
  Directly kills the cascade (outages correlate by host). Needs host attribution
  surfaced into `.try_fetch` (today it only sees a label + a lazy promise; the
  error message does carry `[host]`).
- **[SHIPPED 2026-06-13] Don't retry pure connection failures.** `req_retry` had
  `retry_on_failure = TRUE`, dialing a dead host `max_tries` times (~74s/host).
  Backoff/retry is for 429/5xx (alive-but-throttled, the PX-Web reason); it does
  nothing for a connect timeout. Now `FALSE` (http.R) — `is_transient` still retries
  429/5xx. A dead host costs one 15s attempt, so a blocked run **completes with skips
  in ~19min instead of cancelling at the 30-min cap**, and records the skips in
  run.json. This is the keystone: a completed run is what the targeted lunch/afternoon
  retries (fresh IPs) and the stale-keep need.
- **Global soft-deadline → partial success.** Once total run elapsed crosses
  ~22 min, stop *starting* fetches, mark the rest `skipped: not-attempted
  (deadline)`, and fall through to write the partial catalog + `run.json`. Turns a
  hard `cancelled` (which writes nothing and reports nothing) into a graceful,
  precisely-reported partial run. Must distinguish `skipped: failed` from
  `skipped: not-attempted` so deadline-skips don't look like parser breaks.
  *(Largely obviated by the no-retry-on-connect change above + the broad-outage gate
  below, which keep a blocked run under the cap; keep as a backstop idea if a future
  outage shape still pushes past 30 min.)*
- **[SHIPPED 2026-06-13] Gate the in-process retry pass.** The `RETRY_SLEEP` (180s) +
  refetch pass helps an *isolated* transient blip but is futile against a *broad*
  outage (it re-dials the SAME runner IP). Now skipped when `> RETRY_MAX_INPROCESS`
  (default 3) sources fail at once (pipeline.R) — saving ~RETRY_SLEEP + Nx15s on a
  blocked day; those skips go to the fresh-IP cross-run retries instead.
- **[SHIPPED 2026-06-12, extended 2026-06-13] Targeted retry passes on fresh IPs.** A
  separate `.github/workflows/etl-retry.yml` re-fetches ONLY the morning's skips
  (`ETL_MODE=retry` → `retry_skipped()`). As of 06-13 it runs **twice** — lunch
  (10:30 UTC, `CLOSE_ONLY`) and afternoon (14:15 UTC, opens issues) — because each
  scheduled run draws a **fresh GitHub-runner egress IP**, so each is an independent
  fresh-IP draw at the handful that failed (the admin.ch block hits a *subset* of Azure
  IPs). With the morning now completing-with-skips, the chain is: morning records skips →
  lunch retries on a fresh IP → afternoon retries on another → only then alarm. P(all 3
  draws blocked) ≈ p³ (≈12% at p=0.5, <1% at p=0.2), down from p. Only the LAST pass
  opens `etl-skip` issues (lunch is close-only; a source still failing at noon may clear
  on the afternoon IP). Usage logged to `data/retry.csv`. This is the **in-model
  alternative to off-runner egress** — chosen 2026-06-13 because it keeps the
  single-repo / all-GHA architecture (user preference); off-runner (Tier B) deferred
  indefinitely. See the 2026-06-13 incident.
- **[SHIPPED 2026-06-13] Stale-keep on skip.** A completed-with-skips run must not DROP
  the skipped datasets from `catalog.json` (they'd vanish from the API until a retry).
  main() now reloads a skipped source's previous on-disk files into the catalog (shown
  stale, old `fetched` date); the id still rides in run.json `skipped` so retries + alarm
  act on it. Fixes a latent bug that only mattered once blocked-mornings-complete became
  the norm. Note: because a completed run writes today's `uptime.csv` row even when red,
  the **watchdog now fires only on a *total* failure** (no row at all); *partial* failures
  surface as `etl-skip` issues from the last retry pass.

**Tier B — structural isolation (the deferred "Tier 2"):**

- **Provider matrix in `etl.yml`.** One CI job per provider/host, each with its own
  30-min budget; an aggregation job merges + commits + runs health. A SECO outage
  blows only the SECO job; the rest stay green and fresh, and the failure is
  self-attributing. Plumbing is half-built already (`build(only=)` + `.ONLY`).
  Cost: artifact passing, a merge/commit job, partial-failure commit semantics.
- **Execute the CH-source fetches off GitHub-hosted runners (the IP-block fix).** admin.ch
  intermittently blocks GitHub's Azure runner IPs (see 2026-06-10), so no in-pipeline
  timeout tuning can fetch the data — it must egress from a non-blocked IP. Options: a
  self-hosted runner on a CH/EU box, running the ETL on Hetzner/locally and pushing (proven
  2026-06-10), or routing the CH requests through an egress proxy. The swissdata-served
  sources (SECO) are reachable everywhere; only the direct `*.admin.ch` BFS/FFA fetches
  need this. **→ Chosen 2026-06-11.** The three options were compared on *trust direction*;
  the recommended one is **worker-on-Hetzner → push to GitHub** (outbound, single-repo
  token; safe for a public repo). Full design + trade-offs: [`etl-offload-plan.md`](etl-offload-plan.md).

**Tier C — highest performance, highest risk:**

- **Parallelize fetches within R** (`httr2::req_perform_parallel` / `mirai`).
  Overlaps idle network wait; a 16-min run could drop to ~3–4 min. But the
  fetchers are bespoke (some chunk internally), concurrent error handling is
  harder, and PX-Web/DAM throttle under burst (429) — would need per-host
  concurrency caps or you trade timeouts for throttling.

**Recommendation on file (if/when we act):** Tier A trio (circuit breaker +
no-retry-on-connect + soft-deadline) first — ~40–60 lines, no architectural risk,
kills the cascade and makes every future timeout a graceful reported partial run.
Tier B when per-provider isolation becomes a deliberate goal. Tier C only if raw
speed becomes a goal in itself. Bumping `timeout-minutes` 30→45 is a temporary
cushion *alongside* a real fix, not a fix.

## What would change our mind (revisit thresholds)

Act on a candidate solution when one of these crosses:

- **Broad outage recurs ≥ ~monthly** (or twice in a quarter) → ship Tier A.
- **Any single broad outage refreshes nothing for > ~1 day** (re-run also fails) →
  ship Tier A's soft-deadline at minimum (partial success beats all-or-nothing).
- **Failures stop correlating by host** (independent per-source breaks dominate) →
  circuit breaker won't help; reconsider toward per-source budgets / parser tests.
- **We want per-provider attribution / isolation as a feature** → Tier B.
- **Total runtime itself becomes a constraint** (not just outage tails) → Tier C.
- **The 30-min cancels recur and reachability shows admin.ch up everywhere but the runner**
  (intermittent runner-IP block, per 2026-06-10) → move CH-source execution off
  GitHub-hosted runners (self-hosted/Hetzner/local/proxy); timeout tuning can't fetch
  through an IP block. **→ CROSSED 2026-06-11** (probe: 2/10 Azure runner IPs null-routed,
  silent TCP drop; see that incident + [`etl-offload-plan.md`](etl-offload-plan.md)).

## Incident log

### 2026-06-13 — admin.ch block returns (3rd cancel in 4 days); afternoon retry can't rescue a *cancelled* morning

- **Run:** [27462762798](https://github.com/cynkra/dataseries-data/actions/runs/27462762798),
  schedule, **cancelled** at the `timeout-minutes: 30` cap (started 09:21, killed 09:51).
- **Symptom:** the now-familiar shape — every timeout is an admin.ch host
  (`www.pxweb.bfs.admin.ch`, `dam-api.bfs.admin.ch`), each connect-timing-out at 15002 ms;
  ~12 FSO sources skipped serially (15 s each) blew the 30-min budget before the commit.
  Both alarms fired as designed: `etl-failure` #11 (inline) and `watchdog` #12 (backstop).
- **Root cause:** same partial-Azure-range IP block proven on 06-11 — this morning's runner
  drew a blocked egress IP. **Not** related to the SNB conditional-fetch / retry code shipped
  06-12/06-13: SNB (`data.snb.ch`) is reachable and absent from the failures, and a code bug
  would `fail` fast, not run to the 30-min cap. Cadence now: 06-10, 06-11, 06-13 cancelled vs
  06-09, 06-12 clean — i.e. ~half of scheduled runs, matching the ~20 %-of-IPs-blocked probe
  compounded over the all-or-nothing per-run IP draw.
- **New finding — the afternoon retry does NOT cover a cancelled morning.** `etl-retry.yml`
  ran 14:57 and correctly **no-opped**: its gate requires a `run.json` dated *today* with
  skips, but a *cancelled* morning never reached the step that writes `run.json` (it's stale
  from 06-12). This is by design (never retry a stale skip list), so the retry second-pass
  helps a morning that *completed with skips*, not one that was *killed*. The independent
  `watchdog.yml` remains the only backstop for a cancelled morning — and the real fix is still
  off-runner egress (decided 06-11, see [`etl-offload-plan.md`](etl-offload-plan.md)).
- **Blast radius:** cancelled run, no data committed; #11 + #12 opened.
- **Action taken this time:** recovered by running the full pipeline **locally from a Swiss IP**
  (admin.ch reachable here: 302/200, fast connect) and pushing. This doubled as the first real
  full-set run of the SNB conditional-fetch, bootstrapping `updated` for all SNB cubes. Closed
  #11 manually; #12 auto-closes once `data/uptime.csv` advances to 06-13.
- **Pattern bucket:** runner/infra (partial-Azure-range IP block) — recurring, as predicted.
- **Decision (revised same day):** off-runner egress (Tier B) is **deferred indefinitely** —
  it trades away the single-repo / all-GHA simplicity the project values. Instead, shipped an
  **in-model mitigation** that attacks the cause (a blocked IP) with repeated *fresh-IP draws*:
  (1) `retry_on_failure = FALSE` so a blocked run completes-with-skips (~19 min) instead of
  cancelling; (2) the targeted retry now runs **twice** (lunch + afternoon), each a fresh
  runner IP, re-fetching only the failed sources; (3) the in-process same-IP retry is gated off
  for broad outages; (4) stale-keep so skipped datasets don't vanish from the catalog. Net: a
  blocked morning self-heals on a later fresh IP with no manual step; only an all-day, all-IP
  block (≈p³) still needs a manual run. Off-runner remains the documented escalation if the
  block ever widens to most Azure IPs (p→1, where fresh draws stop helping).

### 2026-06-12 — UZH connect-timeout outlasts the 180s in-run retry; shipped an afternoon second-pass

- **Run:** [27407704818](https://github.com/cynkra/dataseries-data/actions/runs/27407704818),
  schedule, **success** — the admin.ch block had a *good day*: the 06-11 decision's "watch the
  06-12 scheduled run" resolved as **no cancel** (a clean Azure egress IP; admin.ch all fetched).
  69/70 sources OK.
- **Symptom:** one source, `ch_adecco_sjmi` (Adecco SJMI, hosted at
  `www.stellenmarktmonitor.uzh.ch` — **UZH, not admin.ch**), connect-timed-out at 15 s (09:56).
  The in-run 180 s retry pass fired (09:56 → 10:00) and it **still** timed out → the skip
  survived → opened `etl-skip` #10. Second occurrence of this exact UZH timeout in 4 days (first
  was #2 on 06-08, which self-closed the next run).
- **Root cause:** plain transient single-host unreachability at UZH — a silent connect timeout,
  host back up within hours (verified same afternoon: HTTP 302 in ~20 ms). Not a format break.
  The 180 s `RETRY_SLEEP` only rides out a blip of a few minutes; UZH was down longer.
- **Why mitigations didn't catch it:** the in-process retry pass is too short for a >3-min host
  outage, and the `etl-skip` alarm fired *immediately* after it — a false "act ASAP, source
  changed format" issue for what was a passing outage.
- **Blast radius:** 1 dataset kept previous data (1 day stale); one noise `etl-skip` issue (#10).
- **Action taken this time → SHIPPED a mitigation (not just a re-run):** added an **afternoon
  retry second pass**. New `.github/workflows/etl-retry.yml` runs ~6 h after the morning cron,
  re-fetches ONLY the morning's skips, and is now the **sole** place the `etl-skip` alarm opens;
  the morning runs `skip_issues.sh` in new **`CLOSE_ONLY`** mode (closes a recovered source's
  issue, never opens one). So a transient that clears by mid-afternoon never alarms; only a
  source that STILL fails a much-later second attempt does. R side: `R/pipeline.R` gains
  `ETL_MODE=retry` → `retry_skipped()` (reads `data/run.json`, `build(only=)`,
  `merge_into_catalog()`, rewrites `run.json`, appends `data/retry.csv`); `finalize_dataset()`
  extracted so the full run and the retry finalize identically. Usage is tracked in
  `data/retry.csv` (one row per day a retry actually ran).
- **Bonus vs the admin.ch block:** the afternoon job is a SEPARATE Actions run ⇒ a FRESH runner
  egress IP, i.e. a second roll of the dice for the admin.ch sources on a partial-block day. A
  useful *complement* to — **not** a replacement for — the off-runner plan (still an Azure range,
  can still draw a blocked IP; and it only retries what the morning skipped, which on a blocked
  morning is the whole CH set).
- **Pattern bucket:** single-host-outage (UZH), transient.

### 2026-06-11 — probe proves it: admin.ch null-routes a *subset* of Azure runner IPs (not the whole ASN)

- **Run:** [27338228345](https://github.com/cynkra/dataseries-data/actions/runs/27338228345),
  schedule, **cancelled** at the `timeout-minutes: 30` cap — 2nd straight day (after 06-10).
- **Symptom:** same shape — full 30 min, killed mid-build, no data. Both alarms fired this
  time: `etl-failure` #8 (inline) **and** `watchdog` #9 (the independent backstop) — as designed
  (a cancellation slips past the inline alarm, which is exactly why the watchdog exists).
- **Root cause — now directly proven, not inferred.** Dispatched a throwaway 10-job matrix
  probe (each job = a fresh Azure runner egress IP) curling the three admin.ch hosts + controls:
  - **8/10 IPs connected in ~100 ms** (HTTP 302/200); **2/10 were silently dropped** —
    `52.161.59.3` and `145.132.102.54` returned `connect=0.000 / http=000`, i.e. the TCP
    handshake never completes — the *identical* signature to the ETL's 15 s connect timeouts.
  - **All ten IPs are Microsoft Azure** (`MSFT`/`cloud`). So admin.ch null-routes a **subset of
    Azure ranges, not the ASN** — the clean and the blocked IPs are the same provider.
  - **No CDN/WAF in front:** the hosts resolve straight to `162.23.128.x` (BIT, Swiss federal
    admin) and `193.246.70.x` (Abraxas, the CH gov IT provider); `Server: Apache`, no edge
    headers. The block is therefore a **network-level firewall/blocklist at admin.ch itself**,
    not a third-party edge rule.
- **What this explains / quantifies:** ~20 % of sampled IPs blocked ⇒ matches the ~50 % of
  daily runs that cancel (each run picks one egress IP and uses it for *all* admin.ch fetches:
  a blocked IP → every CH source connect-times-out → blow the 30-min budget; a clean IP →
  ~16-min green run). The **silent DROP** (not RST, not 403) is the signature of an
  IP-reputation/datacenter blocklist, **not** app-layer rate-limiting — so it is unrelated to
  our request volume or pattern; a clean IP connects instantly with our exact requests. Onset
  was **06-05** (first scheduled cancel; 06-01→06-04 all green), so the change was on
  **admin.ch's side** — most plausibly a datacenter/cloud-IP blocklist or anti-scraping edge
  rule rolled out in early June — not anything we changed.
- **Why mitigations can't catch it:** unchanged from 06-10 — **no in-pipeline guard can fetch
  data that's null-routed from the runner.** Tier A (circuit breaker / no-retry-on-connect /
  soft-deadline) would only convert the `cancelled` into a graceful *partial* run; it cannot
  obtain the CH data.
- **Blast radius:** cancelled run, no data; #8 + #9 opened.
- **Action taken this time:** ran the full pipeline **locally from a Swiss IP** → **70/70
  green, 0 skips** → pushed `a9161cd`. Closed #8 manually; dispatched `watchdog.yml` so it saw
  the fresh `data/uptime.csv` row and **auto-closed #9**. (The probe was a throwaway workflow,
  added and removed on `main`.)
- **Pattern bucket:** runner/infra (partial-Azure-range IP block) — now **confirmed and
  quantified**, not hypothesized.
- **Decision:** crosses the log's own threshold (*"30-min cancels recur AND admin.ch up
  everywhere but the runner"*). Posture moves from "collect evidence / re-run" to **commit to
  off-runner CH egress.** Options, trade-offs, and the recommended design
  (worker-on-Hetzner → push to GitHub) are in [`etl-offload-plan.md`](etl-offload-plan.md).
  Implementation deferred one cycle to watch the 06-12 scheduled run; recover manually (as
  today) if it cancels again.

### 2026-06-10 — the recurring 30-min cancels are a GitHub-runner IP block; the "SECO 502s" were a permanent source migration

- **Run:** [27266968183](https://github.com/cynkra/dataseries-data/actions/runs/27266968183),
  schedule, **cancelled** at the `timeout-minutes: 30` cap (again).
- **Symptom:** same shape as 06-05/06-07/06-08 — full 30 min, killed mid-build, no data.
  Separately, the 3 SECO datasets had been returning HTTP 502 for days.
- **Root cause — TWO distinct things, both previously mis-read as "transient outage":**
  1. **Runner-IP block, not an upstream outage.** `dam-api.bfs.admin.ch`,
     `www.pxweb.bfs.admin.ch`, `www.data.finance.admin.ch` answer in ~20–100 ms from a
     Swiss IP **and from a Hetzner box in Germany**, but every TCP connect from the
     GitHub-hosted runner times out at 15 s. admin.ch is intermittently
     blocking/null-routing GitHub's Azure runner ranges. Run history fits: ~half of recent
     runs cancel at exactly 30 min, half finish in ~16 min; the morning scheduled runs tend
     to pass. So "recovered ~1 h later" (06-08) was **a different runner IP**, not upstream
     recovery.
  2. **SECO 502 = permanent URL migration, not an outage.** SECO rebuilt its site and
     RETIRED the old `/dam/...download` URLs; machine-readable data now ships via
     `scheduler.swissdatas.ch` (see `docs/source-quirks.md` → SECO). The old URLs will never
     come back — re-running could never have fixed those three.
- **Why mitigations didn't catch it:** per-source caps held (~74 s/dead host) but don't
  bound the aggregate (as 06-08 noted). More importantly, **no in-pipeline guard can fetch
  through an IP block** — the data isn't reachable from the runner at all. The Tier A fixes
  (circuit breaker / no-retry-on-connect / soft-deadline) would only convert the cancel into
  a graceful *partial* run; they would not get the CH data.
- **Blast radius:** cancelled run, no data; `etl-failure` #7 opened. SECO skip issues
  #4/#5/#6 were accurate, but pointed at a migration, not an outage.
- **Action taken this time:** (a) ran the pipeline **off-GitHub** — Hetzner (DE) first to
  restore the 67 reachable datasets, then locally on a Swiss Mac; both reach admin.ch +
  swissdatas.ch — and pushed fresh data (green); (b) **repointed the 3 SECO sources to
  `scheduler.swissdatas.ch`** in code (`R/source_seco.R`, `R/pipeline.R`) + the 3
  datasheets. Full run is now 70/70, no skips, badge brightgreen.
- **Pattern bucket:** runner/infra (IP block) + parser/source-break (SECO migration). NOT
  broad-outage.
- **Correction to the 06-08 entry:** logged there as "broad *transient* admin.ch outage."
  Reachability evidence today reframes the recurring cancellations as an **intermittent
  GitHub-runner IP block** (admin.ch up everywhere except the runner). "Just re-run" is an
  unreliable recovery — it only works when the retry lands on an unblocked runner IP. The
  durable fix is executing the CH fetches off GitHub-hosted runners (new Tier B candidate).

### 2026-06-08 — 30-min timeout from a broad `admin.ch` outage

- **Run:** [27132839583](https://github.com/cynkra/dataseries-data/actions/runs/27132839583),
  manual dispatch, **cancelled** at the `timeout-minutes: 30` cap.
- **Symptom:** job ran the full 30 min and was killed mid-build; the R process was
  still fetching when terminated. A follow-up `etl-failure` issue (#3) opened; no
  data refreshed.
- **Root cause:** broad *transient* outage of Swiss federal infrastructure — SECO
  (`seco.admin.ch`), FFA finance (`data.finance.admin.ch`), and ~9 FSO/BFS
  endpoints (`pxweb.bfs.admin.ch`, `dam-api.bfs.admin.ch`) all connect-timed-out at
  once. Each dead source costs `connecttimeout 15s × max_tries 4 + backoff
  (2+4+8) ≈ 74s`. ~13 dead sources × 74s ≈ 16 min of pure failure, on top of
  ~14 min of healthy fetches → > 30 min. The hosts were reachable again ~1 h later
  (today's 09:51 scheduled run had succeeded), confirming a brief upstream blip.
- **Why mitigations didn't catch it:** the 2026-06-06 hardening caps each source's
  wall-clock (`connecttimeout` + `req_retry(max_seconds=180)` + `setTimeLimit(240)`),
  and it held — every source failed in ~74s, well under 240s. But **per-source caps
  don't bound the *aggregate*.** With a single sequential `build()` over ~70
  sources and no global budget, the run cost is the *sum* of the failures, and a
  broad multi-host outage makes that sum exceed the job budget.
- **Blast radius:** zero data refreshed that cycle (a `cancelled` job writes no
  `catalog.json` / `run.json`, so `skip_issues.sh` never ran → no precise
  per-source reporting, only the blunt `etl-failure` #3). Issue #2
  (`ch_adecco_sjmi` skip, from the 09:51 run) stayed open because the rerun never
  reached the skip-closer.
- **Action taken this time:** re-ran ~1 h later
  ([27135765841](https://github.com/cynkra/dataseries-data/actions/runs/27135765841)) →
  success in ~16 min, **zero skips**, 70 datasets, data committed. Issue #2
  auto-closed (adecco fetched cleanly, 353 rows). Issue #3 closed manually (the
  `etl-failure` step has no close-on-success branch).
- **Pattern bucket:** broad-outage (multi-host, transient).
- **Note:** also the 2nd/3rd timeout of this shape — 2026-06-05 (cancelled, the
  incident that prompted the 06-06 per-source hardening) and 2026-06-07 (cancelled,
  30m22s) fit the same broad-`admin.ch`-outage pattern. So this is the **3rd in
  ~3 days** at time of writing — worth watching closely against the monthly
  threshold above.
