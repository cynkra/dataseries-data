# Securities turnover on the Swiss stock exchange

- **id**: ch_snb_capweums
- **title**: Securities turnover | de: Effektenumsätze | fr: Transactions sur titres | it: Transazioni in titoli
- **concept**: Financial markets / Securities turnover
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1993-01 .. 2026-04
- **series**: 10
- **updated**: 2026-04 (latest observation)

## What is special
How much is traded on the Swiss exchange each month, with shares and bonds split into domestic and foreign paper.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `capweums`
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

## Hierarchy
`T2 Total` is the grand aggregate over the asset-class groups (shares, bond issues, investment funds, structured products), shipped as their sibling. Nest them under it (the shares/bonds domestic-foreign sub-splits are preserved).
- derive: under-root T2

## Caveats / simplifications
- `T2` is a roll-up total kept alongside its components; no frequency synthesis is
  performed.

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube `capweums`, topic
"Financial markets"). Datasheet authored 2026-06-01; parser verified 2026-06-01
(3,973 rows, 10 series).

## What is special (de)
Wie viel an der Schweizer Börse monatlich gehandelt wird, mit Aktien und Anleihen getrennt nach inländischen und ausländischen Titeln.

## What is special (fr)
Combien s'échange chaque mois à la bourse suisse, actions et obligations séparées en titres suisses et étrangers.

## What is special (it)
Quanto viene scambiato ogni mese alla borsa svizzera, con azioni e obbligazioni separate in titoli svizzeri ed esteri.
