# Vacant dwellings

- **id**: ch_fso_vacant_dwellings
- **concept**: Domestic economy / Vacant dwellings
- **canonical**: yes
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 1995 .. 2025
- **series**: 2

## What is special
The official Swiss **vacancy rate** (Leerwohnungsziffer) and the absolute count of
vacant dwellings, national, annual since 1995. The vacancy rate is the headline
housing-market tightness indicator — it fell to ~1.0% by 2025, the tightest in
years.

## Access
- **type**: FSO SDMX (disseminate.stats.swiss), sliced to the national total
- **flow**: agency `CH1.LWZ`, dataflow `DF_LWZ_1`, version 1.0.0
- **call**: `fso_sdmx_vacant_dwellings("ch_fso_vacant_dwellings")`

## Parsing recipe
- One pre-sliced SDMX key — the full cube is ~2.5M rows at municipality level. KEY
  `8100._T._T.V+PC.A` pins geography = `8100` (Switzerland; note this codelist has
  no `_T` total — the national code is the literal `8100`), rooms = `_T` (total),
  vacancy type = `_T` (total), measure = `V`+`PC`, FREQ = `A`.
- `MEASURE_DIMENSION`: `V` = count of vacant dwellings, `PC` = vacancy rate in %.
  (`ABS_V`/`I` exist in the codelist but return no records at the national total.)
- `TIME_PERIOD` (`YYYY`) → first-of-year ISO date.

## Dimensions
- `measure`: `PC` Vacancy rate (%) — the default/headline — and `V` Vacant dwellings
  (number). Two different units, so single-select rather than a meaningful overlay.

## Display
- **split**: measure
- **single-select**:
- **default**: measure=PC
- **transform**: level
- **seasonal adjustment**: n/a (annual)

## Caveats / simplifications
- National total only. The cube also breaks down by canton/municipality, number of
  rooms (1..6+), and vacancy type (for sale / for rent / new / old / house type);
  all sliced out here for the headline series.
- The vacancy rate (`PC`) starts 1997; the count (`V`) starts 1995.

## Provenance
Script: `R/source_fso_sdmx.R::fso_sdmx_vacant_dwellings` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; SDMX slice verified live 2026-06-02 (1995 .. 2025).
