# Monetary aggregates M1, M2 and M3

- **id**: ch_snb_snbmonagg
- **title**: Monetary aggregates (M1–M3)
- **concept**: Money & banking / Monetary aggregates
- **canonical**: yes
- **featured**: Money supply
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1984-12 .. 2026-04
- **series**: 16
- **updated**: 2026-04 (use API PublishingDate header for exact day)

## What is special
The headline Swiss monetary aggregates, monthly from 1984. This is the canonical
money-supply series. The source cube has two dimensions — `D0` level vs year-on-year
change, `D1` the component or aggregate — but `D0` is dropped: its `VV` (year-on-year
change) level is exactly the app's YoY % transform, derived from the `B` level, so
keeping only `B` collapses `D0` away and leaves `D1` as the single dimension. The
components nest into the aggregates by construction:
currency in circulation + sight deposits + deposits in transaction accounts ->
**M1**; M1 + savings deposits -> **M2**; M2 + time deposits -> **M3**. So the cube
ships the building blocks (`B`, `S0`, `ET`, `S1`, `T`) and the three totals
(`GM1`, `GM2`, `GM3`) side by side as CHF-million levels — 8 stored series. Compared
with `snbmoba` (base money, the central bank's own liabilities), these aggregates
measure money held by the public, which is why this is the canonical aggregate and
the base is the alternate.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `snbmonagg`
- **endpoint**: `https://data.snb.ch/api/cube/snbmonagg/data/json/en`
- **call**: `snb_fetch("snbmonagg", title = "Monetary aggregates M1, M2 and M3")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`.
- `metadata.key` is `EPB@SNB.snbmonagg{<D0>,<D1>}`; the two codes in `{...}` map to
  `D0,D1` in order. Long tibble of `D0,D1,date,value`. Dates -> first of month.
  Drop null values. Sort by `D0,D1,date`.
- `D0=B` rows are CHF-million levels; `D0=VV` rows are percentage changes vs the
  same month a year earlier. We keep only `D0=B` and drop `D0=VV` (the app's YoY %
  toggle reproduces it), then drop the now single-valued `D0` column.

## Dimensions
- `D1` (Monetary aggregates): components `B` currency in circulation, `S0` sight
  deposits, `ET` deposits in transaction accounts, `S1` savings deposits, `T` time
  deposits; aggregates `GM1` M1, `GM2` M2, `GM3` M3. (The dropped `D0` dimension
  separated level from year-on-year change; only the level is kept — see above.)

## Display
- **split**: D1
- **single-select**:
- **default**: D1=GM3
- **transform**: level
- **seasonal adjustment**: n/a (no seasonal-adjustment dimension). Opens on the
  broadest aggregate M3 (`D1=GM3`) as a CHF-million level; use the app's YoY %
  toggle for the growth-rate view.

## Hierarchy
SNB ships `D1` flat (all eight items as siblings), but the aggregates nest
cumulatively: M1 ⊂ M2 ⊂ M3. M1 (`GM1`) = currency in circulation (`B`) + sight
deposits (`S0`) + transaction-account deposits (`ET`); M2 (`GM2`) = M1 + savings
deposits (`S1`); M3 (`GM3`) = M2 + time deposits (`T`). We declare that nesting so the
picker shows each broader aggregate as the parent of the narrower one plus its
increment (every node is a published series, so all are selectable). Source: SNB
definitions of the money supply (European standard).
- GM3
  - GM2
    - GM1
      - B
      - S0
      - ET
    - S1
  - T

## Caveats / simplifications
- After dropping `D0`, the code `B` is unambiguous: it now only appears in `D1`
  ("currency in circulation"). (In the source it doubled as the `D0` "level" code.)
- Aggregates and their components are both present, so naive sums over `D1` would
  double count. The aggregation is definitional (M1 < M2 < M3), captured in the
  `D1` labels, not in a separate flag.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `snbmonagg`, title from
`R/snb_cubes.tsv`, topic "Money and banking"). Datasheet authored 2026-06-01.
