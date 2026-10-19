# Foreign exchange rates – Month

- **id**: ch_snb_devkum
- **title**: Bilateral exchange rates | de: Bilaterale Wechselkurse | fr: Taux de change bilatéraux | it: Tassi di cambio bilaterali
- **keywords**: Swiss franc, CHF, euro, EUR, US dollar, USD, FX, forex | de: Franken, Wechselkurs, Devisenkurs | fr: franc suisse, taux de change | it: franco svizzero, tasso di cambio
- **concept**: Exchange rates / Bilateral FX
- **canonical**: yes
- **featured**: Exchange rates
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1914-01 .. 2026-04
- **series**: 54
- **updated**: 2026-04 (latest observation)

## What is special
Swiss franc exchange rates against the major currencies, monthly average and month end. Quoted per unit, but per 100 for yen, krone and others.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `devkum`
- **endpoint**: `https://data.snb.ch/api/cube/devkum/data/json/en`
- **call**: `snb_fetch("devkum", title = "Foreign exchange rates – Month")`

## Parsing recipe
- Fetch `/dimensions/en` (code -> label tree, with nested `dimensionItems`) and
  `/data/json/en` (the observations) for cube `devkum`.
- Each timeseries `metadata.key` (e.g. `...{M0,USD1}`) carries the dimension-item
  codes in `dim_order` order; `.snb_key_codes` extracts them from the `{...}` block.
- One long row per non-null observation: `D0`, `D1`, `date`, `value`. Dates are
  ISO month starts; values numeric.
- Non-data grouping nodes (`D1_0` Europe, `D1_1` America, ...) carry no key and never
  appear as rows; they survive only as `hierarchy` in the dimension tree.

## Dimensions
- `D0` Monthly average/End of month: `M0` monthly average, `M1` end of month.
- `D1` Currency: ISO-ish codes with the quote unit embedded (`EUR1`, `GBP1`,
  `DKK100`, `JPY100`, `XDR1` for the SDR, `USD3M`/`USD6M` USD forward rates).
  Defaults to `USD1`.

## Labels
- dim: D1
  - **units** EUR1: CHF per 1 EUR | de: CHF je 1 EUR | fr: CHF pour 1 EUR | it: CHF per 1 EUR
  - **units** GBP1: CHF per 1 GBP | de: CHF je 1 GBP | fr: CHF pour 1 GBP | it: CHF per 1 GBP
  - **units** DKK100: CHF per 100 DKK | de: CHF je 100 DKK | fr: CHF pour 100 DKK | it: CHF per 100 DKK
  - **units** NOK100: CHF per 100 NOK | de: CHF je 100 NOK | fr: CHF pour 100 NOK | it: CHF per 100 NOK
  - **units** CZK100: CHF per 100 CZK | de: CHF je 100 CZK | fr: CHF pour 100 CZK | it: CHF per 100 CZK
  - **units** HUF100: CHF per 100 HUF | de: CHF je 100 HUF | fr: CHF pour 100 HUF | it: CHF per 100 HUF
  - **units** PLN100: CHF per 100 PLN | de: CHF je 100 PLN | fr: CHF pour 100 PLN | it: CHF per 100 PLN
  - **units** RUB1: CHF per 1 RUB | de: CHF je 1 RUB | fr: CHF pour 1 RUB | it: CHF per 1 RUB
  - **units** SEK100: CHF per 100 SEK | de: CHF je 100 SEK | fr: CHF pour 100 SEK | it: CHF per 100 SEK
  - **units** TRY100: CHF per 100 TRY | de: CHF je 100 TRY | fr: CHF pour 100 TRY | it: CHF per 100 TRY
  - **units** USD1: CHF per 1 USD | de: CHF je 1 USD | fr: CHF pour 1 USD | it: CHF per 1 USD
  - **units** CAD1: CHF per 1 CAD | de: CHF je 1 CAD | fr: CHF pour 1 CAD | it: CHF per 1 CAD
  - **units** ARS1: CHF per 1 ARS | de: CHF je 1 ARS | fr: CHF pour 1 ARS | it: CHF per 1 ARS
  - **units** BRL100: CHF per 100 BRL | de: CHF je 100 BRL | fr: CHF pour 100 BRL | it: CHF per 100 BRL
  - **units** MXN100: CHF per 100 MXN | de: CHF je 100 MXN | fr: CHF pour 100 MXN | it: CHF per 100 MXN
  - **units** ZAR1: CHF per 1 ZAR | de: CHF je 1 ZAR | fr: CHF pour 1 ZAR | it: CHF per 1 ZAR
  - **units** JPY100: CHF per 100 JPY | de: CHF je 100 JPY | fr: CHF pour 100 JPY | it: CHF per 100 JPY
  - **units** AUD1: CHF per 1 AUD | de: CHF je 1 AUD | fr: CHF pour 1 AUD | it: CHF per 1 AUD
  - **units** CNY100: CHF per 100 CNY | de: CHF je 100 CNY | fr: CHF pour 100 CNY | it: CHF per 100 CNY
  - **units** HKD100: CHF per 100 HKD | de: CHF je 100 HKD | fr: CHF pour 100 HKD | it: CHF per 100 HKD
  - **units** KRW100: CHF per 100 KRW | de: CHF je 100 KRW | fr: CHF pour 100 KRW | it: CHF per 100 KRW
  - **units** MYR100: CHF per 100 MYR | de: CHF je 100 MYR | fr: CHF pour 100 MYR | it: CHF per 100 MYR
  - **units** NZD1: CHF per 1 NZD | de: CHF je 1 NZD | fr: CHF pour 1 NZD | it: CHF per 1 NZD
  - **units** SGD1: CHF per 1 SGD | de: CHF je 1 SGD | fr: CHF pour 1 SGD | it: CHF per 1 SGD
  - **units** THB100: CHF per 100 THB | de: CHF je 100 THB | fr: CHF pour 100 THB | it: CHF per 100 THB
  - **units** XDR1: CHF per 1 SDR | de: CHF je 1 SZR | fr: CHF pour 1 DTS | it: CHF per 1 DSP
  - **units** USD3M: CHF per 1 USD | de: CHF je 1 USD | fr: CHF pour 1 USD | it: CHF per 1 USD
  - **units** USD6M: CHF per 1 USD | de: CHF je 1 USD | fr: CHF pour 1 USD | it: CHF per 1 USD

## Display
- **split**: D1
- **single-select**: D0
- **default**: D1=USD1, D0=M0
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube, no SA dimension)

## Caveats / simplifications
- Quote convention is CHF per stated unit; the unit (1 vs 100) differs per currency.
- SNB has no seasonal-adjustment toggle; raw rates only.
- Coverage per currency varies widely; early history exists only for major pairs.

## Provenance
Script: `R/source_snb.R::snb_fetch` (title/topic from `R/snb_cubes.tsv`). Datasheet
authored 2026-06-01.

## What is special (de)
Frankenkurse gegenüber den wichtigsten Währungen, Monatsdurchschnitt und Monatsende. Notiert je Einheit, aber je 100 bei Yen, Kronen und anderen.

## What is special (fr)
Cours du franc suisse face aux principales monnaies, moyenne mensuelle et fin de mois. Cotés par unité, mais par 100 pour le yen, les couronnes et d'autres.

## What is special (it)
Corsi del franco svizzero rispetto alle principali valute, media mensile e fine mese. Quotati per unità, ma per 100 per yen, corone e altre.
