# Mortgage loans and other domestic and foreign loans (monthly)

- **id**: ch_snb_bakredinausbm
- **title**: Mortgage & other loans
- **concept**: Money & banking / Banking & credit
- **canonical**: yes
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1985-06 .. 2026-03
- **series**: 90
- **updated**: 2026-03 release (PublishingDate in CSV header)

## What is special
Bank loans split by **domestic vs foreign** counterparty, back to 1985. This is
the geography cut of the loan book: it separates mortgage and other lending into
claims on borrowers in Switzerland versus abroad, which the company-size and
economic-sector cubes do not do. The long history (from 1985) and the
domestic/foreign axis make it the reference for total credit exposure by
location. Each combination is further crossed by bank category, loan type
(mortgage / other, secured / unsecured) and the utilisation-vs-credit-line pair,
the same utilisation/headroom logic as the other `bakred*` cubes.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `bakredinausbm`
- **endpoint**: `https://data.snb.ch/api/cube/bakredinausbm/data/json/en`
- **call**: `snb_fetch("bakredinausbm", title = "Mortgage loans and other domestic and foreign loans")`

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
- `D1` Domestic and foreign: `T0` total domestic and foreign, `I` domestic, `A`
  foreign.
- `D2` Type of loan: `T1` total loans, `H` mortgage loans, then under grouping
  node `K` (other loans, non-data): `T2` total, `G` secured, `U` unsecured.
- `D3` Utilisation and credit lines: `F` utilisation, `B` credit lines.

## Display
- **split**: D1
- **single-select**: D0, D2, D3
- **default**: D1=T0, D0=AV1, D2=T1, D3=F
- **transform**: level
- **seasonal adjustment**: n/a (no SA dimension; stock series at month end)

## Caveats / simplifications
- `K` (other loans) is a grouping node (`data: false`); only `T2/G/U` carry data.
- 90 stored series are the populated cross-products, not the full 5x3x6x2 grid.
- Stock series at month end, CHF millions.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `bakredinausbm`, title/topic from
`R/snb_cubes.tsv`). Datasheet authored 2026-06-01.
