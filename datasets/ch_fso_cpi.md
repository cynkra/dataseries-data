# Consumer Price Index (LIK)

- **id**: ch_fso_cpi
- **title**: Consumer prices (detailed basket)
- **concept**: Prices / Consumer prices
- **canonical**: no (alternate for Consumer prices — the detailed basket breakdown)
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1982-12 .. 2026-04
- **series**: 595
- **updated**: 2026-05-05

## What is special
The Swiss CPI (Landesindex der Konsumentenpreise) with the **full position
hierarchy**: 595 positions from the total index down to COICOP sub-baskets (food,
housing, transport, ...), not just the headline total. This is the **detailed
alternate** to the canonical SNB headline series (`ch_snb_plkopr`): reach for this
one when you want the basket breakdown, and for `ch_snb_plkopr` when you want the
headline total or YoY inflation across the long history (the FSO asset only carries
the hierarchy from December 1982, whereas the SNB chain reaches back to 1921). Base
period December 2025 = 100 (asset `su-d-05.02.66`, which superseded the frozen
Dec-2020=100 asset `su-d-05.02.67`). History to December 1982.

## Access
- **type**: fso-dam-excel — FSO DAM Excel asset
- **order number**: su-d-05.02.66
- **call**: `fso_excel_download("su-d-05.02.66")` returns the master xlsx + publish date

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

## Hierarchy
Built from the source: the FSO `INDEX_m` sheet carries a `Level` column (1 = Total,
2 = COICOP division, deeper = group/leaf), and the parser reconstructs the COICOP tree
from it (parent = the nearest preceding position of smaller depth). The code slugs are
*not* plain string prefixes — the two-digit divisions 10/11/12 collide with sub-codes
of division 1 — so depth, not the code, drives the nesting. The appended "type of
goods" positions (`110_*`, no depth) stay at the top level. Each `item` node carries
its own series, so every level is selectable.

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
