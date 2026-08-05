# AGENTS.md — orientation for AI agents (and new contributors)

**Read this before changing anything.** This repo has a source-of-truth layering
that is easy to get wrong: edit the wrong layer, or hand-edit a generated file, and
you silently corrupt the data product.

## The golden rule: datasheets are the source of truth

`datasets/<id>.md` is the **source of truth** for every dataset — its access recipe
(source URL, table id / order number, parse steps), its dimensions, and its
presentation choices (the `## Display` block: split, single-select, default view,
transform). The `R/` fetchers, `data/*.{csv,json,parquet}`, `catalog.json`,
`CATALOG.md` and `STATUS.md` are all **generated derivatives**.

- **Never hand-edit** `data/*.json`, `data/catalog.json` or `CATALOG.md` — they are
  regenerated and your edit will be overwritten. Edit the datasheet, then regenerate.
- When a **source changes** (URL moved, format changed): update the datasheet's
  `## Access` block first, then the `R/source_*.R` fetcher, then regenerate.
- Full datasheet format + rationale: [`datasets/README.md`](datasets/README.md).

## How to regenerate after an edit

| You changed… | Run | Effect |
|---|---|---|
| A datasheet **curation field** (`concept`, `canonical`, `featured`, `title`, the `## Display` default/split/single-select/transform, a `## Hierarchy` tree, `## What is special`) | `Rscript dev/rebuild_from_datasheets.R` | Re-derives those fields onto the meta sidecars + `catalog.json` + `CATALOG.md` **from disk, no refetch** (~seconds). |
| A **source URL / parser**, or **added/removed a dataset** | `Rscript R/pipeline.R && Rscript R/health.R && Rscript R/uptime.R` | Full refetch + rewrite of `data/`, catalog, health/uptime (~7–15 min). |

After either, `git diff` should show **only your intended change** (plus refreshed
data for a full run). If `rebuild_from_datasheets.R` touches unrelated datasets,
that is a bug in the script — fix it, don't commit the collateral.

## Read the relevant doc before touching an area

- [`datasets/README.md`](datasets/README.md) — datasheet format; the source of truth.
- [`docs/source-quirks.md`](docs/source-quirks.md) — per-source gotchas (e.g. SECO now
  delivers via `scheduler.swissdatas.ch`; FSO's four channels; KOF `sets` endpoint).
- [`docs/format-contract.md`](docs/format-contract.md) — the data + meta contract clients depend on.
- [`docs/concepts.md`](docs/concepts.md) · [`docs/principles.md`](docs/principles.md) — concept tree + curation principles.
- [`dev/etl-reliability-log.md`](dev/etl-reliability-log.md) — ETL incident journal (timeouts, the admin.ch GitHub-runner IP block).

## Running the ETL (operational notes)

- The repo is **public**; the daily GitHub Action is free. The ETL is plain scripts
  (no DESCRIPTION); deps: `arrow dplyr httr2 jsonlite readr readxl stringr tibble tidyr`.
- **admin.ch intermittently IP-blocks GitHub's hosted runners** (BFS/FSO/FFA hosts),
  which cancels the daily run at the 30-min cap. Those hosts are reachable from a
  Swiss/EU IP. If CI is blocked, run the pipeline off-GitHub (a Swiss machine, or the
  Hetzner box) and push. Details + candidate fixes in `dev/etl-reliability-log.md`.

## Commit conventions

- **No `Co-Authored-By` / AI attribution** in commit messages.
- Daily data-refresh commits use the `dataseries-bot` identity; code, datasheet and
  doc changes are authored normally.
