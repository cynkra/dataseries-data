# Producer and Import Price Index

- **id**: ch_fso_ppi
- **title**: Producer and import prices | de: Produzenten- und Importpreise | fr: Prix à la production et à l'importation | it: Prezzi alla produzione e all'importazione
- **keywords**: PPI | de: PPI, Produzentenpreise | fr: IPP | it: IPP
- **concept**: Prices / Producer and import prices
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1963-01 .. 2026-04
- **series**: 7
- **updated**: 2026-05-12

## What is special
Prices Swiss producers charge and importers pay, monthly. The seven series are the same index rebased on successive years from 1963 to 2025.

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
  - **label**: Index base | de: Indexbasis | fr: Base de l'indice | it: Base dell'indice
  - **units** 1963: Index, 1963 = 100 | de: Index, 1963 = 100 | fr: Indice, 1963 = 100 | it: Indice, 1963 = 100
  - **units** 1993: Index, May 1993 = 100 | de: Index, Mai 1993 = 100 | fr: Indice, mai 1993 = 100 | it: Indice, maggio 1993 = 100
  - **units** 2003: Index, May 2003 = 100 | de: Index, Mai 2003 = 100 | fr: Indice, mai 2003 = 100 | it: Indice, maggio 2003 = 100
  - **units** 2010: Index, December 2010 = 100 | de: Index, Dezember 2010 = 100 | fr: Indice, décembre 2010 = 100 | it: Indice, dicembre 2010 = 100
  - **units** 2015: Index, December 2015 = 100 | de: Index, Dezember 2015 = 100 | fr: Indice, décembre 2015 = 100 | it: Indice, dicembre 2015 = 100
  - **units** 2020: Index, December 2020 = 100 | de: Index, Dezember 2020 = 100 | fr: Indice, décembre 2020 = 100 | it: Indice, dicembre 2020 = 100
  - **units** 2025: Index, December 2025 = 100 | de: Index, Dezember 2025 = 100 | fr: Indice, décembre 2025 = 100 | it: Indice, dicembre 2025 = 100

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

## What is special (de)
Preise, die Schweizer Produzenten verlangen und Importeure zahlen, monatlich. Die sieben Reihen sind derselbe Index, neu basiert auf den Jahren 1963 bis 2025.

## What is special (fr)
Prix pratiqués par les producteurs suisses et payés par les importateurs, mensuel. Les sept séries sont le même indice rebasé sur les années 1963 à 2025.

## What is special (it)
Prezzi praticati dai produttori svizzeri e pagati dagli importatori, mensile. Le sette serie sono lo stesso indice ribasato sugli anni dal 1963 al 2025.
