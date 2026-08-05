# Producer and Import Price Index

- **id**: ch_fso_ppi
- **title**: Producer & import prices
- **concept**: Prices / Producer & import prices
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1963-01 .. 2026-04
- **series**: 7
- **updated**: 2026-05-12

## What is special
Producer and import prices for Switzerland, monthly back to 1963. The seven
"series" are the same total index expressed on **seven successive original base
years** (1963, 1993, 2003, 2010, 2015, 2020, 2025), each a re-indexed view of the
same Producer Price Index, all fully populated over the whole span. This mirrors
the old parser's `idx_type` dimension. Longest price history in the catalog.

## Access
- **type**: fso-dam-excel — FSO DAM Excel asset
- **order number**: su-q-05.04.03.01-ppi-ipp
- **call**: `fso_excel_download("su-q-05.04.03.01-ppi-ipp")`

## Parsing recipe
- Three sheets: `INDEX_m` (monthly, parsed), `INDEX_y` (annual, skipped as a
  roll-up), `PPI_IPI_PGA_PGAI` (a multilingual code/label dictionary).
- Parse `INDEX_m`. Column 3 holds FSO date codes as **Excel serials** (origin
  1899-12-30); footer rows decode to NA and are dropped.
- Columns 11+ are month-over-month / year-over-year % changes and are dropped.
- European number parsing: strip `'` thousands separators, `,` -> `.`; the `…`
  placeholder is treated as NA.

## Dimensions
- `base`: the index original base year (1963, 1993, 2003, 2010, 2015, 2020, 2025).
  Month labels translated for English (Mai -> May, Dez -> Dec).

## Labels
- dim: base
  - **label**: Index base

## Display
- **split**: base
- **single-select**: 
- **default**: base=2020
- **transform**: yoy
- **seasonal adjustment**: n/a

The only dimension is `base` (the original index base year); the seven bases are
re-indexed views of the same total Producer Price Index. The headline default opens on
the current operational base (`2020`, Dec 2020 = 100), which carries the full recent
history; the brand-new `2025` base has barely any data yet, and the older bases are
legacy re-basings. Because this is a pure price index whose point is the rate of change,
the headline transform is year-on-year (`yoy`) rather than the raw index level.

## Caveats / simplifications
- Only the **PPI total** series is captured. The position breakdown (PPI.A, PPI.01,
  ...) exists only as a label dictionary in the `PGA` sheet with **no accompanying
  time series** in this workbook, so there is nothing to extract there.
- The annual sheet is not emitted (monthly is higher frequency; annual derives
  from it, per the keep-native-frequency rule).

## Provenance
Script: `R/source_fso_excel_sets.R::fso_excel_ch_fso_ppi`. Datasheet 2026-06-01;
parser verified 2026-06-01 (5,320 rows, 7 series, 0 NA values).
