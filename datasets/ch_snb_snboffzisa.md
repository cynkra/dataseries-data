# Official interest rates

- **id**: ch_snb_snboffzisa
- **title**: Official interest rates
- **concept**: Interest rates & yields / Policy & official rates
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2000-01 .. 2026-04
- **series**: 10
- **updated**: 2026-04 (use API PublishingDate header for exact day)

## What is special
The official policy rates set by the major central banks, monthly from 2000, on a
single cube. Distinctive because it is not just the Swiss rate: the hierarchy is
organised by country, so it doubles as a cross-central-bank policy-rate comparison.
Switzerland carries the `LZ` SNB policy rate plus the historical SNB target range
for 3-month CHF Libor (`UG0` lower, `OG0` upper). The United States block is the
Fed target range (`UG1`/`OG1`). The Euro area/ECB block has three distinct
facility rates: `H` main refinancing, `SRF` marginal lending, `EF` deposit
facility. The UK is `L0` (Bank of England Bank Rate) and Japan `L1` (BoJ
uncollateralised overnight call rate). All values are in percent. This captures
the regime change in Swiss monetary policy (the move from a Libor target band to a
single SNB policy rate) inside one series, because both the old range bounds and
the current single rate live here.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `snboffzisa`
- **endpoint**: `https://data.snb.ch/api/cube/snboffzisa/data/json/en`
- **call**: `snb_fetch("snboffzisa", title = "Official interest rates")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`.
- `metadata.key` is `EPB@SNB.snboffzisa{<D0>}`; one dimension. Long tibble of
  `D0,date,value`. Dates -> first of month. Drop null values.
- Values are percentages, already numeric on the JSON path.
- The country grouping is purely in the `hierarchy` of the meta; the data table is
  flat on `D0`.

## Dimensions
- `D0` (Overview), grouped by country:
  - Switzerland: `LZ` SNB policy rate; SNB target range for 3-month CHF Libor
    `UG0` lower / `OG0` upper.
  - United States: Fed target range `UG1` lower / `OG1` upper.
  - Euro area/ECB: `H` main refinancing rate, `SRF` marginal lending facility,
    `EF` deposit facility.
  - United Kingdom: `L0` Bank of England Bank Rate.
  - Japan: `L1` BoJ uncollateralised overnight call rate.

## Display
- **split**: D0
- **single-select**:
- **default**: D0=LZ
- **transform**: level
- **seasonal adjustment**: n/a (policy rates, no seasonal adjustment). Opens on the
  current single SNB policy rate (`LZ`) as the Swiss headline rather than a target-
  range bound or a foreign central bank; the other country rates are available as
  additional lines in the split.

## Caveats / simplifications
- The grouping nodes (`D0_0` Switzerland, `D0_0_0` SNB target range, `D0_1` US,
  `D0_1_0` Fed target range, `D0_2` ECB, `D0_3` UK, `D0_4` Japan) are labels only;
  the 10 stored series are the leaves. Country attribution is implicit in the code
  and the stored `hierarchy`, not a separate column.
- Target-range series (`UG*`/`OG*`) are bounds, not a single rate; treat lower and
  upper as a pair when charting Switzerland or the US.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `snboffzisa`, title from
`R/snb_cubes.tsv`, topic "Interest rates"). Datasheet authored 2026-06-01.
