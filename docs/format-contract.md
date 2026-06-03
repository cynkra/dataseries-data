# dataseries-next — the file format contract (ETL ↔ website)

_The contract between the Python/Polars ETL (writer) and the static website (reader). If this is right, the website is "just a renderer": read `catalog.json`, then per dataset read `{id}.csv` + `{id}.json`, and you have everything to browse, search, pick series, label axes, and chart — with no server and no extra step. Grounded in the live SECO swissdata file (`ch_seco_gdp_json.txt`), trimmed of R-isms._

## Principles

- **One file per DATASET, not per series.** Whole GDP = `ch_seco_gdp.csv` (long, all components × all dates) + `ch_seco_gdp.json` (meta). Dozens of dataset files, not thousands.
- **Store the complete data** from each source; the website renders a curated view on top of the same files.
- **Three artifact types:** `catalog.json` (repo root, the index), `{id}.csv` (tidy long data), `{id}.json` (metadata).
- **JSON not YAML. UTF-8. ISO dates. `null` for missing. lower_snake field names.** No `.rds`.
- **English required in every label; de/fr/it optional** (omit a language rather than emit a `---` stub).

## 1. `{id}.csv` — the data

Tidy long format. Columns = the dataset's dimension code-columns, then `date`, then `value`.

```csv
structure,type,seas_adj,date,value
gdp,nom,csa,1980-01-01,50870.6180388267
gdp,real,csa,1980-01-01,...
```

- `date`: ISO `YYYY-MM-DD`, first day of the period (monthly → `-01`, quarterly → first month, annual → `-01-01`).
- `value`: number or empty (= missing).
- Dimension columns carry **codes** (e.g. `gdp`, `nom`), not labels. Labels live in the meta. Order of dimension columns matches `dim_order` in the meta.
- A single-series dataset (e.g. KOF Barometer) has zero dimension columns: just `date,value`.

## 2. `{id}.json` — the metadata (what the website needs to render)

```json
{
  "schema_version": "1.0",
  "id": "ch_seco_gdp",
  "title":  { "en": "Gross domestic product", "de": "...", "fr": "...", "it": "..." },
  "source": { "name": { "en": "SECO", "de": "..." }, "url": "https://..." },
  "license": "seco",
  "frequency": "quarterly",
  "updated": "2026-02-23",
  "start": "1980-01-01",
  "end":   "2026-01-01",
  "dim_order": ["structure", "type", "seas_adj"],
  "dimensions": {
    "structure": {
      "label": { "en": "Structure", "de": "..." },
      "levels": {
        "gdp":   { "label": { "en": "GDP", "de": "..." } },
        "agric": { "label": { "en": "Agriculture, forestry and fishing", "de": "..." } }
      },
      "hierarchy": { "gdp": { "prod": { "agric": null }, "exp": null, "inc": null } }
    },
    "type":     { "label": { "en": "Valuation" }, "levels": { "nom": {"label":{"en":"Nominal"}}, "real": {"label":{"en":"Real"}} } },
    "seas_adj": { "label": { "en": "Adjustment" }, "levels": { "csa": {"label":{"en":"Seasonally adjusted"}}, "nsa": {"label":{"en":"Unadjusted"}} } }
  },
  "units": { "nom": { "en": "CHF, current prices" }, "real": { "en": "CHF, chained 2020" } },
  "display": { "split": "structure", "default": ["gdp"] },
  "notes": { "en": "optional free text" }
}
```

Field-by-field (what the website does with each):

| Field | Required | Website use |
|---|---|---|
| `id` | yes | key; matches filenames |
| `title.{lang}` | en | page heading, search |
| `source.name`, `source.url` | yes | attribution line, "data from X" link |
| `license` | yes | license badge; a key into a shared license table (see below) |
| `frequency` | yes | annual/quarterly/monthly/weekly/daily — axis ticks, resampling |
| `updated`, `start`, `end` | yes | "last updated", time-range slider bounds |
| `dim_order` | if dims | maps to the CSV's dimension columns, in order |
| `dimensions.{d}.label` | en | axis/selector group labels |
| `dimensions.{d}.levels.{code}.label` | en | turn a code into a human label on the chart/legend/picker |
| `dimensions.{d}.hierarchy` | optional | build a drill-down tree picker; absent → flat list of levels |
| `units` | recommended | y-axis label; keyed by the unit-bearing dimension's level |
| `display.split` | optional | which dimension becomes the series selector by default |
| `display.default` | optional | which level(s) to show on first load |
| `notes.{lang}` | optional | description blurb |

