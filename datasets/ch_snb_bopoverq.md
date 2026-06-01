# Swiss balance of payments – Overview – Quarter

- **id**: ch_snb_bopoverq
- **concept**: External sector / Balance of payments
- **canonical**: no (alternate for Balance of payments)
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1985-Q1 .. 2025-Q4
- **series**: 42
- **updated**: 2025-Q4 (latest observation; SNB publishes ~3 months in arrears)

## What is special
The one-page overview of the Swiss balance of payments: the headline aggregates of all
four accounts in a single cube. Unlike the current-account detail cube, this one folds
the accounting entry into the component codes, so each line is named for its account
and its entry at once. It carries the top-level structure rarely shown elsewhere: the
**financial account** (direct, portfolio, other, reserve assets, each as net
acquisition of assets `NA*` vs net incurrence of liabilities `NP*`), the **capital
account** (`S8/E8/A8`), **derivatives** (`S14`), and the **statistical difference**
(`SD`) that closes the BoP identity. It is the alternate to the detailed
`ch_snb_bopcurrq` for the same concept: same producer, broader account coverage but
shallower component detail, so it is kept and labelled rather than dropped.

## Access
- **type**: SNB cube API
- **endpoint**: cube id `bopoverq`
- **call**: `snb_fetch("bopoverq", title = "Swiss balance of payments – Overview – Quarter")`, hitting
  `https://data.snb.ch/api/cube/bopoverq/dimensions/en` and `.../data/json/en`

## Parsing recipe
- Single dimension `D0`. Each `timeseries` key carries one brace-delimited code mapped
  to `D0`; null observations skipped; dates are already ISO.
- Flatten labels and hierarchy as in `source_snb.R`. Long table keyed by `D0`, `date`,
  `value`. No SA toggle; raw values.

## Dimensions
- `D0` Component: account x entry leaves. Current account `S0/E0/A0`; goods and
  services `S1/E1/A1`, goods `S2/E2/A2`, services `S3/E3/A3`; primary income
  `S4/E4/A4` with labour income `S5..` and investment income `S6..`; secondary income
  `S7/E7/A7`; capital account `S8/E8/A8`; financial account `S9` plus `NA0/NP0`, and
  by instrument direct (`S10`,`NA1/NP1`), portfolio (`S11`,`NA2/NP2`), other
  (`S12`,`NA3/NP3`), reserve assets (`S13`); derivatives `S14`; statistical
  difference `SD`. Default view `A0` (current-account expenses). Grouping nodes
  (`D0_*`, `data:false`) carry no data.

## Display
- **split**: D0
- **single-select**: n/a (single-dimension cube; D0 is the only dimension)
- **default**: D0=S0
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes raw values, no SA dimension)

## Caveats / simplifications
- This is the roll-up view; for component depth (individual services, investment-income
  splits) use `ch_snb_bopcurrq`. Both are kept because their account coverage differs,
  not as a pure format re-export.

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube `bopoverq`, topic
"Balance of payments"). Datasheet authored 2026-06-01; parser verified 2026-06-01
(6,676 rows, 42 series).
