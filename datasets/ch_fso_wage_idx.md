# Swiss Wage Index

- **id**: ch_fso_wage_idx
- **concept**: Labour / Wages
- **canonical**: yes
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 1994 .. 2025
- **series**: 24
- **updated**: 2026-04-21

## What is special
The official Swiss wage index (Lohnindex, base 1993 = 100), nominal and real, by
sector and sex. Captures wage development the SNB cubes do not carry at all.

## Access
- **type**: FSO DAM Excel asset
- **order number**: je-e-03.04.03.00.04
- **call**: `fso_excel_download("je-e-03.04.03.00.04")`

## Parsing recipe
- Two sheets: `T1.93` (nominal index) and `T2.93` (real index). The old parser's
  assumed 4-language `_DE/_FR/_IT` files do not exist for this asset; labels are
  English, taken from the reference dimension tables.
- Each sheet has two stacked blocks: an "Index 1993=100" block (header row 4, data
  rows 5-10) and a "Variation in % vs previous year" block (header row 15, data
  rows 16-21). The 6 data rows per block map to sector x sex combinations:
  TOTAL (both / men / women), SECTOR 2 (secondary), Construction, SECTOR 3 (tertiary).
- **NOGA classification break handled robustly**: years 1994-2010 sit in columns
  4-20 (NOGA02 era), columns 21-23 hold NOGA08 artifacts (not data), years
  2011-2025 sit in columns 24-38 (NOGA08 era). The parser does **not** hardcode
  column ranges; it selects value columns by detecting which header cells parse as
  a 4-digit year, so the break columns are skipped automatically and the chained
  index stays continuous. European number formatting and stray leading spaces
  (e.g. ` 133.3`) are stripped.

## Dimensions
- `sector`: Total, Secondary, Construction, Tertiary (Construction is a sub-position
  of Secondary; hierarchy not encoded in the flat dimension).
- `sex`: both / men / women (the men/women split exists only for the Total sector,
  matching the source).
- `measure`: index / change (year-on-year %).
- `adjustment`: nominal / real.

## Display
- **split**: sector
- **single-select**: sex, measure, adjustment
- **default**: sector=bs0, sex=tot, measure=index, adjustment=real
- **transform**: level
- **seasonal adjustment**: n/a (no SA dimension; this is an annual index)

## Caveats / simplifications
- Sector breakdown limited to the four the workbook breaks out.
- Spot-checks match raw values exactly (TOTAL nominal index 1994 = 101.45,
  2025 = 141.9).

## Provenance
Script: `R/source_fso_excel_sets.R::fso_excel_ch_fso_wage_idx`. Datasheet 2026-06-01;
parser verified 2026-06-01 (768 rows, 24 series, 0 NA values).
