# Source quirks

Per-source data quirks worth knowing when writing or refining the fetchers.
Several were learned the hard way by the **old swissdata repo**; read that code
only for these factual quirks, not as a design or code-quality reference. Our
pipeline (Python/Polars → tidy long CSV + JSON meta + `catalog.json`) is the
canonical approach.

## SNB (cube API)
- **Redundant TOTAL rows.** Cubes carry hierarchy-parent / total rows (e.g.
  `D1 == "T0"`, and `TMA`/`TTR`/`TFIIN` parents). If kept, they inflate
  `n_series` and double-count. Filter total/parent codes out of the data (or
  flag them explicitly).
- **Labels can be weak — keep an override hook.** The old swissdata repo had to
  hand-override `D0` labels for flagship series. In the 2026 pull the API
  returns usable `D0` labels, but keep an override hook in case it regresses.
- **Rename opaque dim columns.** Cubes arrive with opaque `D0`/`D1` headers. The
  JSON meta carries the dimension label so the website can resolve it, but a
  downloaded CSV has meaningless headers — rename to semantic names from the
  dimension `name`.
- **Shape matches the swissdata format**, so the SNB approach is sound.
- **Discontinued cubes go stale silently.** The cube still serves data, just frozen.
  `rendoblid` (daily bond par yields) stopped at 2025-07-31 (last published 2025-09-01);
  the live bond-yield series is the spot cube `rendeiduebd` (canonical). Check the live
  CSV `PublishingDate` header before trusting a cube as current.

## FSO

### FSO publishes the same data through FOUR channels — know them, don't tunnel on one

The single most re-discovered (and re-lost) fact about FSO. A series missing from
one channel does **not** mean it's unavailable — check the others. Roughly ordered
by how clean they are to ingest:

1. **SDMX** — `https://disseminate.stats.swiss/rest/`. The cleanest machine channel,
   already used by `R/source_fso_sdmx.R` for retail/production. **Discover everything**
   in one call: `GET /rest/dataflow/all/all/latest` (Accept:
   `application/vnd.sdmx.structure+json`) → ~182 dataflows with ids, agencies, English
   names. Pull data via `GET /rest/data/{agency},{flow},{version}/all` (Accept:
   `application/vnd.sdmx.data+csv`). **Caveat:** many cubes are huge (full
   canton×attribute key → tens of MB / millions of rows) — slice to the national
   total key, same idea as `noga_keep`. Confirmed live flows for the long-deferred
   "real-economy" set:
   - **New vehicle registrations** → agency `CH1.MFZ_IVS`, flow `DF_IVS_0_GENERAL_M`
     (monthly) / `DF_IVS_0_GENERAL` (annual). Dims: geography, owner type,
     registration type, vehicle group/type, fuel. Slice to Switzerland total.
   - **Vacant dwellings (Leerwohnungsziffer)** → agency `CH1.LWZ`, flow `DF_LWZ_1`.
     ~2.5M rows at municipality level — slice to national total + total rooms/type.
2. **DAM Excel assets** — `https://dam-api.bfs.admin.ch/hub/api/dam/assets/{id}/master`,
   addressed by **order number** (`je-d-XX.XX.XX.XX`) via
   `R/source_fso_excel.R::fso_excel_download`. Already used for CPI, wages, population.
   Each asset is a bespoke sheet layout.
   - **Construction investment (Bauinvestitionen)** → order `je-d-09.04.01.27`. It's a
     multi-sheet snapshot (one sheet per year, methodology break 2012-2013), so a
     continuous series needs stitching the "Total" row across sheets.
3. **opendata.swiss / CKAN** — `https://opendata.swiss/api/3/action/package_search?q=…`
   and `…/package_show?id=…`. **Requires a browser `User-Agent`** (else 403/302; see
   `R/source_ffa.R::.ffa_get`). Best as a **discovery index**: each BFS dataset's
   resources expose the DAM order number (HTML resource `…/asset/de/je-d-…`) or the
   SDMX/STAT-TAB link (`SERVICE` resource). For many BFS series the only data resource
   here is `SERVICE` → STAT-TAB, so fall back to channel 1 or 2.
