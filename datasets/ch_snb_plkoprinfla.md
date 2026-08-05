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
The **core inflation** series, kept as a deliberate alternate to headline CPI
(`ch_fso_cpi`) because it is an analytical, derived measure, not a re-export of the
raw price index. It is the canonical series for the Core inflation concept. The cube
bundles **four core-inflation definitions** from two producers under one flat `D0`
dimension: the SNB's **trimmed mean** (KGM, the headline default) and the SFSO's
**Core inflation 1** (K1), **Core inflation 2** (K2), plus the **headline national
CPI inflation rate** (TLK) for reference. Values are **year-on-year inflation rates
in percent**, not index levels. The KGM trimmed-mean history reaches back to
**1983-12**; the SFSO K1/K2 series start later (K1 from 2001-05 in the CSV), so the
full span is driven by the SNB measure.

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
