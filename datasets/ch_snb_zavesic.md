# Swiss Interbank Clearing (SIC) - payment transactions

- **id**: ch_snb_zavesic
- **title**: Interbank clearing (SIC)
- **concept**: Payment systems / Payments & cash
- **canonical**: no (alternate within Payments & cash; one of several `ch_snb_zave*` payment series)
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1987-07 .. 2026-04
- **series**: 14
- **updated**: 2026-04 (use API PublishingDate header for exact day)

## What is special
Activity in SIC, Switzerland's real-time gross settlement system for interbank
CHF payments, monthly from 1987. This is the deepest hierarchy of the six cubes
(four nesting levels) and the one whose dimension codes are partly numeric. Two
views sit side by side. The headline block (`D0_0`) gives counts, turnover and a
turnover ratio, each as a total (`T0`/`T1`), a daily maximum (`MT0`/`MT1`/`MT2`)
and an average per working day (`DA0`/`DA1`/`DA2`). The by-size block (`D0_1`)
breaks the same number of transactions and turnover into three payment-size bands,
encoded with the quirky numeric ids `149990` / `50009999990` / `1MM0` (and the
parallel `...91`/`1MM1` for turnover). Those ids read as the band edges:
`149990` = CHF 1-4,999, `50009999990` = CHF 5,000-999,999, `1MM0` = CHF 1 million
and larger. Counts are number of transactions; turnover is in CHF million. The
long history makes it a useful proxy for the digitisation and growth of Swiss
interbank payment volume.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `zavesic`
- **endpoint**: `https://data.snb.ch/api/cube/zavesic/data/json/en`
- **call**: `snb_fetch("zavesic", title = "Swiss Interbank Clearing (SIC) - payment transactions")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`.
- `metadata.key` is `EPB@SNB.zavesic{<D0>}`; one dimension despite the deep
  hierarchy (the nesting is grouping, not extra key positions). Long tibble of
  `D0,date,value`. Dates -> first of month. Drop null values.
- The size-band codes are stored verbatim as strings (`149990`, `50009999990`,
  `1MM0`, and the `...1` turnover variants). Do not coerce them to numbers; they
  are opaque ids, not magnitudes. Read the band ranges from the level labels.
- Units differ by code: number of transactions vs CHF million turnover vs turnover
  ratio. No separate unit column; read from the `D0` label.

## Dimensions
- `D0` (Overview), two groups:
  - Transactions, turnover, turnover ratio:
    - Number of transactions: `T0` total, `MT0` daily maximum, `DA0` average per
      working day.
    - Turnover (CHF million): `T1` total, `MT1` daily maximum, `DA1` average per
      working day.
    - Turnover ratio: `MT2` daily maximum, `DA2` average per working day.
  - By size of payments:
    - Number of transactions by band: `149990` CHF 1-4,999, `50009999990`
      CHF 5,000-999,999, `1MM0` CHF 1 million and larger.
    - Turnover by band (CHF million): `149991`, `50009999991`, `1MM1`
      (same three bands).

## Display
- **split**: D0
- **single-select**: (none; D0 is the only dimension)
- **default**: D0=T0
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes this cube raw; no SA dimension)

## Caveats / simplifications
- All grouping nodes (`D0_0`, `D0_0_0`, `D0_0_1`, `D0_0_2`, `D0_1`, `D0_1_0`,
  `D0_1_0_0`, `D0_1_1`, `D0_1_1_0`) are labels only; the 14 stored series are the
  leaves. The four-level structure survives only in the meta `hierarchy`, not in
  separate columns.
- The two views overlap: the by-size counts re-cut the same transactions that the
  headline `T0` totals; summing across both groups double counts.
- The turnover-ratio leaves (`MT2`, `DA2`) have no "total" sibling, unlike counts
  and turnover; a ratio total would be meaningless, so only max and daily-average
  exist.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `zavesic`, title from `R/snb_cubes.tsv`,
topic "Payment systems"). Datasheet authored 2026-06-01.
