# Securities turnover on the Swiss stock exchange

- **id**: ch_snb_capweums
- **concept**: Financial markets / Securities turnover
- **canonical**: yes
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1993-01 .. 2026-04
- **series**: 10
- **updated**: 2026-04 (latest observation)

## What is special
Monthly trading turnover on the Swiss stock exchange (SIX), the canonical
securities-turnover series, back to 1993. The distinctive cut is the
**domestic-vs-foreign** split applied to each asset class: shares and bond issues each
break into domestic (`IT0/IT1`), foreign (`AT0/AT1`) and total (`T0/T1`), which makes
visible how much of the venue's volume is foreign paper. Beyond those it carries
investment funds (`A`), structured products and options (`SPO`), a grand total (`T2`),
and turnover in SMI-constituent securities (`ISMIT`). A compact 10-series companion to
the daily index cube `ch_snb_capchstocki`: where that measures price levels, this
measures traded volume.

## Access
- **type**: SNB cube API
- **endpoint**: cube id `capweums`
- **call**: `snb_fetch("capweums", title = "Securities turnover on the Swiss stock exchange")`,
  hitting `https://data.snb.ch/api/cube/capweums/dimensions/en` and `.../data/json/en`

## Parsing recipe
- Single dimension `D0`. One code per `timeseries` key; null observations skipped;
  monthly dates already ISO (first of month). Flatten labels and hierarchy. Long table
  keyed by `D0`, `date`, `value`. No SA toggle; raw values.

## Dimensions
- `D0` Overview: instrument and origin. Shares `IT0` domestic / `AT0` foreign / `T0`
  total; bond issues `IT1` domestic / `AT1` foreign / `T1` total; `A` investment funds;
  `SPO` structured products and options; `T2` overall total; `ISMIT` securities
  included in the SMI. Default `A`. Grouping nodes `D0_0` (Shares) and `D0_1` (Bond
  issues) are `data:false` and carry no observations.

## Display
- **split**: D0
- **single-select**: (none; single dimension)
- **default**: D0=T2
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube, no SA dimension)

## Caveats / simplifications
- `T2` is a roll-up total kept alongside its components; no frequency synthesis is
  performed.

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube `capweums`, topic
"Financial markets"). Datasheet authored 2026-06-01; parser verified 2026-06-01
(3,973 rows, 10 series).
