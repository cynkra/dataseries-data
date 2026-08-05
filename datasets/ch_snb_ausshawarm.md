# Foreign trade by goods category

- **id**: ch_snb_ausshawarm
- **title**: Foreign trade by goods category | de: Aussenhandel nach Warengruppe | fr: Commerce extérieur par catégorie de marchandises | it: Commercio estero per categoria di merci
- **concept**: External sector / Foreign trade
- **canonical**: yes
- **featured**: Foreign trade
- **source**: snb
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
exports (`C21`, `C2652`). The quirky axis is `D2` "Value/Change": the source nests a
level (`WMF` value in CHF millions) with two year-on-year %-change leaves (`N` nominal,
`R` real) under one dimension. The nominal change `N` is exactly the YoY % of `WMF`, so
it is dropped as redundant with the app's YoY toggle; the real change `R` (price-deflated,
not recomputable from the value) is kept. That leaves `D2` = {`WMF` nominal value, `R`
real change} — two genuinely different series, so the `value` column still means CHF
millions for `WMF` and a percent change for `R`. Despite a 2012 catalog start, the
CHF-million level rows begin 2012 while the %-change rows begin 2013 (a year of base
needed first).

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `ausshawarm`
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
- `D2` (Value/Change): `WMF` value in CHF millions (level) and `R` real YoY %-change,
  the latter under the non-data group `D2_1`. The nominal YoY %-change `N` is dropped
  (it equals the YoY of `WMF`, reproduced by the app's YoY toggle).

## Display
- **split**: D1
- **single-select**: D2
- **default**: D0=A, D1=GT, D2=WMF
- **transform**: level
- **seasonal adjustment**: n/a (no SA dimension or SA codes). D2 mixes a level
  (WMF, CHF millions) with the real YoY %-change leaf (R); the level WMF is the
  headline, so transform stays level rather than yoy. Pick R on D2 for the real
  change, or the YoY toggle on WMF for the nominal change.

## Hierarchy
SNB lists `GT Total` as a sibling of the goods groups; nest the groups (and the
ungrouped goods C2652/C22/C17) under Total so the picker reads Total → category →
product. The category nodes (CHEM, ME, MET, NFG, FZ, EN, TB) carry no series of their
own in the SNB cube — only `GT` and the individual goods are published — so they stay
non-selectable grouping headers, now correctly placed under Total.
- derive: under-root GT

## Caveats / simplifications
- Mixed semantics on `D2`: `WMF` is a CHF-million level, `R` is a real % change;
  do not aggregate across them. The redundant nominal change (`N`) is dropped — use
  the app's YoY toggle on `WMF` for it.
- Default preview series is `D0 = A`, `D1 = A01`, `D2 = WMF`.

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube_id `ausshawarm`).
Datasheet 2026-06-01; parser verified 2026-06-01 (28,285 rows, 175 series).
