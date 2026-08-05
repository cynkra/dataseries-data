# Employed persons by economic sector and sex (ETS)

- **id**: ch_fso_ets
- **title**: Employed persons (ETS)
- **concept**: Labour / Employment / employed persons
- **canonical**: no (alternate / sector-and-sex breakdown of the employment concept; `ch_fso_besta` is the headline)
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1991-04 .. 2025-10
- **series**: 69
- **updated**: 2026-03-17

## What is special
The Employment Statistics (ETS) headcount of **employed persons on the domestic
concept (Inlandkonzept)**, quarterly averages back to 1991, cut by economic
sector and sex. Where BESTA tracks *jobs* by fine NOGA division, ETS tracks
*persons* and exposes the full sector tree on one axis: total `P`, the three
economic sectors (`P_1` agriculture, `P_2` industry & construction, `P_3`
services), and 18 NOGA-2008 sections beneath them. Crossing 23 sector codes with
three sexes (total / men / women) gives 69 series on a single headcount scale, so
the male/female split of any sector reads straight off the chart.

## Access
- **type**: fso-dam-csv — FSO DAM asset, master is a long CSV (not xlsx)
- **order number**: `ts-x-03.02.01.08` (asset 36461448)
- **call**: `fso_ets("ch_fso_ets")`

## Parsing recipe
- `fso_dam_csv_download("ts-x-03.02.01.08")` resolves + downloads the CSV master;
  read with `fileEncoding = "UTF-8-BOM"` (the file carries a BOM).
- Columns `INDICATORS_HRCHY, INDICATORS_FR/DE, GENDER_FR/DE, DETAILS_FR/DE,
  PERIOD, FREQ, MEASURE_FR/DE, VALUE, STATUS`.
- **Filter `FREQ == "Q"`** to keep quarterly averages and drop the annual `A`/`Y`
  rows (those repeat the year as one observation and would double-count).
- Sector dimension is keyed on `INDICATORS_HRCHY` (`P`, `P_1..P_3`, `P_x_y`); the
  NOGA section letter is in `DETAILS_DE` (`A`, `B-F`, `G-T`, single letters) and
  drives the authored EN labels. Sex is recoded from `GENDER_DE`
  (`Total`/`Männer`/`Frauen` → `total`/`male`/`female`).
- `PERIOD` is `YYYY-Qn`; `to_iso()` maps it to a first-of-quarter ISO `date`
  (Q1→01-01, Q2→04-01, Q3→07-01, Q4→10-01).
- NA `VALUE` rows are dropped (the 1991-Q1 quarter is all NA, so the series start
  at 1991-Q2).

## Dimensions
- `sector` (Economic sector, hierarchical): `P` Total → `P_1` Sector 1
  (agriculture) / `P_2` Sector 2 (industry & construction) / `P_3` Sector 3
  (services); leaves are the NOGA-2008 sections (`P_1_1` A; `P_2_1` B-C, `P_2_2`
  D, `P_2_3` E, `P_2_4` F; `P_3_1` G … `P_3_14` T). 23 codes.
- `sex` (Sex): `total` Total, `male` Men, `female` Women.

## Labels
- **units**: Number of employed persons (domestic concept, quarterly average)
- dim: sector
  - **label**: Economic sector
  - P: Total
  - P_1: Sector 1: Agriculture, forestry and fishing
  - P_1_1: A Agriculture, forestry and fishing
  - P_2: Sector 2: Industry and construction
  - P_2_1: B-C Mining, quarrying and manufacturing
  - P_2_2: D Electricity, gas, steam and air conditioning supply
  - P_2_3: E Water supply; sewerage, waste management and remediation
  - P_2_4: F Construction
  - P_3: Sector 3: Services
  - P_3_1: G Wholesale and retail trade; repair of motor vehicles
  - P_3_2: H Transportation and storage
  - P_3_3: I Accommodation and food service activities
  - P_3_4: J Information and communication
  - P_3_5: K Financial and insurance activities
  - P_3_6: L Real estate activities
  - P_3_7: M Professional, scientific and technical activities
  - P_3_8: N Administrative and support service activities
  - P_3_9: O Public administration and defence; compulsory social security
  - P_3_10: P Education
  - P_3_11: Q Human health and social work activities
  - P_3_12: R Arts, entertainment and recreation
  - P_3_13: S Other service activities
  - P_3_14: T Activities of households as employers
- dim: sex
  - **label**: Sex
  - total: Total
  - male: Men
  - female: Women

## Display
- **split**: sector
- **single-select**:
- **default**: sector=P, sex=total
- **transform**: level
- **seasonal adjustment**: n/a (quarterly averages, not seasonally adjusted)

## Caveats / simplifications
- **Domestic concept (Inlandkonzept)**: counts persons employed in Switzerland
  regardless of residence, so it differs from the resident-based labour-force
  count; not directly comparable with BESTA *jobs* magnitudes.
- The annual `A`/`Y` rows in the master are deliberately discarded — only the
  quarterly average (`FREQ=="Q"`) survives.
- The sector tree mixes aggregates and leaves under one column; the parent nodes
  (`P`, `P_1`, `P_2`, `P_3`) carry their own series and should be read as totals,
  not summed with their children.

## Provenance
Script: `R/source_fso_dam_csv.R::fso_ets` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-02 (Total P both sexes
2025-Q4 = 5,391,587; agriculture P_1 2025-Q4 = 114,803.9, exact match).
Display reworked 2026-06-03: split = sector (the hierarchical industry tree is the
set of lines), sex = exclusive single-select (Total / Men / Women); sector×sex is
a clean 23×3 rectangle so every chip is populated.
