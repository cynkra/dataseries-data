# Labour productivity (GDP per hour worked)

- **id**: ch_fso_labour_productivity
- **title**: Labour productivity
- **concept**: National accounts / Labour productivity
- **canonical**: yes
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 1991 .. 2024
- **series**: 3

## What is special
The headline **labour-productivity** decomposition: real GDP, actual hours worked,
and productivity (GDP per hour), all as a chained-volume index, base 1991 = 100.
Productivity is the ratio of the other two, so the three plot together on one scale —
the long-run Swiss productivity-growth story (≈ +0.9%/yr) at a glance.

## Access
- **type**: FSO DAM asset, master is a long CSV (not xlsx)
- **order**: `ts-x-04.07.01.01` (asset 36178401)
- **call**: `fso_labour_productivity("ch_fso_labour_productivity")`

## Parsing recipe
- `fso_dam_csv_download("ts-x-04.07.01.01")` resolves + downloads the CSV master;
  read with `fileEncoding = "UTF-8-BOM"` (the file carries a BOM).
- Columns `PERIOD, INDICATOR, UNIT_MEA, VALUE, OBS_STATUS`. Key the dimension on
  `INDICATOR` (`GDP` / `Actual hours worked` / `Productivity`) — NOT on `UNIT_MEA`,
  which is the constant `"Index"` for all three (the legacy "duplicate idx" trap).
- `PERIOD` (year) → first-of-year ISO date.

## Dimensions
- `indicator`: `gdp` GDP volume, `hours` actual hours worked, `productivity` GDP per
  hour worked (the default).

## Display
- **split**: indicator
- **single-select**:
- **default**: indicator=productivity
- **transform**: level
- **seasonal adjustment**: n/a (annual)

## Caveats / simplifications
- It is an **index** (1991 = 100), not a level (CHF/hour) and not a %-change. Sibling
  FSO assets give current-price levels and by-branch/region cuts if wanted later.

## Provenance
Script: `R/source_fso_dam_csv.R::fso_labour_productivity` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-02 (productivity 2024 = 146.0786, exact match).
