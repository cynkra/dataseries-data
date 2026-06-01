# Labour market (registered unemployment, SECO)

- **id**: ch_snb_amarbma
- **concept**: Labour / Unemployment
- **canonical**: no (alternate for Unemployment; registered/SECO definition, kept alongside FSO `ch_fso_unemp_rate` ILO)
- **featured**: Unemployment
- **source**: Swiss National Bank (data originate from SECO)
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1948-01 .. 2026-04
- **series**: 9
- **updated**: 2026-04 (latest observation; PublishingDate in CSV header is the freshness signal)

## What is special
The registered (administrative) view of Swiss unemployment, sourced from SECO and
republished by the SNB. It is the deliberate alternate to the FSO ILO survey rate:
different definition, not a format re-export, so both are kept and labelled. History
runs back to 1948, the longest labour series in the catalog. One `Overview` dimension
packs several distinct concepts at once: registered unemployed, jobless rate,
notified vacancies (each as raw Total and Seasonally adjusted), plus short-time
working, registered job seekers, and the labour force. Note the unusual mix of units
on a single axis: counts of persons, a percentage rate, and vacancy counts all live
under the same `D0` codes, so consumers must split by code before charting.

## Access
- **type**: SNB cube API
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
- **default**: D0=T0
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
