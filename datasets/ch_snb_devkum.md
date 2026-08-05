# Foreign exchange rates – Month

- **id**: ch_snb_devkum
- **title**: Bilateral exchange rates | de: Bilaterale Wechselkurse | fr: Taux de change bilatéraux | it: Tassi di cambio bilaterali
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
The headline bilateral CHF exchange-rate table, with a history reaching back to
**1914**, the longest FX record in the catalog. Quotes are CHF per foreign-currency
unit, with the unit baked into each currency label (EUR 1, GBP 1, but DKK 100, JPY
100, etc.), so the multiplier matters when comparing rates. Each currency is
published as both a **monthly average** (M0) and an **end-of-month** value (M1).
Beyond spot rates it carries two **USD forward rates** (3-month and 6-month, CHF per
1 USD), which is unusual for a spot-rate table. Currencies are grouped by region
(Europe, America, Africa, Asia and Australia, SDR, USD forward rates); the group
nodes are non-data headers. Note the CSV begins well after 1914 for most currencies
(e.g. ARS from 1999); the 1914 start reflects the earliest long series (USD/major
European), not every pair.

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
