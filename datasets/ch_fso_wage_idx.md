# Swiss Wage Index

- **id**: ch_fso_wage_idx
- **title**: Swiss Wage Index | de: Schweizerischer Lohnindex | fr: Indice suisse des salaires | it: Indice svizzero dei salari
- **concept**: Labour / Wages
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 1994 .. 2025
- **series**: 12
- **updated**: 2026-04-21

## What is special
The official Swiss wage index (Lohnindex, 1993 = 100), nominal and real, broken
down by sector and by sex. Real wages are the nominal index deflated by consumer
prices, so the two together show whether pay rises kept pace with inflation.

## Access
- **type**: fso-dam-excel — FSO DAM Excel asset
- **order number**: je-e-03.04.03.00.04
- **call**: `fso_excel_download("je-e-03.04.03.00.04")`

## Parsing recipe
- Two sheets: `T1.93` (nominal index) and `T2.93` (real index). The old parser's
  assumed 4-language `_DE/_FR/_IT` files do not exist for this asset; labels are
  English, taken from the reference dimension tables.
- Each sheet has two stacked blocks: an "Index 1993=100" block (header row 4, data
  rows 5-10) and a "Variation in % vs previous year" block (header row 15, data
  rows 16-21). The 6 data rows per block map to the `breakdown` levels in workbook
  order: TOTAL, Men, Women, SECTOR 2 (Secondary), Construction, SECTOR 3 (Tertiary).
- **NOGA classification break handled robustly**: years 1994-2010 sit in columns
  4-20 (NOGA02 era), columns 21-23 hold NOGA08 artifacts (not data), years
  2011-2025 sit in columns 24-38 (NOGA08 era). The parser does **not** hardcode
  column ranges; it selects value columns by detecting which header cells parse as
  a 4-digit year, so the break columns are skipped automatically and the chained
  index stays continuous. European number formatting and stray leading spaces
  (e.g. ` 133.3`) are stripped.

## Dimensions
- `breakdown`: the Total wage index and its two non-crossing cuts, on one overlay
  axis so men and women (or any sectors) can be shown in the same chart. Levels:
  Total; **by sex** → Men, Women; **by sector** → Secondary, Construction (a
  sub-position of Secondary, nested under it), Tertiary. The source carries no
  sex × sector cross product (men/women exist only for the Total sector), which is
  exactly why these are one dimension rather than two. Encoded as a hierarchy so
  the picker renders the "By sex" / "By sector" groups as headers.
- `adjustment`: nominal / real.

The published `change` (year-on-year %) series is dropped: it is exactly the app's
YoY % transform, recomputed on the fly from the index, so storing it would just
duplicate a button. Keeping only the index collapses the former `measure` dimension.

## Labels
- dim: breakdown
  - **label**: Breakdown | de: Gliederung | fr: Ventilation | it: Suddivisione
  - tot: Total | de: Total | fr: Total | it: Totale
  - by_sex: By sex | de: Nach Geschlecht | fr: Selon le sexe | it: Secondo il sesso
  - m: Men | de: Männer | fr: Hommes | it: Uomini
  - f: Women | de: Frauen | fr: Femmes | it: Donne
  - by_sector: By sector | de: Nach Sektor | fr: Selon le secteur | it: Secondo il settore
  - bf1: Secondary sector | de: Sekundärer Sektor | fr: Secteur secondaire | it: Settore secondario
  - f41: Construction | de: Bau | fr: Construction | it: Costruzioni
  - gs4: Tertiary sector | de: Tertiärer Sektor | fr: Secteur tertiaire | it: Settore terziario
- dim: adjustment
  - **label**: Adjustment | de: Bereinigung | fr: Correction | it: Correzione
  - nominal: Nominal wage index | de: Nominallohnindex | fr: Indice des salaires nominaux | it: Indice dei salari nominali
  - real: Real wage index | de: Reallohnindex | fr: Indice des salaires réels | it: Indice dei salari reali

## Hierarchy
The Total and its two non-crossing cuts on one overlay axis; by_sex / by_sector are
real grouping levels (no data of their own), Construction nests under Secondary as a
sub-position.
- tot
  - by_sex
    - m
    - f
  - by_sector
    - bf1
      - f41
    - gs4

## Display
- **split**: breakdown
- **single-select**: adjustment
- **default**: breakdown=tot, adjustment=real
- **transform**: level
- **seasonal adjustment**: n/a (no SA dimension; this is an annual index)

## Caveats / simplifications
- Sector breakdown limited to the four the workbook breaks out.
- Spot-checks match raw values exactly (TOTAL nominal index 1994 = 101.45,
  2025 = 141.9).

## Provenance
Script: `R/source_fso_excel_sets.R::fso_excel_ch_fso_wage_idx`. Datasheet 2026-06-01;
parser verified 2026-06-01 (768 rows, 24 series, 0 NA values).
