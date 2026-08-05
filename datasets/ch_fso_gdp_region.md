# Regional GDP (cantons & greater regions)

- **id**: ch_fso_gdp_region
- **title**: Regional GDP
- **concept**: National accounts / Regional GDP
- **canonical**: yes
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 2008 .. 2022
- **series**: 34
- **updated**: 2024-10-28

## What is special
Gross domestic product broken down by **canton** (all 26) and by the **7 greater
regions** (NUTS-2), at current prices in CHF million — the regional decomposition
of the national GDP that the SNB cubes and the SECO national-accounts series do
not carry. Switzerland (the national total) is the root of a single drill-down
tree: **Switzerland → greater region → canton**, so the share of any canton in
its region, or of any region in the country, is one division away. Switzerland is
among the most economically concentrated small economies, and this dataset makes
the Zurich / Lake-Geneva / Northwestern cluster visible at a glance.

## Access
- **type**: fso-dam-excel — FSO DAM Excel asset
- **order number**: je-e-04.02.06.01 (EN; asset 32627406. DE sibling: je-d-04.02.06.01, asset 32627391)
- **call**: `fso_excel_download("je-e-04.02.06.01")` (resolves the current master xlsx)

## Parsing recipe
- Two sheets: `GDP per canton` and `GDP per region`. Each sheet stacks blocks:
  a **current-price levels** block first, then "Change over previous year in %"
  blocks (current-price, then real). We keep **only the first block** (current-price
  CHF-million levels) and stop at the first blank row after it.
- The block is located by HEADER TEXT, never fixed rows: the year header is the
  row whose column-1 cell is `Canton` / `Region`; the value rows start just after
  the `In CHF million, at current prices` subheader and run until the first blank
  column-1 cell (the gap before "Change over previous year").
- Year columns are the header cells beginning with a 4-digit year; the final year
  carries a `p` suffix (`2022p`, provisional), matched out of the raw header text.
  Years → first-of-year ISO date. European number formatting (apostrophe thousands
  separator, comma decimal, nbsp) is stripped.
- Each row is mapped from its English workbook label to a stable code on a single
  `region` dimension: Switzerland → `ch`; the 7 greater regions → slugs
  (`leman`, `mittelland`, `nw`, `zurich`, `east`, `central`, `ticino_r`); the 26
  cantons → official two-letter abbreviations (ZH, BE, …). An unmapped / renamed /
  inserted row fails loud (→ skip + stale flag).
- **Switzerland** appears in both sheets with identical values → taken once (from
  the canton sheet) as `ch`. **Zurich** and **Ticino** are one-canton greater
  regions: each appears as both a greater region (`zurich` / `ticino_r`) and the
  canton (`ZH` / `TI`) with identical values. Both are kept as distinct,
  data-bearing nodes, with the canton nested under its greater region in the
  hierarchy — so they never collide and a canton is never summed into its region.

## Dimensions
- `region`: the geographic unit, organised as a 3-level **hierarchy** —
  Switzerland (`ch`, root) → the 7 greater regions (NUTS-2) → their cantons (the
  26 cantons partition the 7 regions). 34 codes total: 1 country + 7 greater
  regions + 26 cantons. Every node is a real series (not a grouping-only header):
  the country total, each greater region and each canton all have their own GDP
  values, so any node is selectable. Canton → greater-region grouping follows the
  FSO / Eurostat NUTS-2 standard: Lake Geneva = VD/VS/GE; Espace Mittelland =
  BE/FR/SO/NE/JU; Northwestern = BS/BL/AG; Zurich = ZH; Eastern = GL/SH/AR/AI/SG/GR/TG;
  Central = LU/UR/SZ/OW/NW/ZG; Ticino = TI.

## Display
- **split**: region
- **default**: region=ch
- **transform**: level
- **seasonal adjustment**: n/a (annual current-price levels; no SA dimension)

## Caveats / simplifications
- **Nominal only** (current prices, CHF million). The per-capita and real
  (chained-volume) blocks the workbook also publishes are not parsed.
- Regional GDP lags the national accounts by ~2 years (latest = 2022, provisional).
- The 26 cantons sum to Switzerland and the 7 greater regions sum to Switzerland,
  but cantons and regions overlap — **do not sum canton + region** rows together.
  The hierarchy makes the nesting explicit (canton under its region under CH).
- Greater regions follow the FSO/Eurostat NUTS-2 grouping; Zurich and Ticino are
  one-canton regions, hence the duplicated values across the region and canton node.

## Provenance
Script: `R/source_fso_excel_sets.R::fso_excel_ch_fso_gdp_region` (wired in
`R/pipeline.R` via `fso_excel_dataset`). Datasheet authored 2026-06-02; parser
reworked + verified live 2026-06-03 against asset 32627406 to expose a single
hierarchical `region` dimension (CH → greater region → canton; the `level`
dimension was removed). Spot-checks match raw values exactly: Zurich canton
2008 = 135763.7 and 2022 = 164494.8; Geneva 2022 = 61231.3; Ticino 2022 = 36083.6;
Switzerland 2022 = 791087.2.
