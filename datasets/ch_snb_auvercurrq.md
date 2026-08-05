# Switzerland's international investment position - Breakdown by currency - Quarter

- **id**: ch_snb_auvercurrq
- **title**: Investment position by currency | de: Auslandvermögen nach Währung | fr: Position extérieure par monnaie | it: Posizione sull'estero per valuta
- **concept**: External sector / International investment position
- **canonical**: no (currency cut of the IIP; companion to canonical overview `auvekomq`)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1985-Q1 .. 2025-Q4
- **series**: 94
- **updated**: 2025-Q4 (latest observation; PublishingDate in CSV header is the freshness signal)

## What is special
The currency cut of Switzerland's international investment position: how much of
the country's foreign assets and liabilities are denominated in Swiss francs, US
dollars, euros, other currencies and precious metals. This is what makes the
external balance sheet sensitive to exchange-rate moves. Currency is crossed with
accounting entry and functional component, so a query such as US-dollar portfolio
liabilities is direct. For the headline position, see `ch_snb_auvekomq`.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `auvercurrq`
- **endpoint**: `GET https://data.snb.ch/api/cube/auvercurrq/data/json/en`
- **call**: `snb_fetch("auvercurrq", title = "Switzerland's international investment position - Breakdown by currency - Quarter")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`; map each `timeseries.metadata.key`
  `{...}` codes positionally onto dim ids `D0`,`D1`,`D2`.
- Flatten `dimensionItems` code -> label; here all three axes are flat (single
  level, no grouping nodes).
- Quarterly dates are period starts; coerce to ISO `Date`.
- JSON+CSV only, no JSON-stat; no SA toggle.

## Dimensions
- `D0` (Currency): `T` total, `CHF`, `USD`, `EUR`, `UW` other currencies, `E`
  precious metals.
- `D1` (Accounting entry): `A` assets, `P` liabilities, `N` net IIP.
- `D2` (Component): `T` total, `D0` direct investment, `P` portfolio investment,
  `D1` derivatives, `UI` other investment, `W` reserve assets.

## Display
- **split**: D2
- **single-select**: D1
- **default**: D0=T, D1=N, D2=T
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube has no seasonal-adjustment dimension)

## Hierarchy
Both line dimensions carry a `T Total` that the source ships as a flat sibling of its
parts. Nest each under its total: the functional-component split (D2, IMF BPM6) and the
currency breakdown (D0: CHF / USD / EUR / other currencies / precious metals).
- derive: under-root T
- dim: D0
- derive: under-root T

## Caveats / simplifications
- Stocks in CHF millions, end of quarter; the component axis here is the coarse
  functional level only (no deep sub-tree, unlike `auvekomq`).
- Codes `D0`/`D1` appear both as dim ids and as `D2` item codes; key on the dim id,
  not the bare code.
- Default preview series is `D0 = CHF`, `D1 = A`, `D2 = D0` (CHF direct-investment
  assets).

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube_id `auvercurrq`).
Datasheet 2026-06-01; parser verified 2026-06-01 (13,794 rows, 94 series).
