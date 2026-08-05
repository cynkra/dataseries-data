# Consumer prices – SNB and SFSO core inflation rates

- **id**: ch_snb_plkoprinfla
- **title**: Core inflation | de: Kerninflation | fr: Inflation sous-jacente | it: Inflazione di fondo
- **concept**: Prices / Core inflation
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1983-12 .. 2026-04
- **series**: 4

## What is special
Core inflation for Switzerland: the price trend with the most volatile components
stripped out, which is what central banks watch instead of the headline rate. Four
definitions sit side by side — the SNB's trimmed mean and two Federal Statistical
Office measures, plus the headline rate for reference. Values are year-on-year
rates in percent, not index levels.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `plkoprinfla`
- **endpoint**: `https://data.snb.ch/api/cube/plkoprinfla/data/json/en`
- **call**: `snb_fetch("plkoprinfla", title = "Consumer prices – SNB and SFSO core inflation rates")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube `plkoprinfla`.
- Single dimension `D0`; `metadata.key` `{...}` carries one code. One long row per
  non-null observation with `date` (ISO month start) and numeric `value`.
- Producer group headers (`D0_0` SNB, `D0_1` SFSO) are non-data nodes; only the four
  measure codes bear values.

## Dimensions
- `D0` Overview (measure): `KGM` SNB core inflation, trimmed mean (default); `K1`
  SFSO core inflation 1; `K2` SFSO core inflation 2; `TLK` headline national CPI
  inflation rate.

## Display
- **split**: D0
- **single-select**: n/a (single dimension)
- **default**: D0=KGM
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube has no SA dimension)

## Caveats / simplifications
- Values are YoY inflation rates (%), not a price index.
- Per-measure coverage differs; only KGM goes back to 1983.
- SNB has no seasonal-adjustment toggle.

## Provenance
Script: `R/source_snb.R::snb_fetch` (title/topic from `R/snb_cubes.tsv`). Datasheet
authored 2026-06-01.
