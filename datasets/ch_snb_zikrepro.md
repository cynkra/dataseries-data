# Published interest rates for new transactions

- **id**: ch_snb_zikrepro
- **title**: Published interest rates | de: Publizierte Zinssätze | fr: Taux d'intérêt publiés | it: Tassi d'interesse pubblicati
- **concept**: Interest rates & yields / Money-market rates
- **canonical**: no (alternate; one of the three money-market-rate cubes `zimoma` / `zikredlauf` / `zikrepro`, this one is the published retail rates with the deepest product tree)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1933-01 .. 2026-03
- **series**: 228
- **updated**: 2026-03 (latest published period)

## What is special
Interest rates on new Swiss banking business: mortgages, consumer credit, savings, pensions and term deposits, given as a distribution.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `zikrepro`
- **endpoint**: `https://data.snb.ch/api/cube/zikrepro/data/json/en`
- **call**: `snb_fetch("zikrepro", title = "Published interest rates for new transactions")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube id `zikrepro`.
- `metadata$key` `{...}` holds two codes in `dim_order`; split on `,` into `D0,D1`.
- Per `values`: drop nulls, ISO date, numeric value. JSON+CSV only, no SA toggle.
- `D1` is a deep multi-level tree; keep only `data: true` leaves and drop the many
  grouping nodes (`D1_HYP`, `FVZ`, `FGM`, `LIB`, `D1_PHA`, `D1_3/4/5`, ...). The
  recursive `.snb_flatten` / `.snb_hierarchy` walk handles arbitrary nesting depth.

## Dimensions
- `D0` (Reference values): `M` mean, `025Q` 0.25 quantile, `05Q` median, `075Q` 0.75
  quantile.
- `D1` (Products): deep tree. Mortgages `D1_HYP` -> `MV` variable, `FVZ` fixed by
  maturity year (`11`,`20`,...,`HYP_15`), money-market-linked `FGM` with SARON
  (`SARJ03/05/OBD`) and Libor sub-trees; `D1_BKK` consumer credit; private clients
  `D1_PHA` (payment/savings accounts, pillar 2/3a pension); corporate `D1_FIK`; term
  deposits `D1_3` (>= CHF 100k, by months) and `D1_5` (by years); cash bonds `D1_4` by
  years.
- Default item: `D0=M, D1=S1` (savings deposits, mean).

## Display
- **split**: D1
- **single-select**: D0
- **default**: D0=M, D1=MV
- **transform**: level
- **seasonal adjustment**: n/a (this cube has no seasonal-adjustment dimension)

## Caveats / simplifications
- The product codes are not human-readable maturities; the bare numeric codes (`11`,
  `20`, `31`, ...) are SNB internal ids whose meaning comes only from the `D1` label
  tree (e.g. `11` = fixed mortgage maturity 1 year). Always resolve via the dimension
  labels, never parse the code.
- The same display label ("3", "5", "6") appears under several branches with different
  codes; uniqueness is the code plus its position in the hierarchy, not the label.
- The 1933 start is product-specific; most leaves are far shorter, so series are highly
  unbalanced.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube list + title from `R/snb_cubes.tsv`).
Datasheet authored 2026-06-01; parser verified 2026-06-01 (40,857 data rows, 228 series).
