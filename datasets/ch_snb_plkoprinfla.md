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
Swiss inflation with volatile items stripped out, the measure central banks watch. Four definitions side by side, as yearly rates not index levels.

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

## What is special (de)
Schweizer Teuerung ohne die schwankungsanfälligen Positionen, das Mass, auf das Zentralbanken schauen. Vier Definitionen nebeneinander, als Jahresraten statt Indexstände.

## What is special (fr)
Inflation suisse hors postes volatils, la mesure que suivent les banques centrales. Quatre définitions côte à côte, en taux annuels et non en niveaux d'indice.

## What is special (it)
Inflazione svizzera al netto delle voci volatili, la misura seguita dalle banche centrali. Quattro definizioni affiancate, come tassi annui e non livelli d'indice.
