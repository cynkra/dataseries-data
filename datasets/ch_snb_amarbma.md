# Labour market (registered unemployment, SECO)

- **id**: ch_snb_amarbma
- **title**: Registered unemployment | de: Registrierte Arbeitslosigkeit | fr: Chômage inscrit | it: Disoccupazione registrata
- **concept**: Labour / Unemployment
- **canonical**: yes (registered/SECO definition — the headline unemployment series; the ILO `ch_fso_unemp_rate` is the labelled alternate)
- **featured**: Unemployment
- **source**: snb (data originate from SECO)
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1948-01 .. 2026-04
- **series**: 9
- **updated**: 2026-04 (latest observation; PublishingDate in CSV header is the freshness signal)

## What is special
People registered unemployed at Swiss job centres, with the rate, vacancies and short-time work. Units differ by series, so select one to chart.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `amarbma`
- **endpoint**: `GET https://data.snb.ch/api/cube/amarbma/data/json/en`
- **call**: `snb_fetch("amarbma", title = "Labour market (registered unemployment, SECO)")`

## Parsing recipe
- Fetch `/dimensions/en` (code -> label + nested `dimensionItems` hierarchy) and
  `/data/json/en` (each `timeseries.metadata.key` like `...{T0}` carries the
  dimension-item codes in `{...}` order).
- Flatten the hierarchy; map each key's `{...}` codes positionally onto dim ids
  (`D0`). Emit one long row per observation with `date` and `value`.
- Dates are period starts; coerce to ISO `Date` (months -> first of month).
- SNB emits JSON+CSV only (no JSON-stat) and has no seasonal-adjustment toggle:
  SA appears as explicit codes (`S0/S1/S2`) inside the single `D0` axis.

## Dimensions
- `D0` (Overview): leaf data codes are `K` short-time workers, `T0`/`S0` registered
  unemployed (raw/SA), `T1`/`S1` jobless rate (raw/SA), `T2`/`S2` notified vacancies
  (raw/SA), `RS` registered job seekers, `E` labour force. The `D0_1..D0_3` codes
  are non-data grouping nodes (`data: false`) and carry no observations.

## Display
- **split**: D0
- **single-select**: (none; D0 is the only dimension)
- **default**: D0=T1
- **transform**: level
- **seasonal adjustment**: encoded as codes inside D0 (S0/S1/S2 are the SA
  variants of registered unemployed / jobless rate / vacancies), not a separate
  dimension. Default to the raw Total registered unemployed (T0); pick S0/S1/S2
  to read the seasonally adjusted variants. Note D0 mixes units, so the SA codes
  only pair with their own raw Total (T0<->S0, T1<->S1, T2<->S2).

## Caveats / simplifications
- Heterogeneous units within one dimension (persons, %, vacancy counts); no unit
  column, the meaning is encoded in the `D0` code.
- Default series for previews is `E` (labour force).

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube_id `amarbma`).
Datasheet 2026-06-01; parser verified 2026-06-01 (6,540 rows, 9 series).