4. **PX-Web / STAT-TAB** — `https://www.pxweb.bfs.admin.ch/`. `R/source_fso.R::fso_fetch_auto`
   speaks the JSON-stat2 API at `/api/v1/en/{id}/{id}.px` and serves the cubes we
   already ship (besta, hesta, jobs_sex, vacancies). **But the newer STAT-TAB instance
   is unreachable from our build env** (`/pxweb/…` → 400/404/500; `/api/v1/en/` nav
   lists ~673 ids that almost all 400 — stale, not a discovery tool). Old (2019)
   `mbannert` cube ids are retired. **Don't** sink time here for a cube that 400s — go
   to channel 1 (SDMX). The data is there.

### A fifth FSO channel: DAM masters that are already long CSVs
Some DAM "cube" assets ship their master as a tidy, SDMX-style **long CSV** (one row
per observation), not the row/column spreadsheets that need bespoke reshaping. For
those, skip the sheet-parser machinery: resolve with `fso_asset_master(order)`,
`download_binary` to a `.csv` tempfile, `read.csv(fileEncoding="UTF-8-BOM")` (they carry
a BOM). `R/source_fso_dam_csv.R` holds these (`ch_fso_labour_productivity`, `ch_fso_ets`,
`ch_fso_gfcf_detail`, `ch_fso_hours_worked`). Watch for a unit column carrying both
levels and %-change leaves on the same key (`ch_fso_gfcf_detail`: filter `UNIT_MEAS==MCHF`)
— they break (dims,date) uniqueness otherwise.

### Other FSO notes
- We read FSO PX-Web via the **JSON-stat2 API** (clean, no extra dependency) rather
  than the old swissdata repo's binary `.px` + R `pxR` route. JSON-stat2 parses
  cleanly and year+month recombine into one ISO first-of-period date.
- **Drop single-value dimension columns.** A dimension filtered to one value
  (e.g. `Indikator`) adds a constant, noise-only column.
- **German dimension codes as headers** (e.g. `Tourismusregion`): decide whether
  to keep the code or map to a semantic english slug. Labels are already in the
  meta either way.

## Meta gaps to fill where the source allows
- **`updated`** — capture the source publish date (SNB `PublishingDate` in the
  CSV header; KOF and FSO carry their own).
- **`units`** — missing for SNB (packed oddly) and FSO; extract where available.
- **`topic`** — populate from a controlled per-dataset vocabulary.

## Cross-source
- Date normalization spans dialects: SNB `1990-Q1` → `1990-04-01`, monthly
  `1991-01` → `1991-01-01`, all ISO first-of-period.
- A single-series source (e.g. KOF) yields zero dimension columns — just
  `date,value`. That is correct, not a bug.

## Non-FSO open channels
- **KOF — use the `sets` endpoint, not per-key `ts`.** `…/api/v1/public/ts?keys=` gates
  most keys behind HTTP 412 (only `ch.kof.barometer` serves), but `…/api/v1/public/sets/<set>?mime=csv`
  is open for the curated OGD sets (`ogd_ch.kof.esi`, `ogd_ch.kof.globalbaro`,
  `ogd_ch.kof.bts_total`, …). `R/source_kof.R::kof_set_fetch` reads them (wide+sparse →
  pivot long + drop NA). The COVID-era **weekly WBI is genuinely discontinued** (not gated).
- **Eurostat (SDMX 2.1)** for EU-harmonised series with no clean Swiss-domain source
  (e.g. HICP). `ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/<flow>/<key>/?format=SDMX-CSV`,
  `geo=CH`. Separate host/module from FSO SDMX → `R/source_eurostat.R`. Provenance must
  say Eurostat, not FSO.
- **BAZG Swiss-Impex monthly trade (by tariff × country, since 1988)** is the richer
  upgrade path for `ch_fso_trade_partner`, but its OGD ZIP/CSV endpoints **502'd from this
  build env** on every retry — annual FSO Excel (English assets) was used instead. Retry
  the BAZG monthly channel later; if it works it supersedes the annual cut.
