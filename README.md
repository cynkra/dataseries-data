# dataseries-data

[![data health](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/cynkra/dataseries-data/main/data/badge.json)](STATUS.md)

**The dataseries open-data product: source of truth for the Swiss economic data
universe.** This repo holds the ETL that fetches the data, the data files
themselves, the dataset catalog, and the format contract that clients depend on.

It is **not** an R package — `R/` is ETL *scripts*. The installable clients live
elsewhere ([`cynkra/dataseries`](https://github.com/cynkra/dataseries) for R,
`cynkra/dataseries-py` for Python) and consume the files this repo produces.

## Layout

| Path | What |
|---|---|
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

A daily GitHub Action (`.github/workflows/etl.yml`) re-fetches every source, rewrites
`data/` + `catalog.json`, recomputes health/uptime, and commits the result. You can
also run it locally: `Rscript R/pipeline.R && Rscript R/health.R && Rscript R/uptime.R`,
then commit.

## License

Code: MIT (or as set on the repo). Data: per-dataset, see each dataset's `license`
field in its meta / `catalog.json`. Mirrors the upstream sources' terms.

## Monitoring

Two binary metrics are recorded once per day (history in [`data/uptime.csv`](data/uptime.csv),
trend in [UPTIME.md](UPTIME.md)):

- **Run-through** — did the scrape complete with zero skips? A skip (a source failing
  to fetch/parse) is the *leading* signal that a source changed format, and opens an
  `etl-skip` issue immediately.
- **Recently updated** — is every dataset that's expected to update fresh? A dataset
  ageing past its threshold is the *lagging* signal and opens a `data-health` issue.
  The per-dataset board (🟢 fresh / 🔴 stale) lives in [STATUS.md](STATUS.md).

A hard workflow failure opens a rolling `etl-failure` issue.

<!-- DATA-HEALTH:START -->
**ETL uptime** (run 2026-06-07):
- 🟢 **Run-through** — clean (0 skips)
- 🟢 **Recently updated** — 70 of 70 datasets fresh

See [UPTIME.md](UPTIME.md) for the trend and [STATUS.md](STATUS.md) for the per-dataset board.
<!-- DATA-HEALTH:END -->
