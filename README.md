# dataseries-data

[![pipeline](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/cynkra/dataseries-data/main/data/badge-pipeline.json)](UPTIME.md)
[![upstream](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/cynkra/dataseries-data/main/data/badge-upstream.json)](UPTIME.md#current-run-through)
[![data freshness](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/cynkra/dataseries-data/main/data/badge-fresh.json)](STATUS.md)

_**pipeline** = did our ETL run · **upstream** = did the sources deliver (a red here is usually a provider outage — nothing to do, [see the run](UPTIME.md#current-run-through)) · **freshness** = is the data current_

**The dataseries open-data product: source of truth for the Swiss economic data
universe.** This repo holds the ETL that fetches the data, the data files
themselves, the dataset catalog, and the format contract that clients depend on.

It is **not** an R package — `R/` is ETL *scripts*. The installable clients live
elsewhere ([`cynkra/dataseries`](https://github.com/cynkra/dataseries) for R,
`cynkra/dataseries-py` for Python) and consume the files this repo produces.

> **Editing this repo (human or AI)?** Read **[AGENTS.md](AGENTS.md)** first.
> `datasets/<id>.md` datasheets are the source of truth; almost everything in `data/`
> and `catalog.json` is **generated** — edit the datasheet and regenerate, don't
> hand-edit the outputs.

## Layout

| Path | What |
|---|---|
| `AGENTS.md` | **read first** (human or AI) — source-of-truth layering + how to regenerate after an edit |
| `R/` | ETL fetchers (one per source: SNB, KOF, SECO, FSO) + writer + catalog builder |
| `data/` | the data product — one `*.csv` + `*.json` (meta) + `*.parquet` per dataset, plus `catalog.json` |
| `datasets/` | per-dataset datasheets (concept-first source of truth, Markdown) |
| `docs/format-contract.md` | the swissdata-style data + meta contract that clients read against |
| `docs/deferred-datasets.md` | datasets we considered but did **not** ingest, and the concrete reason (read before re-hunting a missing series) |
| `STATUS.md` | per-dataset freshness board (🟢/🔴 per dataset) |
| `UPTIME.md` | the two daily ETL metrics — run-through success + recently-updated — with the uptime trend (`data/uptime.csv` + `data/uptime.svg`) |

## The contract (what clients can rely on)

- **One file per dataset**, not per series. Data = tidy long CSV
  (`<dim cols…>, date, value`, ISO `YYYY-MM-DD`). Meta = JSON sidecar
  (multilingual title/source, units, hierarchy, `updated`, license). See
  `docs/format-contract.md`.
- **`catalog.json`** lists every dataset with id, title, source, license,
  frequency, time span, last-updated. This is the index clients/the site read.
- **Latest only** (no vintage in v1). Per-dataset **license** field
  (SNB = non-commercial+attribution; KOF = CC BY; FSO = free+attribution).

## How it's consumed

- **The API** (`cynkra/dataseries.org`) reads `data/` read-only (DuckDB over the
  Parquet) via its `DS_DATA_DIR` env var. In production the Hetzner host
  shallow-pulls this repo into a volume the API container mounts.
- **The clients** fetch the raw files / `catalog.json` from this repo's raw URL
  (or via the API).

## Updating the data

**Datasheets are the source of truth** (`datasets/<id>.md`); `data/` + `catalog.json`
are generated. Two regeneration paths (full detail in [AGENTS.md](AGENTS.md)):

- **Edited a datasheet curation field** (concept, title, the `## Display`
  default/split/single-select/transform): `Rscript dev/rebuild_from_datasheets.R` —
  re-derives the meta sidecars + `catalog.json` + `CATALOG.md` from disk, **no refetch**.
- **Changed a source/parser, or the data itself**: `Rscript R/pipeline.R && Rscript
  R/health.R && Rscript R/uptime.R`, then commit — this is what the daily GitHub Action
  (`.github/workflows/etl.yml`) runs.

## License

Code: MIT (or as set on the repo). Data: per-dataset, see each dataset's `license`
field in its meta / `catalog.json`. Mirrors the upstream sources' terms.

## Monitoring

Three binary metrics are recorded once per day (history in [`data/uptime.csv`](data/uptime.csv),
trend in [UPTIME.md](UPTIME.md)), one badge each at the top of this README. They answer
three different questions — *did our automation run*, *did the sources deliver*, *is the
data current* — so a provider outage reddens only the middle one:

- **Pipeline** — did **our** ETL run to completion? Green whenever a run finishes (it
  fetched what it could, kept previous data on a skip, committed, reported); red only when a
  run cancels or crashes (caught by the independent `watchdog`). This is the headline: it
  **stays green through any upstream outage or IP block**, because that's not our automation
  failing.
- **Run-through (upstream)** — did *every source* fetch cleanly this run? Red on **any**
  skip — a provider 503 and an admin.ch runner-IP block both mean "we didn't get fresh data
  this run." A morning skip is re-fetched the same day by **two** fresh-IP retry passes —
  lunch and afternoon (`.github/workflows/etl-retry.yml`) — the main defence against admin.ch
  intermittently blocking a subset of runner IPs (see
  [`dev/etl-reliability-log.md`](dev/etl-reliability-log.md)). **Most red here needs no
  action** — it's the provider's outage, shown on the dashboard but not filed as an issue.
  A skip only becomes an issue when: it's a **network/provider error that persists ≥ 3 days**
  (then one grouped `etl-outage` issue opens), or it's an **actionable break** — a 4xx or a
  parse error, meaning the source changed and *our* parser must adapt (a per-source
  `etl-skip` issue opens immediately). Retry usage is logged in
  [`data/retry.csv`](data/retry.csv).
- **Recently updated** — is every dataset that's expected to update fresh? A dataset
  ageing past its threshold is the *lagging* signal and opens a `data-health` issue.
  The per-dataset board (🟢 fresh / 🔴 stale) lives in [STATUS.md](STATUS.md).

A hard workflow failure opens a rolling `etl-failure` issue.

<!-- DATA-HEALTH:START -->
**ETL health** (run 2026-06-25):
- 🟢 **Pipeline** — our ETL ran to completion
- 🟢 **Run-through (upstream)** — all sources fetched
- 🟢 **Recently updated** — 70 of 70 datasets fresh

See [UPTIME.md](UPTIME.md) for the trend and [STATUS.md](STATUS.md) for the per-dataset board.
<!-- DATA-HEALTH:END -->
