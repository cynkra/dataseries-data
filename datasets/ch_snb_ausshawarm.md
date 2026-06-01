# Foreign trade by goods category

- **id**: ch_snb_ausshawarm
- **concept**: External sector / Foreign trade
- **canonical**: yes
- **source**: Swiss National Bank
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2012-01 .. 2026-03
- **series**: 175
- **updated**: 2026-03 (latest observation; PublishingDate in CSV header is the freshness signal)

## What is special
Switzerland's monthly foreign trade split by goods category, the canonical trade
series in the catalog. It is a three-way cube: trade flow (exports / imports /
balance) times a deep goods hierarchy times a value-or-change axis. The goods axis
goes two levels deep (e.g. group `CHEM` -> `C21` pharma preparations, `C20`
chemicals), which surfaces the pharma and watches drivers that dominate Swiss
exports (`C21`, `C2652`). The quirky axis is `D2`: it mixes a level (`WMF` value in
CHF millions) with two year-on-year % change variants (`N` nominal, `R` real) under
one dimension, so the same `value` column means CHF millions in some rows and a
percent change in others. Despite a 2012 catalog start, the CHF-million level rows
begin 2012 while the %-change rows begin 2013 (a year of base needed first).

## Access
- **type**: SNB cube API
- **endpoint**: `GET https://data.snb.ch/api/cube/ausshawarm/data/json/en`
- **call**: `snb_fetch("ausshawarm", title = "Foreign trade by goods category")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`; map each `timeseries.metadata.key`
  `{...}` codes positionally onto dim ids `D0`,`D1`,`D2`.
- Recurse the nested `dimensionItems` to flatten code -> label and rebuild the
  goods hierarchy tree; grouping nodes (`data: false`, e.g. `CHEM`, `ME`, `MET`)
  carry no rows.
- Monthly dates are period starts; coerce to ISO `Date`.
- JSON+CSV only, no JSON-stat; no SA toggle.

## Dimensions
- `D0` (Overview): `A` exports, `E` imports, `H` trade surplus/deficit.
- `D1` (Goods category): `GT` total plus leaf goods codes nested under non-data
  groups, e.g. `C21` pharma preparations, `C20` chemicals, `C26` computer/optical,
  `C2652` watches and clocks, `C24/C25` metals, `C10..C12` food/beverages/tobacco,
  `C29/C30` vehicles, `B05/B06/C19/D35` energy, `C13..C15` textiles/apparel/leather.
- `D2` (Value/Change): `WMF` value in CHF millions (level); `N` nominal and `R` real
  are the two YoY %-change leaves under the non-data group `D2_1`.

## Display
- **split**: D1
- **single-select**: D0, D2
- **default**: D0=A, D1=GT, D2=WMF
- **transform**: level
- **seasonal adjustment**: n/a (no SA dimension or SA codes). D2 mixes a level
  (WMF, CHF millions) with YoY %-change leaves (N nominal, R real); the level
  WMF is the headline, so transform stays level rather than yoy. Pick N/R on D2
  to read the published year-on-year change instead.

## Caveats / simplifications
- Mixed semantics on `D2`: filter to `WMF` for levels, to `N`/`R` for growth rates;
  do not aggregate across them.
- Default preview series is `D0 = A`, `D1 = A01`, `D2 = WMF`.

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube_id `ausshawarm`).
Datasheet 2026-06-01; parser verified 2026-06-01 (28,285 rows, 175 series).
