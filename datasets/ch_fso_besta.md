# Jobs by economic division (quarterly)

- **id**: ch_fso_besta
- **title**: Jobs by economic division | de: Beschäftigte nach Wirtschaftsabteilung | fr: Emplois par division économique | it: Impieghi per divisione economica
- **concept**: Labour / Employment / jobs
- **canonical**: yes
- **featured**: Employment
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1991-07 .. 2026-01
- **series**: 60
- **updated**: not published (live PX-Web pull; latest observation 2026Q1)

## What is special
The Federal Statistical Office's job statistics (BESTA): the number of jobs in
Switzerland by economic division (NOGA), from the grand total down to two-digit
divisions such as pharmaceuticals, financial services and human health. The
division depth is what makes the structural shift of the Swiss economy readable
from a single table.

## Access
- **type**: fso-pxweb — FSO PX-Web (json-stat2)
- **table id**: `px-x-0602000000_101`
- **endpoint / table id**: `px-x-0602000000_101` (node; real table at
  `.../px-x-0602000000_101/px-x-0602000000_101.px`)
- **call**: `fso_fetch("ch_fso_besta", "px-x-0602000000_101", besta_query,
  quarter_col = "Quartal", chunk_by = "Quartal", chunk_size = 40L)` with an
  explicit query (not `fso_fetch_auto`).

## Parsing recipe
- The full cube is ~60 divisions x 10 employment-rate levels x 3 sexes x ~139
  quarters (~250k cells), far over the 5000-cell cap. The query takes the
  **headline slice**: `Wirtschaftsabteilung` = all, `Beschäftigungsgrad` = item
  `TOT`, `Geschlecht` = item `TOT`, `Quartal` = all.
- Even the headline slice (60 x 139) exceeds the cap, so the call **chunks by
  `Quartal`** in groups of 40 quarters; each chunk is a separate POST and the
  parts are `rbind`-ed back together. Dimensions/metadata are stable across
  chunks.
- Time is a single `Quartal` code like `1991Q3`; `.fso_make_date` maps quarter q
  to month `(q-1)*3+1` and emits a first-of-quarter ISO `date`
  (Q1->01, Q2->04, Q3->07, Q4->10), frequency quarterly.
- Dimension **codes are German** even on `/en/` (`Wirtschaftsabteilung`,
  `Beschäftigungsgrad`, `Geschlecht`, `Quartal`); kept as stored column values.

## Dimensions
- `Wirtschaftsabteilung` (Economic division): 60 NOGA codes. `5-96` = total;
  `5-43` Sector II, `45-96` Sector III; `10-33` Manufacturing and its parts
  (`21` Pharmaceuticals, `26` Watches/electronics, ...); `41-43` Construction;
  service divisions `45`..`96`. Range codes like `10-12` are aggregates of the
  contained two-digit divisions.

The source's `Beschäftigungsgrad` (Employment rate) and `Geschlecht` (Gender) columns
only ever carry `TOT` here, so both are dropped: a one-option picker is pure noise. That
leaves `Wirtschaftsabteilung` as the single dimension.

## Display
- **split**: Wirtschaftsabteilung
- **single-select**:
- **default**: Wirtschaftsabteilung=5-96
- **transform**: level
- **seasonal adjustment**: n/a (no seasonal-adjustment dimension; only the total
  employment-rate, total-sex slice is fetched)

## Hierarchy
The NOGA division codes are contiguous ranges that nest by containment
(`5-96` Total ⊃ `5-43` Sector II ⊃ `10-33` Manufacturing ⊃ divisions); the tree is
derived from those ranges.
- derive: noga-range

## Caveats / simplifications
- Only the total-level, total-sex slice is captured. The full-time/part-time and
  men/women breakdowns of this exact table are dropped here; the sex breakdown
  lives in the sibling dataset `ch_fso_jobs_sex` (table `_102`).
- No `updated` date is published by the API; latest quarter stands in.

## Provenance
Script: `R/source_fso.R::fso_fetch` (explicit chunked query built in
`R/pipeline.R`). Datasheet authored 2026-06-01.
