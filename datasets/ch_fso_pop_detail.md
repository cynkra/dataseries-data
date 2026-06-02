# Permanent resident population by nationality and sex

- **id**: ch_fso_pop_detail
- **concept**: Population and demographics / Resident population by nationality
- **canonical**: no (the headline resident population is `ch_fso_pop`, the 1861– demographic balance; this is the recent nationality × sex stock detail)
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 2010 .. 2024
- **series**: 9

## What is special
The permanent resident population broken down by **nationality (Swiss / foreign) ×
sex**, annual year-end stock from the STATPOP register. Complements `ch_fso_pop` (the
long 1861– demographic balance with births/deaths) with the modern
foreign-population share — ~27.4% foreign in 2024.

## Access
- **type**: FSO SDMX (disseminate.stats.swiss), sliced to the national total
- **flow**: agency `CH1.STATPOP`, dataflow `DF_STATPOP_REGLING`, version 1.0.0
- **call**: `fso_sdmx_pop_detail("ch_fso_pop_detail")`

## Parsing recipe
- One pre-sliced SDMX key `1._T..._T.A` (DSD order
  `POPULATION_TYPE.REG_LING.NATIONALITY_CATEGORY.SEX.AGE.FREQ`): permanent residents,
  all language regions, age total, annual; leaves nationality × sex.
- `NATIONALITY_CATEGORY` `_T`/`1`/`2` = Total/Swiss/Foreign; `SEX` `_T`/`1`/`2` =
  Total/Male/Female. `TIME_PERIOD` (`YYYY`) → first-of-year ISO (year-end stock).

## Dimensions
- `nationality`: Total / Swiss / Foreign.
- `sex`: Total / Male / Female.

## Display
- **split**: nationality
- **single-select**: sex
- **default**: nationality=_T, sex=_T
- **transform**: level
- **seasonal adjustment**: n/a

## Caveats / simplifications
- National only; the flow also carries a full single-year age dimension (~100 codes)
  and language region — sliced out here for the headline nationality × sex stock.
- BEVNAT vital flows (births/deaths) are **not** added: only marriages exist on SDMX
  (and only 2020–2024), and births/deaths back to 1861 are already in `ch_fso_pop`.

## Provenance
Script: `R/source_fso_sdmx.R::fso_sdmx_pop_detail` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-02 (Total 2024 = 9,051,029, exact match to FSO).