**Rich vs thin (the maintenance rule):** for **at-source** datasets the owner already ships rich labels/hierarchy (SECO does), keep them. For series **we collect**, fill only the cheap required fields and whatever the source hands us; do NOT hand-author hierarchies/translations we can't keep current. `hierarchy`, `units`, extra languages are all optional by design.

**Declared hierarchies (the sanctioned exception):** a datasheet may add a `## Hierarchy` block when the source ships a dimension *flat that genuinely nests* — but only against a **stable, citable definition**, never a guess (see *Hierarchies: real containment only* in [`principles.md`](principles.md)). The pipeline (`R/hierarchy.R`, run after the datasheet merge) reads the block and writes `dimensions.{d}.hierarchy`. Grammar, under `## Hierarchy`:
- an indented bullet tree (2 spaces per level); a bare code references an existing level; `@code: Label` declares a synthetic grouping header (`data: false`); an optional `dim: <name>` targets a non-split dimension. A declared tree **overrides** a flat/wrong source hierarchy; codes omitted from the tree are appended as top-level leaves so nothing vanishes.
- or a single `- derive: <method>` line: `noga-range` (nest FSO NOGA range codes 5-96 ⊃ 5-43 ⊃ … by containment) or `under-root <CODE>` (reparent a flat-topped dimension under its total, e.g. the SNB goods cube under `GT`).
- a `## Hierarchy` block with neither a tree nor a `derive:` is documentation only (e.g. CPI, whose tree is reconstructed in the parser from the FSO `Level` column) and leaves any source hierarchy intact.

## 3. `catalog.json` — the index (repo root)

One array, one entry per dataset. This is all the homepage/search needs without opening any dataset.

```json
[
  {
    "id": "ch_seco_gdp",
    "title": { "en": "Gross domestic product", "de": "..." },
    "topic": "national-accounts",
    "source": "SECO",
    "license": "seco",
    "frequency": "quarterly",
    "start": "1980-01-01",
    "end": "2026-01-01",
    "n_series": 50,
    "updated": "2026-02-23",
    "data": "ch_seco_gdp.csv",
    "meta": "ch_seco_gdp.json"
  }
]
```

`n_series` = number of distinct dimension-combinations in the CSV (so the site can say "50 series"). `topic` = a controlled vocabulary for grouping (national-accounts, prices, labour, money, rates, sentiment, trade, tourism, construction, …).

Add a **`load` hint** per dataset so the website knows how to fetch it (see website-concept doc): `"whole"` (default — download the whole CSV, instant client-side interaction), `"sliced"` (fetch only the needed slice file — for high-cardinality cubes pre-split at ETL time), or `"parquet"` (query a Parquet via DuckDB-WASM). Threshold for non-`whole`: gzipped size over ~2 MB. Most datasets are `whole`.

## 4. Shared `licenses.json` (repo root, optional but recommended)

So the `license` key resolves to display text + terms:
```json
{
  "seco": { "name": "SECO open data", "url": "...", "commercial": "ask", "attribution": true },
  "snb":  { "name": "SNB", "url": "...", "commercial": "no", "attribution": true },
  "kof":  { "name": "CC BY 4.0", "url": "...", "commercial": "yes", "attribution": true },
  "fso":  { "name": "FSO / opendata.swiss", "url": "...", "commercial": "yes", "attribution": true }
}
```

## Open points to confirm against real output (the tracer bullet will surface these)

- Does the SNB dimensions endpoint give a clean code→label map and any hierarchy, or just flat dims? (affects how much `dimensions`/`hierarchy` we can fill for SNB datasets)
- FSO JSON-stat → does its `dimension.category.label` map cleanly into our `dimensions.levels.label`? German dimension codes — keep as codes, put German text in `label.de`, English in `label.en` where available.
- Unit handling: SNB packs unit as one string ("In CHF millions / In percent"); SECO keys units by dimension level. Confirm a single `units` shape covers both.
- Do we need a per-observation `status`/flag column in the CSV (estimated/provisional)? Defer unless a source forces it.

## Storage & formats (what is the source of truth)

Three artifacts per dataset, but only two are authoritative:

- **`{id}.csv` — source of truth, committed.** The readable data product. Committed
  to git, so each revision diffs and the change history is free.
- **`{id}.json` — source of truth, committed.** The metadata sidecar, committed
  alongside the CSV.
- **`{id}.parquet` — DERIVED query cache, NOT committed.** Built from the CSV at
  deploy / sync time for the DuckDB serving layer. A derivative, never the source of
  truth, never committed.

See [`principles.md`](principles.md) for the full curation rationale.
