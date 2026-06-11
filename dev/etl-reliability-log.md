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

**Decision made 2026-06-11 — move CH-source execution off GitHub-hosted runners;
implementation deferred one cycle.** The runner-IP-block threshold in "What would
change our mind" is now **crossed**: the 2026-06-11 probe directly proved an
intermittent, *partial*-Azure-range null-route at admin.ch (2/10 runner IPs
silently dropped, 8/10 fine, all Azure). No in-pipeline fix can reach data that is
null-routed from the runner, so the only durable answer is off-runner egress. The
options, trade-offs, and recommended design (worker-on-Hetzner → push to GitHub)
are written up in [`etl-offload-plan.md`](etl-offload-plan.md).

Posture until built: recover by running the ETL off-GitHub (locally / Hetzner) and
pushing; the independent `watchdog.yml` remains the backstop. We deliberately watch
the **06-12** scheduled run before investing build effort — partial blocks have
good days, and one more observation costs nothing.

(History: "open — collecting evidence" from 2026-06-08 to 2026-06-11.)

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
- **Don't retry pure connection failures.** `req_retry(retry_on_failure = TRUE)`
  dials a dead host `max_tries` times. Backoff/retry is for 429/5xx
  (alive-but-throttled, the PX-Web reason); it does nothing for a connect timeout.
  Splitting the two cuts a dead-host cost ~5× (one connect attempt, not four).
- **Global soft-deadline → partial success.** Once total run elapsed crosses
  ~22 min, stop *starting* fetches, mark the rest `skipped: not-attempted
  (deadline)`, and fall through to write the partial catalog + `run.json`. Turns a
  hard `cancelled` (which writes nothing and reports nothing) into a graceful,
  precisely-reported partial run. Must distinguish `skipped: failed` from
  `skipped: not-attempted` so deadline-skips don't look like parser breaks.
- **Gate the in-process retry pass on time-remaining.** The `RETRY_SLEEP` (180s) +
  refetch pass helps an *isolated* transient blip but *adds* to the budget during
  a *broad* outage — skip it if we're already past ~20 min.

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
