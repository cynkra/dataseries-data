# Consumer confidence

- **id**: ch_snb_concon
- **concept**: Business cycle & sentiment / Consumer confidence
- **canonical**: yes
- **source**: Swiss National Bank (SNB), data of SECO origin
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1972-Q4 .. 2026-Q2
- **series**: 12
- **updated**: 2026-Q2 (latest observation, 2026-04-01)

## What is special
The Swiss consumer confidence survey, the canonical sentiment series, back to 1972,
one of the longest survey histories in the catalog. The data originate from SECO (the
State Secretariat for Economic Affairs, which runs the survey) but are redistributed
through the SNB cube API, so the title is relabelled accordingly in the catalog. The
cube exposes both the headline **consumer sentiment index** (`NIK`) and the twelve
underlying balance components that build it: assessments of the past and expected
economic situation, past and expected prices, job security and unemployment outlook,
past and future personal finances, savings/debt situation and outlook, and whether now
is a good moment for major purchases. Having the sub-questions, not just the composite,
is what makes this the canonical sentiment series rather than a bare index.

## Access
- **type**: SNB cube API
- **endpoint**: cube id `concon`
- **call**: `snb_fetch("concon", title = "Consumer confidence")`, hitting
  `https://data.snb.ch/api/cube/concon/dimensions/en` and `.../data/json/en`

## Parsing recipe
- Single dimension `D0`, flat (no nested hierarchy). One code per `timeseries` key;
  null observations skipped; quarterly dates already ISO. Flatten labels. Long table
  keyed by `D0`, `date`, `value`. No SA toggle; raw survey balances.

## Dimensions
- `D0` Overview: survey item. Components `VW` past economic situation, `EW` economic
  outlook, `VP` past prices, `EP` price outlook (12 months), `SA` job security, `EA`
  unemployment outlook, `VL` past financial situation, `EL` financial outlook, `ASSS`
  current savings/debt situation, `ZA` moment to make major purchases, `ESSS`
  savings/debt outlook, and `NIK` the composite consumer sentiment index. Default
  `ASSS`. All twelve are data leaves; no grouping nodes.

## Display
- **split**: D0
- **single-select**: (none; single dimension)
- **default**: D0=NIK
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube, no SA dimension)

## Caveats / simplifications
- Producer attribution: survey is SECO's; the SNB cube is the access channel. The
  catalog title is the SECO relabel ("Consumer confidence") per the concept universe.
- Values are survey balances/index points, not levels; the composite `NIK` is the
  series most users want.

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube `concon`, topic
"Business surveys"). Datasheet authored 2026-06-01; parser verified 2026-06-01
(2,304 rows, 12 series).
