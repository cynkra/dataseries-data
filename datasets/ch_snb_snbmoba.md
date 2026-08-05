# Monetary base

- **id**: ch_snb_snbmoba
- **title**: Monetary base | de: Notenbankgeldmenge | fr: Monnaie centrale | it: Base monetaria
- **concept**: Money & banking / Monetary aggregates
- **canonical**: no (alternate for Monetary aggregates; `ch_snb_snbmonagg` M1-M3 is canonical)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1950-01 .. 2026-04
- **series**: 10
- **updated**: 2026-04 (use API PublishingDate header for exact day)

## What is special
Central bank money in Switzerland, shown from both sides: how it is created, and banknotes plus the sight deposits banks hold.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `snbmoba`
- **endpoint**: `https://data.snb.ch/api/cube/snbmoba/data/json/en`
- **call**: `snb_fetch("snbmoba", title = "Monetary base")`

## Parsing recipe
- Fetch `/dimensions/en` (labels + hierarchy) and `/data/json/en` (observations).
- `metadata.key` is `EPB@SNB.snbmoba{<D0>}`; one dimension. Long tibble of
  `D0,date,value`. Dates -> first of month. Drop null values.
- Number format from the JSON is already numeric (CHF millions, no thousands
  separators to strip on this path).
- Freshness signal: `PublishingDate` header on the live `/data/csv/en` response.

## Dimensions
- `D0` (Overview), three groups:
  - Origination: `RF` relevant foreign-currency positions, `W` securities
    portfolio, `G` money-market transactions, `S0` other, `N0` monetary base.
  - Utilisation: `N1` banknotes in circulation, `GB` sight deposit accounts of
    domestic banks, `N2` monetary base.
  - Seasonally adjusted: `N3` monetary base, `S1` seasonal factor.

## Display
- **split**: D0
- **single-select**:
- **default**: D0=N0
- **transform**: level
- **seasonal adjustment**: n/a as a dimension; the SNB encodes it as its own
  series rather than a toggle (`N3` seasonally adjusted monetary base, `S1`
  seasonal factor under the `D0_2` group). The headline opens on the raw monetary
  base total (`N0`, the origination-side total) rather than the seasonally adjusted
  variant.

## Caveats / simplifications
- The grouping nodes (`D0_0` Origination, `D0_1` Utilisation, `D0_2` Seasonally
  adjusted) carry no data; only the leaves do. The flattened long table keeps the
  10 leaf codes, so the asset/liability/SA split is implicit in the codes and the
  stored `hierarchy` in the JSON meta, not in a separate column.
- `N0`, `N2`, `N3` are all "monetary base" on three different bases (origination
  total, utilisation total, seasonally adjusted); they coincide in concept but come
  from different measurement sides.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `snbmoba`, title from `R/snb_cubes.tsv`,
topic "Money and banking"). Datasheet authored 2026-06-01.

## What is special (de)
Notenbankgeld in der Schweiz, von beiden Seiten gezeigt: wie es entsteht, und Notenumlauf plus Giroguthaben der Banken.

## What is special (fr)
La monnaie centrale en Suisse, montrée des deux côtés : comment elle est créée, et les billets en circulation plus les avoirs à vue des banques.

## What is special (it)
La moneta centrale in Svizzera, mostrata da entrambi i lati: come viene creata, e le banconote in circolazione più gli averi a vista delle banche.
