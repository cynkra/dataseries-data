# Real estate price indices – total for Switzerland – by quarter

- **id**: ch_snb_plimoinchq
- **title**: Real estate prices | de: Immobilienpreise | fr: Prix de l'immobilier | it: Prezzi immobiliari
- **concept**: Prices / Real estate prices
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1970-Q1 .. 2026-Q1
- **series**: 17

## What is special
Swiss house and rent price indices from four providers side by side, covering apartments, houses, offices, retail and industrial space.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `plimoinchq`
- **endpoint**: `https://data.snb.ch/api/cube/plimoinchq/data/json/en`
- **call**: `snb_fetch("plimoinchq", title = "Real estate price indices – total for Switzerland – by quarter")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube `plimoinchq`.
- `metadata.key` `{...}` gives `D0,D1` codes in order; one long row per non-null
  observation. Dates are ISO **quarter starts** (Jan/Apr/Jul/Oct).
- Property-type group headers (`D0_0` residential, `D0_1` rents) and provider headers
  (`D0_0`..`D0_3`) are non-data nodes; only the leaf type/basis codes bear values.

## Dimensions
- `D0` Property type: `EW` privately owned apartments, `EH` single-family houses,
  `MH` apartment buildings, `MW` rental housing, `BF` office space, `GF` industrial/
  commercial space, `VF` retail space.
- `D1` Data provider + price basis: `TP3` SFSO transaction, `TP1` Fahrländer
  transaction, `TP2` IAZI transaction, `AP`/`TP` Wüest Partner asking/transaction.

## Display
- **split**: D0
- **single-select**: D1
- **default**: D0=EW, D1=AP
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes no SA toggle for this cube)

## Caveats / simplifications
- Sparse cross: many type x provider combinations do not exist.
- Provider codes (`TP`, `TP1`, `TP2`, `TP3`, `AP`) encode both the source and the
  asking-vs-transaction basis; keep both to compare methodologies.
- SNB has no seasonal-adjustment toggle.

## Provenance
Script: `R/source_snb.R::snb_fetch` (title/topic from `R/snb_cubes.tsv`). Datasheet
authored 2026-06-01.
