# E-money - loading and float

- **id**: ch_snb_zavegelade
- **title**: E-money | de: E-Geld | fr: Monnaie électronique | it: Moneta elettronica
- **concept**: Payment systems / Payments & cash
- **canonical**: no (alternate within Payments & cash; one of several `ch_snb_zave*` payment series)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2014-12 .. 2026-03
- **series**: 4
- **updated**: 2026-03 (use API PublishingDate header for exact day)

## What is special
Loading and float of e-money on Swiss prepaid and stored-value payment cards.
Loading is the flow of top-ups, reported as a transaction count, a total amount
and an average per transaction; float is the balance left sitting on cards. The
flow and its corresponding stock in one short table.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `zavegelade`
- **endpoint**: `https://data.snb.ch/api/cube/zavegelade/data/json/en`
- **call**: `snb_fetch("zavegelade", title = "E-money - loading and float")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`.
- `metadata.key` is `EPB@SNB.zavegelade{<D0>}`; one dimension. Long tibble of
  `D0,date,value`. Dates -> first of month. Drop null values.
- Units differ per code (thousands of transactions vs CHF millions vs CHF per
  transaction); there is no separate unit column, so read units from the `D0`
  label.

## Dimensions
- `D0` (Overview):
  - Loading (domestic payment cards): `TT` transactions in thousands, `BMF0`
    amount in CHF millions, `BTF` amount per transaction in CHF.
  - Float (domestic payment cards): `BMF1` amount in CHF millions.

## Display
- **split**: D0
- **single-select**:
- **default**: D0=BMF0
- **transform**: level
- **seasonal adjustment**: n/a (no seasonal-adjustment dimension). Opens on the
  loading flow in CHF millions (`BMF0`) as the headline; the transaction count
  (`TT`), per-transaction average (`BTF`) and outstanding float (`BMF1`) are
  available as additional lines in the split.

## Caveats / simplifications
- The grouping nodes `D0_0` Loading / `D0_0_0` Domestic payment cards and `D0_1`
  Float / `D0_1_0` Domestic payment cards are labels only; the 4 stored series are
  the leaves. The loading-vs-float distinction is implicit in the code and the
  stored `hierarchy`.
- `BTF` is an average (CHF per transaction) and must not be summed; `BMF0` and
  `BMF1` are different concepts (flow loaded vs outstanding float) and do not add up
  to anything meaningful together.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `zavegelade`, title from
`R/snb_cubes.tsv`, topic "Payment systems"). Datasheet authored 2026-06-01.
