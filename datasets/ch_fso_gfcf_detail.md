# Gross fixed capital formation by institutional sector and asset type

- **id**: ch_fso_gfcf_detail
- **title**: Investment (GFCF) detail
- **concept**: National accounts / Investment (gross fixed capital formation)
- **canonical**: no (headline total-economy GFCF is in `ch_seco_gdp` as part of the GDP expenditure breakdown; this is the institutional-sector × asset-type detail)
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 1995 .. 2024
- **series**: 37

## What is special
Gross fixed capital formation (investment) broken down by **institutional sector**
(total economy, non-financial / financial corporations, general government,
households, NPISH, …) **and asset type** (construction vs equipment/software, with
construction split into building vs civil engineering), in CHF-million current
prices, annual 1995–2024. Non-duplicative with `ch_seco_gdp`, which carries only the
single total-economy GFCF aggregate inside the GDP expenditure split — this is the
who-invests-in-what cut underneath it (e.g. how much of total investment is
government civil-engineering vs corporate equipment).

## Access
- **type**: FSO DAM asset, master is a long CSV (not xlsx)
- **order**: `ts-x-04.02.05.02` (asset 36182144)
- **codelist appendix** (level labels, ODS): `https://dam-api.bfs.admin.ch/hub/api/dam/assets/36182144/appendix` — EN labels are transcribed into the parser (file labels are FR/DE/IT only).
- **call**: `fso_gfcf_detail("ch_fso_gfcf_detail")`

## Parsing recipe
- `fso_dam_csv_download("ts-x-04.02.05.02")` resolves + downloads the CSV master;
  read with `fileEncoding = "UTF-8-BOM"` (the file carries a BOM).
- Columns `SECTOR, PERIOD, CLASSIFICATION, UNIT_MEAS, VALUE, STATUS`.
- **Filter `UNIT_MEAS == "MCHF"`** (CHF-million levels). The file also carries `AC`
  (% change at current prices) and `ACPP` (% change at previous-year prices) leaves
  on the *same* `(SECTOR, CLASSIFICATION, PERIOD)` key — keeping them triple-counts
  every observation and breaks (dims, date) uniqueness. The app reproduces %-change
  from the level via its transform toggle.
- Dims: `sector` ← `SECTOR`, `asset` ← `CLASSIFICATION`. `PERIOD` (year) →
  first-of-year ISO date. Drop NA values.

## Dimensions
- `sector`: `S1` total economy (the default), `S11` non-financial corporations,
  `S12` financial corporations, `S121T127` financial institutions (excl. S128/S129),
  `S12Q` insurance & pension funds, `S13` general government, `S1314` social-security
  funds, `S14` households, `S15` NPISH. Every sector carries the full asset
  breakdown (construction / building / civil engineering / equipment).
- `asset`: `P51G` gross fixed capital formation total, `P5111_N111_112G` construction,
  `P5111_N113T117G` equipment / fixed assets & software, with construction split into
  `6011` building construction and `6010` civil engineering. Hierarchy:
  P51G → {Construction → (Building, Civil engineering), Equipment}.
  `P51G` (the grand total) is present only for `S1` in the source; the breakdown
  assets (construction, building, civil engineering, equipment) exist for all 9 sectors.

## Display
- **split**: sector
- **single-select**:
- **default**: sector=S1, asset=P5111_N111_112G
- **transform**: level
- **seasonal adjustment**: n/a (annual)

The split is the **sector** (9 institutional-sector lines), driven by a single-select
**asset** picker. This is the clean rectangle: every sector carries the construction /
building / civil-engineering / equipment breakdown, so selecting any of those four
assets draws all 9 sector lines fully populated — no dead cells. The default opens on
the construction breakdown (`P5111_N111_112G`), populated for all 9 sectors. The only
ragged level is the grand total `P51G`, which the source publishes for the total
economy `S1` only; selecting it draws the single S1 headline line (correct for a
total-economy aggregate), and it is flagged data-bearing via S1. The earlier
split=asset / single-select=sector layout was ragged: picking any of the 8 sub-sectors
together with `P51G` produced an empty (dead) chart, since sub-sectors have no grand
total. Swapping the roles removes those 8 dead cells.

## Caveats / simplifications
- **Current prices, levels only.** The source's %-change variants (`AC`, `ACPP`) are
  dropped; the app reconstructs %-change via its transform toggle, but real (volume)
  levels are not provided here.
- The grand total `P51G` exists only for the total economy `S1`; the per-sector rows
  carry the asset breakdowns (construction / building / civil engineering / equipment)
  but not a sector `P51G` total. With split=sector / single-select=asset this is not a
  dead cell: selecting `P51G` simply draws the single S1 line, the headline total.
- Asset codes mix two coding schemes (ESA `P51*` plus FSO `601x` construction
  sub-codes); EN labels are authored from the codelist appendix.

## Provenance
Script: `R/source_fso_dam_csv.R::fso_gfcf_detail` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-03 (S1 P51G 2024 = 225,873.1 and S1 construction 2023 = 66,634.8, exact matches to FSO).
