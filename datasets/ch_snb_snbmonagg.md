# Monetary aggregates M1, M2 and M3

- **id**: ch_snb_snbmonagg
- **concept**: Money & banking / Monetary aggregates
- **canonical**: yes
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1984-12 .. 2026-04
- **series**: 16
- **updated**: 2026-04 (use API PublishingDate header for exact day)

## What is special
The headline Swiss monetary aggregates, monthly from 1984. This is the canonical
money-supply series. It is the only cube in this group with two dimensions, which
gives it a clean matrix shape: `D0` is level vs year-on-year change, `D1` is the
component or aggregate. The components nest into the aggregates by construction:
currency in circulation + sight deposits + deposits in transaction accounts ->
**M1**; M1 + savings deposits -> **M2**; M2 + time deposits -> **M3**. So the cube
ships the building blocks (`B`, `S0`, `ET`, `S1`, `T`) and the three totals
(`GM1`, `GM2`, `GM3`) side by side, each available as a CHF-million level (`B`) and
as a year-over-year percentage change (`VV`). That 2x8 cross is exactly the 16
stored series. Compared with `snbmoba` (base money, the central bank's own
liabilities), these aggregates measure money held by the public, which is why this
is the canonical aggregate and the base is the alternate.

## Access
- **type**: SNB cube API
- **endpoint**: `https://data.snb.ch/api/cube/snbmonagg/data/json/en`
- **call**: `snb_fetch("snbmonagg", title = "Monetary aggregates M1, M2 and M3")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`.
- `metadata.key` is `EPB@SNB.snbmonagg{<D0>,<D1>}`; the two codes in `{...}` map to
  `D0,D1` in order. Long tibble of `D0,D1,date,value`. Dates -> first of month.
  Drop null values. Sort by `D0,D1,date`.
- `D0=B` rows are CHF-million levels; `D0=VV` rows are percentage changes vs the
  same month a year earlier. Same `D1` code means different unit depending on `D0`.

## Dimensions
- `D0` (Level/change): `B` level (CHF millions), `VV` change vs the corresponding
  month of the previous year (%).
- `D1` (Monetary aggregates): components `B` currency in circulation, `S0` sight
  deposits, `ET` deposits in transaction accounts, `S1` savings deposits, `T` time
  deposits; aggregates `GM1` M1, `GM2` M2, `GM3` M3.

## Display
- **split**: D1
- **single-select**: D0
- **default**: D1=GM3, D0=B
- **transform**: level
- **seasonal adjustment**: n/a (no seasonal-adjustment dimension). Opens on the
  broadest aggregate M3 (`D1=GM3`) as a CHF-million level (`D0=B`) rather than the
  year-on-year change (`D0=VV`); switch `D0` to `VV` for the growth-rate view.

## Caveats / simplifications
- The code `B` is overloaded: in `D0` it means "level", in `D1` it means "currency
  in circulation". They are distinguished only by which dimension column they sit
  in.
- Aggregates and their components are both present, so naive sums over `D1` would
  double count. The aggregation is definitional (M1 < M2 < M3), captured in the
  `D1` labels, not in a separate flag.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `snbmonagg`, title from
`R/snb_cubes.tsv`, topic "Money and banking"). Datasheet authored 2026-06-01.
