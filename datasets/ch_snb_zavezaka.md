# Payment cards and ATMs

- **id**: ch_snb_zavezaka
- **title**: Payment cards and ATMs
- **concept**: Payment systems / Payments & cash
- **canonical**: no (alternate for Payments & cash; the `zave*` family covers SIC, cards, ATMs and e-money, this cube is the card-and-ATM stock view)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2005-01 .. 2026-03
- **series**: 7
- **updated**: 2026-03 (latest published period)

## What is special
Monthly stock of the Swiss card landscape: number of credit cards, debit cards and
e-money cards in circulation, plus the count of ATMs. It is a counts-only cube (no
turnover), so it reads as the installed base behind the flow cube `zavezaluba`. The
distinctive feature is the "of which with contactless payment function" subtotal
(`DZ0`/`DZ1`/`DZ2`), which only begins in late 2014 once contactless rolled out, so
those three series start 2014-12 while the card totals run back to 2005. The single
`Total` ATM series (`T3`) sits in the same cube despite being a different unit
(machines, not cards).

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `zavezaka`
- **endpoint**: `https://data.snb.ch/api/cube/zavezaka/data/json/en`
- **call**: `snb_fetch("zavezaka", title = "Payment cards and ATMs")`

## Parsing recipe
- Fetch `/dimensions/en` (code -> label + hierarchy) and `/data/json/en` (timeseries)
  for cube id `zavezaka`.
- Each `timeseries$metadata$key` (e.g. `...{T0}`) carries the dimension-item codes in
  `{...}` in `dim_order`; split on `,` into the `D0` column.
- Each `values` entry is `{date, value}`; drop null values, coerce `date` to ISO and
  `value` to numeric. SNB emits JSON+CSV only, no JSON-stat, no seasonal-adjustment
  toggle.
- Keep only data-bearing leaves (`data: true`); grouping nodes (`D0_0`, `D0_0_0`, ...)
  carry no observations.

## Dimensions
- `D0` (Overview): the single dimension. Leaf codes: `T0` credit cards total, `DZ0`
  of which contactless; `T1` debit cards total, `DZ1` contactless; `T2` e-money total,
  `DZ2` contactless; `T3` ATMs total. Default item `T0`.

## Display
- **split**: D0
- **single-select**: (none; D0 is the only dimension)
- **default**: D0=T0
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes this cube raw; no SA dimension)

## Caveats / simplifications
- Contactless subtotals (`DZ*`) start 2014-12, not 2005, so the series are unbalanced.
- Mixed units in one cube: `T0`/`T1`/`T2`/`DZ*` are card counts, `T3` is a machine
  count. There is no value-per-unit normalisation here.
- The intermediate grouping levels (`D0_0` Credit cards, `D0_0_0` Number of cards) are
  labels only and produce no rows.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube list + title from `R/snb_cubes.tsv`).
Datasheet authored 2026-06-01; parser verified 2026-06-01 (1,309 data rows, 7 series).
