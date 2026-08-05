# Domestic loans, broken down by economic sector and industry (monthly)

- **id**: ch_snb_bakredsekbm
- **title**: Domestic loans by sector
- **concept**: Money & banking / Banking & credit
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1985-06 .. 2026-03
- **series**: 540
- **updated**: 2026-03 release (PublishingDate in CSV header)

## What is special
Domestic bank loans broken down by **borrower industry** (NOGA/NACE sections):
private households plus the full sector list from agriculture and manufacturing
through construction, trade, hospitality, finance, health, public administration
and a non-classifiable bucket. This is the most granular of the `bakred*`
credit cubes, the one that tells you which parts of the Swiss economy are
borrowing. The industry axis is crossed with bank category, loan type
(mortgage / other, secured / unsecured) and the utilisation-vs-credit-line pair,
which is what pushes it to 540 stored series. Long history from 1985, and the
sector dimension is the distinctive feature; household mortgage utilisation is
the default cell.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `bakredsekbm`
- **endpoint**: `https://data.snb.ch/api/cube/bakredsekbm/data/json/en`
- **call**: `snb_fetch("bakredsekbm", title = "Domestic loans, broken down by economic sector and industry")`

## Parsing recipe
- `/dimensions/en` for code->label and hierarchy; `/data/json/en` for
  observations.
- `metadata.key` carries the four codes in `dim_order` (`D0,D1,D2,D3`);
  `.snb_key_codes` splits the braces.
- Keep non-null values, parse `date` (month start) to ISO, cast numeric. CHF
  millions.
- `PublishingDate` header is the freshness signal. JSON+CSV only, no SA toggle.

## Dimensions
- `D0` Bank category: `AV1` banks in Switzerland, `AV2` cantonal, `AV3` big,
  `AV4` regional and savings, `AV10` Raiffeisen.
- `D1` Type of loan: `T0` total loans, `H` mortgage loans, then under grouping
  node `K` (other loans, non-data): `T2` total, `GE` secured, `UN` unsecured.
  (Note: secured/unsecured codes here are `GE`/`UN`, unlike `G`/`U` in the
  company-size and domestic/foreign cubes.)
- `D2` Utilisation and credit lines: `F` utilisation, `B` credit lines.
- `D3` Economic activities and sectors: `T1` total domestic, `AA` private
  households, then NACE sections `A` agriculture, `C` manufacturing, `F`
  construction, `G` trade, `I` accommodation/food, `K` finance/insurance, `Q`
  health, etc., plus `SX1` non-classifiable loans. Several sections are grouped
  (e.g. `DE`, `JLMN`, `RS`).

## Display
- **split**: D3
- **single-select**: D0, D1, D2
- **default**: D3=T1, D0=AV1, D1=T0, D2=F
- **transform**: level
- **seasonal adjustment**: n/a (no SA dimension; stock series at month end)

## Hierarchy
`T1 Total domestic` is the sum of the 17 economic-sector / household loan codes, but SNB lists it as their sibling. Nest them under it.
- derive: under-root T1

## Caveats / simplifications
- `K` under `D1` (other loans) is a grouping node (`data: false`); only `T2/GE/UN`
  carry data. Do not confuse it with `K` under `D3` (financial activities), which
  is a real sector leaf.
- 540 stored series are the populated cross-products only.
- Stock series at month end, CHF millions.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `bakredsekbm`, title/topic from
`R/snb_cubes.tsv`). Datasheet authored 2026-06-01.
