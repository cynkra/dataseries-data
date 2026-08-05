# Effective exchange rate indices – Daily

- **id**: ch_snb_devwkieffid
- **title**: Effective exchange-rate index | de: Effektiver Wechselkursindex | fr: Indice de taux de change effectif | it: Indice del tasso di cambio effettivo
- **concept**: Exchange rates / Effective FX index
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: daily
- **coverage**: 1999-01 .. 2026-04-30
- **series**: 12

## What is special
The trade-weighted franc index, the standard daily measure of how strong the Swiss franc is overall and against the euro area.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `devwkieffid`
- **endpoint**: `https://data.snb.ch/api/cube/devwkieffid/data/json/en`
- **call**: `snb_fetch("devwkieffid", title = "Effective exchange rate indices – Daily")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube `devwkieffid`.
- `metadata.key` `{...}` gives `D0,D1,D2` codes in order; one long row per non-null
  observation. Dates here are **actual trading days** (ISO), not month starts, so the
  date column is irregular (weekdays only).
- `R` under `D0` is the non-data parent of `K`/`P`.

## Dimensions
- `D0` Real/Nominal: `N` nominal, `K` real CPI-based, `P` real PPI-based.
- `D1` Index country group: `G` overall index, `E` euro-area index.

The source's `D2` Index/Change dimension (`I` index, `V` day-on-day % change) is reduced
to the index: `V` is exactly the app's day-on-day % change transform, derived from `I`.
Keeping only `I` collapses `D2` away.

## Display
- **split**: D1
- **single-select**: D0
- **default**: D1=G, D0=K
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes no SA toggle for this cube)

## Caveats / simplifications
- Daily, weekday-only dates; gaps on holidays are normal, not missing data.
- The day-on-day change (`V`) is dropped, not stored: it is reproduced by the app's
  % change toggle.
- Drop `ch_snb_devwkieffim` (monthly) in favour of this daily cube.
- SNB has no seasonal-adjustment toggle.

## Provenance
Script: `R/source_snb.R::snb_fetch` (title/topic from `R/snb_cubes.tsv`). Datasheet
authored 2026-06-01.
