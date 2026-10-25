# Swiss balance of payments, financial account (quarterly)

- **id**: ch_snb_bopcapbalq
- **title**: Balance of payments: financial account | de: Zahlungsbilanz: Kapitalbilanz | fr: Balance des paiements : compte financier | it: Bilancia dei pagamenti: conto finanziario
- **concept**: External sector / Balance of payments
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1985-01 .. 2025-10
- **series**: 62
- **updated**: 2025 Q4 release (PublishingDate in CSV header)

## What is special
Cross-border investment flows in and out of Switzerland: direct, portfolio and other investment plus reserve assets, quarterly.

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

## Labels
- **units**: CHF millions | de: Mio. CHF | fr: Millions de CHF | it: Milioni di CHF

## Display
- **split**: D1
- **single-select**: D0
- **default**: D1=KD, D0=S
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes raw values, no SA dimension)

The default opens on the headline net financial account including derivatives
(`D1=KD`, `D0=S` Net; 166 quarters, 1985Q1 .. 2026Q2). The total `T0` exists only for
the gross entries `NA` and `NP`, never for the net `S`, so `T0` with `S` returns no rows.
`S` is populated for just six components (`KD`, `P`, `D0`, `D2`, `UI`, `W1`).

## Hierarchy
`T0 Total` is the sum of the investment categories (direct, portfolio and other investment, reserve assets; IMF BPM6), shipped as their sibling; nest them under it (`T0 = T1 + T2 + T4 + T7`). `KD` (financial account including derivatives) is the total of the separate `D1_6` summary (`KD = D0 + P + D2 + UI + W1`, with derivatives `D2`, which the `T0` categories do not include), so `D1_6` stays its own branch beside `T0`, following the cube's own pattern of a group holding its total plus its components. `KD` and `D1_6` are not part of `T0`.
- T0
  - D1_1
    - T1
    - B0
    - RE
    - K0
  - D1_2
    - T2
    - S0
      - T25
      - KFR
      - LFR
    - D1_2_2
      - T3
      - A
      - K1
  - D1_3
    - T4
    - D1_3_1
      - T5
      - N0
      - B1
        - T55
        - FGB
        - VGB
        - VGK
      - OH0
      - US0
    - D1_3_2
      - T6
      - N1
      - B2
        - T65
        - FGK
      - OH1
      - US1
    - UNA
    - UNP
  - D1_4
    - T7
    - G
    - RIWF
    - S1
    - D1_4_4
      - T8
      - W0
      - BE
    - U
- D1_6
  - KD
  - D0
  - P
  - D2
  - UI
  - W1

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

## What is special (de)
Grenzüberschreitende Investitionsströme in die Schweiz und aus ihr heraus: Direkt-, Portfolio- und übrige Investitionen sowie Währungsreserven, vierteljährlich.

## What is special (fr)
Flux d'investissement transfrontaliers vers et depuis la Suisse : investissements directs, de portefeuille et autres, plus les réserves monétaires, par trimestre.

## What is special (it)
Flussi d'investimento transfrontalieri verso e dalla Svizzera: investimenti diretti, di portafoglio e altri, più le riserve monetarie, per trimestre.
