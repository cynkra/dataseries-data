# dataseries-data

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

Run the ETL (R) to refresh `data/` from source, then commit. Automation
(GitHub Actions on a cron matched to each source's release calendar) is planned
but deferred — for now the ETL runs locally and the result is committed here.

## License

Code: MIT (or as set on the repo). Data: per-dataset, see each dataset's `license`
field in its meta / `catalog.json`. Mirrors the upstream sources' terms.

## Data health

<!-- DATA-HEALTH:START -->
**Data health** (updated 2026-06-01): 🟢 50 · 🟡 0 · 🔴 0 · ⚪ 0 of 50 datasets — see [STATUS.md](STATUS.md).
<!-- DATA-HEALTH:END -->
