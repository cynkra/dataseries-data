# Jobs by economic division and sex

- **id**: ch_fso_jobs_sex
- **title**: Jobs by economic division and sex | de: Beschäftigte nach Wirtschaftsabteilung und Geschlecht | fr: Emplois par division économique et sexe | it: Impieghi per divisione economica e sesso
- **concept**: Labour / Employment / jobs
- **canonical**: no (alternate / breakdown of `ch_fso_besta`)
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1995-07 .. 2026-01
- **series**: 336
- **updated**: not published (live PX-Web pull; latest observation 2026Q1)

## What is special
Swiss jobs split by region, sector, full-time or part-time, and sex, the breakdowns the headline employment series reports only as a total.

## Access
- **type**: fso-pxweb — FSO PX-Web (json-stat2)
- **table id**: `px-x-0602000000_102`
- **endpoint / table id**: `px-x-0602000000_102` (node; real table at
  `.../px-x-0602000000_102/px-x-0602000000_102.px`)
- **call**: `fso_fetch_auto("ch_fso_jobs_sex", "px-x-0602000000_102", ...)`
  (auto-query, no hand-written selection).

## Parsing recipe
- `fso_fetch_auto` reads table metadata, selects **all values of every
  dimension**, detects the time dimension (`Quartal` here) and chunks by it so
  each POST stays under the 5000-cell cap. Chunk size is
  `floor(4500 / cells_per_period)` where `cells_per_period` is the product of the
  four non-time dimension sizes; chunk parts are `rbind`-ed back together.
- Time is a single `Quartal` code like `1995Q3`; `.fso_make_date` maps it to a
  first-of-quarter ISO `date` (Q1->01, Q2->04, Q3->07, Q4->10), frequency
  quarterly. Non-numeric (annual aggregate) time codes parse to NA and are
  dropped.
- Dimension **codes are German** even on `/en/` (`Grossregion`,
  `Wirtschaftssektor`, `Beschäftigungsgrad`, `Geschlecht`, `Quartal`); kept as
  stored column values.

## Dimensions
- `Grossregion` (Major region): `0` Switzerland; `1` Lake Geneva, `2` Espace
  Mittelland, `3` North-Western Switzerland, `4` Zurich Region, `5` Eastern
  Switzerland, `6` Central Switzerland, `7` Ticino.
- `Wirtschaftssektor` (Economic sector): `TOT` Sectors 2-3, `2` Sector 2
  (industry), `3` Sector 3 (services).
- `Beschäftigungsgrad` (Employment rate): `TOT` total, `1` full time, `2` part
  time, `3` total seasonally adjusted, `4` full-time equivalents, `4.1` FTE
  seasonally adjusted.
- `Geschlecht` (Gender): `TOT` total, `1` man, `2` woman.

## Display
- **split**: Geschlecht
- **single-select**: Beschäftigungsgrad
- **default**: Geschlecht=TOT, Grossregion=0, Wirtschaftssektor=TOT, Beschäftigungsgrad=TOT
- **transform**: level
- **seasonal adjustment**: lives inside `Beschäftigungsgrad` (levels `3` total SA and
  `4.1` FTE SA); the opening view uses the non-adjusted total (`TOT`), the SA levels
  are available as toggles

## Hierarchy
`0 Switzerland` is the national total over the seven major regions, but FSO lists it as their sibling; nest the regions under Switzerland.
- dim: Grossregion
- derive: under-root 0

## Caveats / simplifications
- Mixed measures share one `value` column: headcount levels and full-time-
  equivalent levels coexist under `Beschäftigungsgrad`, and two levels are
  seasonally adjusted. Read the unit/adjustment from the dimension, not the
  magnitude.
- Sector detail is coarse (total / Sector 2 / Sector 3) compared with BESTA's
  NOGA divisions; use BESTA for fine industry cuts.
- No `updated` date is published by the API; latest quarter stands in.

## Provenance
Script: `R/source_fso.R::fso_fetch_auto` (auto-query; entry in `R/pipeline.R`).
Datasheet authored 2026-06-01.
