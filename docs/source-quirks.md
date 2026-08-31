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
  the live bond-yield series is the spot cube `rendeiduebd` (canonical). Check the cube's
  `lastUpdate` (see next point) before trusting a cube as current.
- **Conditional fetch via `lastUpdate` (implemented).** SNB documents a freshness
  method exactly for "find out if there are new data" (https://data.snb.ch/en/help_api):
  `GET /api/cube/{id}/lastUpdate` returns a ~65-byte
  `{"editionDate":"YYYYMMDD_HHMM","publicSinceDate":"…"}` — vs the 0.2–1.1 MB data cube.
  `R/source_snb.R::snb_last_update()` reads `editionDate`, formats it `YYYY-MM-DD HH:MM`,
  and stores it as meta `updated`. The pipeline (`.try_fetch_if_unchanged`) compares it to
  the on-disk `updated` and, when unchanged, serves the cube from disk — skipping the
  download + parse (most days, for monthly/quarterly cubes). A failed/missing probe
  degrades to an unconditional fetch, so it never blocks a refresh. (SNB also honors
  `ETag`/`If-None-Match` → 304 on the data endpoint, but `lastUpdate` is preferred since
  its date doubles as `updated`. `Range` and `If-Modified-Since` are NOT honored.)

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

### The PX cubes are also DAM assets (`.px` masters)

Every STAT-TAB cube is *also* a DAM asset, with the table id as its `orderNr` and
the native `.px` file as its master. `R/source_fso_px.R::fso_px_fetch()` reads
that instead of the json-stat API. Measured against the production route
(`dev/compare_px_vs_pxweb.R`, 2026-08-30):

- **2 requests instead of 7-18.** No 5000-cell cap, so no hand-written query, no
  `chunk_by`/`chunk_size`, and no three extra GETs for de/fr/it labels.
- **Full precision.** The `.px` header carries `DECIMALS 4` and `SHOWDECIMALS 0`;
  the API serves the *shown* value, so everything we stored was rounded.
- **`LAST-UPDATED`**, which the json-stat API does not expose — the reason five
  datasheets say the publication date is "not published".
- **Correct French.** PX-Web's json-stat emits latin1 bytes tagged as UTF-8, so
  the typographic apostrophe in NOGA labels lands in `data/*.json` as a raw
  `\x92` (`d\x92automobiles`). 20 such bytes across three datasets today. The
  `.px` route decodes latin1 explicitly and gets `d’automobiles`.

Three gotchas:

- **The declared encoding is a lie, in both directions.** Every cube says
  `CHARSET="ANSI"; CODEPAGE="iso-8859-15"`. Some are single-byte but carry CP1252
  C1 bytes (`0x92`, the right single quote, undefined in 8859-1 and -15); others
  are plain UTF-8. Sniff, do not trust the header: valid UTF-8 with a multi-byte
  sequence means UTF-8, otherwise CP1252. 8 of 24 sampled cubes carry C1 bytes,
  2 of 15 are UTF-8.

- **`ELIMINATION` is implicit in PX-Web, explicit here.** A dimension a PX-Web
  query does not mention is silently collapsed to its `ELIMINATION` level. The
  `.px` is the whole cube, so that collapse must be asked for
  (`eliminate = "Herkunftsland"` for hesta; without it the cube is 69x bigger).
- **`lifecycleGroup=NON_CURRENT`** lists ~40 archived versions per cube, newest
  first. Useful when FSO breaks a CURRENT master, but those are earlier
  *vintages*: the newest archived besta differs from today's data in every cell
  after 2018Q2 (median 0.32%, p95 2.8%), which is the revision window, not a
  parse error.

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
- **A DAM asset's observation frequency is not its publication cadence — read
  `description.categorization.periodicity`.** Several FSO workbooks carry monthly
  values but are republished quarterly (a whole quarter at once). `je-d-03.03.01.03`
  (ILO unemployment rate) declares `QUARTERLY`, and its newest month is normally
  ~5.5 months old just before the next release — enough to trip the *monthly*
  staleness line in `R/health.R`. When a dataset goes red, check `periodicity` and
  `bfs.embargo` on its order number before assuming the scraper broke:
  `curl -s "https://dam-api.bfs.admin.ch/hub/api/dam/assets?orderNr=<ordernr>"`.
  A cadence mismatch belongs in health.R's `OVERRIDE`, not in the `frequency` label.

## Meta gaps to fill where the source allows
- **`updated`** — capture the source publish date. SNB: **done** via the `lastUpdate`
  method (see the SNB section above) — also drives conditional fetch. KOF and FSO carry
  their own publish dates (FSO Excel already returns a `pubdate`); wire those next if we
  extend conditional fetch beyond SNB.
- **`units`** — missing for SNB (packed oddly) and FSO; extract where available.
- **`topic`** — populate from a controlled per-dataset vocabulary.

## Cross-source
- Date normalization spans dialects: SNB `1990-Q1` → `1990-04-01`, monthly
  `1991-01` → `1991-01-01`, all ISO first-of-period.
- A single-series source (e.g. KOF) yields zero dimension columns — just
  `date,value`. That is correct, not a bug.

## Non-FSO open channels
- **KOF — API v1 is DEAD; we are on the Time Series Database API v2** (base
  `https://tsdb-api.kof.ethz.ch/v2`, docs `https://data.kof.ethz.ch/#tsdb-api`,
  swagger at `/v2/docs`). Every `datenservice.kof.ethz.ch/api/v1/…` path now answers
  `301` with a JSON "migrate to v2" body; that killed `ch_kof_barometer` +
  `ch_kof_esi` in the 2026-07 runs. Migration (2026-07-30), response shapes unchanged:
  | v1 | v2 |
  |---|---|
  | `…/api/v1/public/ts?keys=K&mime=csv` | `…/v2/ts?keys=K&mime=csv&access_type=public` |
  | `…/api/v1/public/sets/<set>?mime=csv` | `…/v2/collections/public/<set>/ts?mime=csv&access_type=public` |
  | `…/api/v1/public/metadata?keys=K` | `…/v2/ts/metadata?keys=K&locale=en` |
  - **`access_type=public` is the anonymous switch.** Omit it and the API 302s to
    KOF's Keycloak login instead of serving data — there is no separate `/public/`
    path segment any more. The v1 `apikey=` query param is gone too (v2 wants an
    `x-api-key` header), but we need no key for the public series.
  - "sets" are now **collections**, owned by the `public` user; the ids are unchanged
    (`ogd_ch.kof.esi`, `ogd_ch.kof.globalbaro`, `ogd_ch.kof.bts_total`, …), and
    `R/source_kof.R::kof_set_fetch` still reads them wide+sparse → pivot long + drop NA.
  - The v1 **HTTP 412 gate on per-key `ts` is gone** — under v2 any public key serves
    directly (verified `ch.kof.globalbaro.coincident`, `ch.kof.esi.index`). Collections
    remain the convenient route for whole families.
  - The R client `kofdata` is discontinued along with v1; KOF's replacement is
    [`tsdbapi`](https://github.com/KOF-ch/tsdbapi-R) (we call the API directly).
  - The COVID-era **weekly WBI is genuinely discontinued** (not gated).
- **Eurostat (SDMX 2.1)** for EU-harmonised series with no clean Swiss-domain source
  (e.g. HICP). `ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/<flow>/<key>/?format=SDMX-CSV`,
  `geo=CH`. Separate host/module from FSO SDMX → `R/source_eurostat.R`. Provenance must
  say Eurostat, not FSO.
- **BAZG Swiss-Impex monthly trade (by tariff × country, since 1988)** is the richer
  upgrade path for `ch_fso_trade_partner`, but its OGD ZIP/CSV endpoints **502'd from this
  build env** on every retry — annual FSO Excel (English assets) was used instead. Retry
  the BAZG monthly channel later; if it works it supersedes the annual cut.

## SECO
- **SECO publishes in the swissdata format natively** — a tidy long CSV
  (`structure,type,seas_adj,date,value`) plus a JSON meta sidecar with full en/de/fr/it
  labels and a hierarchy. So the SECO fetchers are passthroughs, not scrapes
  (`R/source_seco.R::seco_fetch` for GDP + consumer sentiment; `seco_wwa_fetch` for the
  WEA index, whose two series + units are stable so its dimensions are hand-built).
- **2026-06 delivery migration — the old `www.seco.admin.ch/dam/...download` URLs are
  RETIRED (they now 502 permanently — not an outage).** SECO rebuilt its website (new
  short pages `seco.admin.ch/{gross-domestic-product,consumer-sentiment,wea}`) and now
  delivers the machine-readable files through **`scheduler.swissdatas.ch`**, linked from
  those pages. Current endpoints:
  - GDP: `scheduler.swissdatas.ch/scheduled/ch-seco-gdp.csv` + `…/ch-seco-gdp.json`
  - Consumer sentiment (`ch_seco_concon`, long quarterly since 1972): `…/ks-q.csv` +
    `…/ch-seco-ks-q.json`. SECO also serves monthly `ks-m` and experimental `ks-exp-m`;
    we take the quarterly.
  - WEA / weekly activity: `…/wwa.csv` + `…/ch-seco-wwa.json` — note the CSV kept the bare
    `wwa.csv` name while the JSON is `ch-seco-wwa.json` (the slugs are NOT uniform).
- **If a SECO source 502s again, check the `scheduler.swissdatas.ch` link on the new SECO
  page before assuming an outage** — and watch for other `*.admin.ch` agencies moving to
  the same swissdata delivery. The `source_url` inside each JSON points back to the SECO
  topic page, which is what lands in the catalog.
