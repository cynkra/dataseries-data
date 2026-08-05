# Bilateral exchange rate indices – Monthly

- **id**: ch_snb_devwkibiim
- **title**: Bilateral exchange-rate indices | de: Bilaterale Wechselkursindizes | fr: Indices de taux de change bilatéraux | it: Indici dei tassi di cambio bilaterali
- **concept**: Exchange rates / Bilateral FX
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1973-01 .. 2026-04
- **series**: 324

## What is special
Bilateral exchange-rate indices of the Swiss franc against about 54 partner
currencies. Real rates come in two deflator variants, consumer-price and
producer-price based, alongside the nominal index, and each is given both as an
index and as a year-on-year percentage change. For the trade-weighted summary
rather than individual partners, see `ch_snb_devwkieffid`.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `devwkibiim`
- **endpoint**: `https://data.snb.ch/api/cube/devwkibiim/data/json/en`
- **call**: `snb_fetch("devwkibiim", title = "Bilateral exchange rate indices – Monthly")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube `devwkibiim`.
- `metadata.key` `{...}` gives `D0,D1,D2` codes in order; one long row per non-null
  observation, `date` ISO month start, numeric `value`.
- The `R` (Real) node under `D0` is a non-data grouping header whose leaves are `K`
  and `P`; only `N`, `K`, `P` bear data. Drop the `V` (change) rows downstream if a
  level-only view is wanted, but they are kept here as published.

## Dimensions
- `D0` Real/Nominal: `N` nominal, `K` real CPI-based, `P` real PPI-based (`R` is the
  non-data parent of K/P).
- `D1` Countries: ~54 ISO-style partner codes (`US`, `DE`, `JP`, `CN`, `GB`, ...).

The source's `D2` Index/Change dimension (`I` index, `V` YoY % change) is reduced to the
index: `V` is exactly the app's YoY % transform, derived from `I`, so storing it would
duplicate a button. Keeping only `I` collapses `D2` away.

## Display
- **split**: D1
- **single-select**: D0
- **default**: D1=US, D0=K
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes no SA toggle for this cube)

## Caveats / simplifications
- The YoY-change representation (`V`) is dropped, not stored: it is derived from the
  index and reproduced on the fly by the app's YoY % toggle.
- "Real" is two deflator variants (CPI vs PPI), not a single real series.
- SNB has no seasonal-adjustment toggle.

## Provenance
Script: `R/source_snb.R::snb_fetch` (title/topic from `R/snb_cubes.tsv`). Datasheet
authored 2026-06-01.
