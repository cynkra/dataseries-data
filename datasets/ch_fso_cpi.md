# Consumer Price Index (LIK)

- **id**: ch_fso_cpi
- **concept**: Prices / Consumer prices
- **canonical**: yes
- **featured**: Inflation
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1982-12 .. 2025-12
- **series**: 443
- **updated**: 2026-01-08

## What is special
The Swiss headline inflation measure (Landesindex der Konsumentenpreise). This is
the canonical CPI: it carries the **full position hierarchy**, 443 positions from
the total index down to COICOP sub-baskets (food, housing, transport, ...), not
just the headline total. It replaces the SNB re-export `plkopr` (which is only the
total). Base period December 2020 = 100. History to December 1982.

## Access
- **type**: FSO DAM Excel asset
- **order number**: su-d-05.02.67
- **call**: `fso_excel_download("su-d-05.02.67")` returns the master xlsx + publish date

## Parsing recipe
- Sheet `INDEX_m` (monthly index levels). Sister sheets `VAR_m-1`/`VAR_m-12`
  (month/year change), `CONTR_m` (contributions), `INDEX_y`/`VAR_y` (annual) are
  intentionally not parsed; only the monthly level.
- Rows 1-3 are a title banner; **row 4 is the header**; data begins row 5.
- Columns 1-14 are position metadata: Code, PosNo, PosType, Level, COICOP,
  DE/FR/IT/EN labels, weight year.
- **Date columns begin at column 15.** The header row stores dates as **Excel day
  serials** (30286 = 1982-12-01 ... 45992 = 2025-12-01). Read the header row with
  `col_types="text"` to recover the raw serials; a numeric read makes readxl
  reformat them into bogus POSIXct seconds.
- Reshape wide -> long; `value` is the numeric index.

## Dimensions
- `item`: the FSO position **Code** (e.g. `100_100` = Total, `100_1` = Food and
  non-alcoholic beverages). English level labels come from `PosTxt_E` (falling back
  to `Item_E`).

## Display
- **split**: item
- **single-select**:
- **default**: item=100_100
- **transform**: yoy
- **seasonal adjustment**: n/a (the CPI is not seasonally adjusted)

## Caveats / simplifications
- Code slugs (`100_100`, `100_1`, ...) are used directly as level keys rather than
  the short mnemonic ids (ttl, fanb, ...) from the old hand-maintained mapping; the
  Codes are stable, unique and machine-derivable, avoiding a brittle hardcode.
- Only English labels emitted (workbook also has DE/FR/IT).
- The hierarchy nesting and weights are not yet encoded; positions are flat.
- The "Sondergliederungen" (additional classifications) prefixing from the old
  parser is not applied.

## Provenance
Script: `R/source_fso_excel_sets.R::fso_excel_ch_fso_cpi`. Datasheet 2026-06-01;
parser verified 2026-06-01 (177,589 rows, 443 series, 0 NA values).
