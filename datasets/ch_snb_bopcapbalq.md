# Swiss balance of payments, financial account (quarterly)

- **id**: ch_snb_bopcapbalq
- **title**: Balance of payments: financial account
- **concept**: External sector / Balance of payments
- **canonical**: yes
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1985-01 .. 2025-10
- **series**: 62
- **updated**: 2025 Q4 release (PublishingDate in CSV header)

## What is special
The financial account of the Swiss balance of payments, quarterly back to 1985:
the flow side of cross-border investment that the international investment
position (`ch_snb_auversecq`) shows as stocks. The distinctive structure is its
**deep nested hierarchy** under the single Component dimension. The standard BPM6
breakdown is unrolled to several levels: direct investment (equity, reinvested
earnings, debt instruments), portfolio investment (debt securities split
short/long term, equity split shares vs collective schemes), other investment
(currency and deposits and loans, each split by holding sector SNB / banks /
public / other, with "of which" amounts due from/to banks and customers), and
reserve assets (gold, IMF reserve position, SDRs, foreign-currency investments in
securities and deposits). Each component carries a three-way accounting entry:
net acquisition of assets, net incurrence of liabilities, and the net of the two.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `bopcapbalq`
- **endpoint**: `https://data.snb.ch/api/cube/bopcapbalq/data/json/en`
- **call**: `snb_fetch("bopcapbalq", title = "Swiss balance of payments - Financial account - Quarter")`

## Parsing recipe
- `/dimensions/en` for code->label and the multi-level nested `dimensionItems`
  hierarchy; `/data/json/en` for observations.
- `metadata.key` carries the two codes in `dim_order` (`D0,D1`);
  `.snb_key_codes` splits the braces. The Component code in `D1` already encodes
  the position in the hierarchy.
- Keep non-null values, parse `date` (quarter start) to ISO, cast numeric. CHF
  millions (flows over the quarter).
- `PublishingDate` header is the freshness signal. JSON+CSV only, no SA toggle.

## Dimensions
- `D0` Accounting entry: `NA` net acquisition of financial assets, `NP` net
  incurrence of liabilities, `S` net.
- `D1` Component: deeply nested. Many intermediate codes (`D1_1` direct
  investment, `D1_2` portfolio, `D1_3` other investment, `D1_3_1` currency and
  deposits, `D1_4` reserve assets, `D1_6` financial-account summary, etc.) are
  **grouping nodes with `data: false`** and carry no series; the data lives in
  their children. Note repeated label "Total" appears under many parents with
  distinct codes (`T0`..`T8`, `T25`, `T55`, `T65`) keyed by position in the tree.

## Display
- **split**: D1
- **single-select**: D0
- **default**: D1=T0, D0=S
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes raw values, no SA dimension)

## Hierarchy
`T0 Total` is the sum of the financial-account components (direct/portfolio/other investment, reserve assets — IMF BPM6), shipped as their sibling. Nest them under it.
- derive: under-root T0

## Caveats / simplifications
- The flatten step relies on the SNB code, not the label, to disambiguate the
  many "Total" / "Banks" / "Swiss National Bank" entries that recur at different
  nesting levels.
- 62 stored series are the data-bearing leaves; the non-data grouping nodes are
  dropped (no observations attached).
- Flow series (quarterly transactions), not stocks; pair with `ch_snb_auversecq`
  for the position counterpart.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `bopcapbalq`, title/topic from
`R/snb_cubes.tsv`). Datasheet authored 2026-06-01.
