# Plan: move CH-source ETL egress off GitHub-hosted runners

**Status (2026-06-11): decided in principle, not yet built.** Watching the 06-12
scheduled run first (see [`etl-reliability-log.md`](etl-reliability-log.md) →
Decision status). Recover manually meanwhile.

## Why

admin.ch intermittently **null-routes a subset of Azure runner IP ranges** (probe
on 2026-06-11: 2/10 GitHub runner IPs silently dropped at TCP connect, 8/10 fine,
all Microsoft Azure; the hosts sit on Swiss federal IPs with no CDN/WAF in front).
Each daily run uses one egress IP for *all* its `*.admin.ch` fetches, so a blocked
IP cancels the whole 30-min job; a clean IP sails through. Result: ~half of
scheduled runs cancel, no data. **No in-pipeline change can fix this** — the data
is unreachable from a blocked IP. The fix must change *where the request egresses
from*, to a stable non-blocked IP. Only the direct `*.admin.ch` BFS/FFA fetches
are affected; SECO already serves via `scheduler.swissdatas.ch` (reachable
everywhere), and CRAN/GitHub are fine.

## The real axis: which way does the trust arrow point?

All three options reach admin.ch from a non-blocked IP (the Hetzner box,
`91.98.74.173`, German IP, verified reaching all three hosts in ~100 ms). They
differ only in **trust direction** and in how much of the current GitHub setup
they keep.

| Option | Trust direction | Code/infra change | Verdict |
| --- | --- | --- | --- |
| **A. GitHub SSHes into Hetzner** (SOCKS egress proxy) | **Inbound to the box** | 4 lines in `R/http.R` + 1 workflow step | Smallest change, **worst trust** — an SSH key into a box that also runs CKAN/Outline/Kimai/Plane. Rejected on trust grounds. |
| **B. Worker on Hetzner → pushes to GitHub** | **Outbound from the box** | New container + timer on the box; ETL leaves Actions | **Recommended.** Cleanest trust; safe for a public repo. |
| **C. Self-hosted GitHub runner on Hetzner** | Outbound (runner pulls jobs) | `runs-on: self-hosted`; `etl.yml` otherwise unchanged | Keeps all Actions niceties, but the repo is **public** → fork-PR code execution on the box is a known footgun. Only viable with strict trigger lockdown; not worth it here. |

### Why B over A and C

- **A** points the arrow the wrong way: it grants GitHub inbound access to a
  production box. Defensible (nologin forwarding-only user, key in Secrets, blast
  radius = free proxy) but the user's instinct to reject it is right.
- **C** is the *least-change* option (the entire `etl.yml` runs unchanged, just on
  the box, and you keep Actions logs/badges/manual-dispatch/issue automation). But
  **this repo is public**, and a self-hosted runner on a public repo can execute
  untrusted fork-PR code on the host unless `pull_request` triggers are locked
  down. Not worth that footgun for a daily data job.
- **B** points the arrow outbound and needs only a token that can write **one
  public repo**. If it leaks, the blast radius is "someone can push to
  dataseries-data" — scoped and recoverable — not a foothold on the box.

## Recommended design (Option B)

**Worker on Hetzner, watcher on GitHub.**

1. **Container image** (the box is already Docker-centric). Base `rocker/r-ver`
   pinned to R 4.5.x; install the 9 CRAN binaries the ETL needs — `arrow, dplyr,
   httr2, jsonlite, readr, readxl, stringr, tibble, tidyr` (from P3M, no
   compilation; no `renv`/DESCRIPTION in this repo). `COPY` the repo in, or
   `git clone` at run time and check out `main`.
2. **Scheduler on the box.** A `systemd` timer (or host cron) fires daily ~08:15
   UTC (mirroring today's cron). It runs a **one-shot** container — *not* a
   long-running service — that does `Rscript R/pipeline.R && R/health.R &&
   R/uptime.R`, then commits `data STATUS.md UPTIME.md README.md` and `git push`.
3. **Credential.** A GitHub **fine-grained PAT or deploy key, write-scoped to
   `cynkra/dataseries-data` only**, stored root-readable on the box. This is the
   single secret, outbound, least-privilege.
4. **Keep on GitHub, unchanged:**
   - `watchdog.yml` — the **independent backstop**. It checks only whether
     `data/uptime.csv` gained a fresh row each day, so it pages us (opens the
     `watchdog` issue) if the Hetzner job ever silently dies — regardless of where
     the ETL runs. This decoupling of *worker* from *watcher* is what makes moving
     the ETL off GitHub safe.
   - The README badge / health board — they render from committed files, so they
     keep working as-is.
5. **Issue alerting (`etl-skip` / `data-health` detail).** Two sub-options:
   - **Re-home:** run `health_issues.sh` + `skip_issues.sh` inside the box job,
     authenticating `gh` with the same scoped token. Keeps per-source detail.
   - **Drop:** rely on the watchdog (freshness) + the health board (green/red).
     Simpler; loses leading per-source skip detail.
   *Decision pending — default to re-home if it's cheap.*

### What physically moves vs stays

- **Moves to Hetzner:** `R/pipeline.R`, `R/health.R`, `R/uptime.R`, dependency
  install, the commit + push.
- **Stays on GitHub:** the repo, `watchdog.yml`, badges/board, (optionally) the
  issue-alert scripts.
- **`etl.yml`:** its cron is disabled once B is live (keep the file so we can flip
  back instantly).

## Honest costs of B

- **R runtime upkeep on the box.** Mitigated by pinning the image; rebuild only
  when a dependency changes (≈ twice a year).
- **Loss of the Actions per-run log UI.** Logs become container logs / `journalctl`
  on the box (read via SSH). Day to day the health board + watchdog give the
  green/red + freshness signal; the logs matter only when something breaks.
- **The box becomes the ETL's execution dependency.** It's already
  production-critical for other services, and the watchdog catches a silent death,
  so this is acceptable — but it is one more job on a shared host.

## Shared-host guardrails (the box runs CKAN/Outline/Kimai/Plane)

- One-shot container on a timer; **bind nothing to public ports** (no Caddy vhost,
  no exposed proxy).
- Never `docker prune` / `docker stop` broadly on this host — it would hit the
  foreign services. Scope any cleanup to this job's own image/containers by name.
- ~3.5 GiB baseline is already in use by the demo services; the ETL container is
  short-lived and light, but size it modestly.

## Rollback

Trivial and non-destructive: re-enable the `etl.yml` schedule (and disable the
box timer). The data contract — commits of `data/` + status files to `main` — is
identical whichever side produces them.

## Open sub-decisions (pick at build time)

1. Issue alerting: **re-home** the two scripts (default) or **drop** them?
2. Image: **pin a prebuilt image** (rebuild on dep change) or **clone + install at
   run time** (always current, slower start)?
3. Stamp the commit author as `dataseries-bot` (matches history) — yes.
