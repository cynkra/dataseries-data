# Switzerland's external debt - Quarter

- **id**: ch_snb_auverdeptq
- **title**: External debt
- **concept**: External sector / International investment position
- **canonical**: no (external-debt cut of the IIP; companion to canonical overview `auvekomq`)
- **source**: Swiss National Bank
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1999-Q4 .. 2025-Q4
- **series**: 38
- **updated**: 2025-Q4 (latest observation; PublishingDate in CSV header is the freshness signal)

## What is special
Switzerland's gross external debt: the liabilities side of the external balance sheet,
the IMF/SDDS external-debt presentation. It complements the `auvekomq` IIP overview
and `auvercurrq` currency cut, focusing only on debt liabilities. Starts later than
its companions (1999-Q4) because the standardized external-debt template post-dates
the IIP series. The whole cube rides on a single `Overview` dimension whose hierarchy
encodes two cross-classifications at once: sector (public, SNB, banks, other sectors,
direct-investment loans) and maturity (short-term / long-term), each further split
into debt securities vs other liabilities. So one flat dim id (`D0`) carries a
sector x maturity x instrument tree expressed entirely as codes. Values are
CHF-million stocks at end of quarter.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `auverdeptq`
- **endpoint**: `GET https://data.snb.ch/api/cube/auverdeptq/data/json/en`
- **call**: `snb_fetch("auverdeptq", title = "Switzerland's external debt - Quarter")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`; map each `timeseries.metadata.key`
  `{...}` codes positionally onto dim id `D0`.
- Recurse `dimensionItems` to flatten code -> label and rebuild the tree; the many
  `D0_*` codes are non-data grouping nodes (sector/maturity headings) and the `T*`,
  `S*`, `V*`, `GTA/GDA/GSA` codes are the data leaves.
- Quarterly dates are period starts; coerce to ISO `Date`.
- JSON+CSV only, no JSON-stat; no SA toggle.

## Dimensions
- `D0` (Overview): a sector x maturity x instrument tree on one axis. Top total `T0`;
  total-level sector split `OH` public, `N` SNB, `B` banks, `US` other sectors;
  total-level maturity split `K` short-term, `L` long-term. Per-sector blocks
  (`D0_1` public, `D0_2` SNB, `D0_3` banks, `D0_4` other sectors) repeat
  short-/long-term `Total`/`Debt securities`/`Liabilities` (`T1..T12`, `S0..S7`,
  `V0..V7`). `D0_5` direct-investment loans splits liabilities by counterparty:
  `GTA` subsidiaries, `GDA` direct investors, `GSA` fellow companies abroad.

## Display
- **split**: D0
- **single-select**:
- **default**: D0=T0
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube has no seasonal-adjustment dimension)

## Caveats / simplifications
- Stocks in CHF millions, end of quarter; gross external debt (liabilities only).
- Reused leaf labels (`Total`, `Debt securities`, `Liabilities`) recur under every
  sector/maturity block; meaning depends on the parent group, so keep the code, not
  just the label.
- Default preview series is `D0 = B` (banks total).

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube_id `auverdeptq`).
Datasheet 2026-06-01; parser verified 2026-06-01 (3,785 rows, 38 series).
