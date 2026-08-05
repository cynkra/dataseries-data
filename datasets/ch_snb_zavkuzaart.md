# Customer payments at banks – Outgoing payments, by type of order

- **id**: ch_snb_zavkuzaart
- **title**: Customer payments (outgoing) | de: Kundenzahlungen (ausgehend) | fr: Paiements des clients (sortants) | it: Pagamenti dei clienti (in uscita)
- **concept**: Payment systems / Payments & cash
- **canonical**: no (alternate for Payments & cash; the credit-transfer / direct-debit view of the `zave*` family, complementary to the card cubes)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2012-03 .. 2026-03
- **series**: 90
- **updated**: 2026-03 (latest published period)

## What is special
How Swiss customers send money without a card: credit transfers, direct debits and standing orders, paper versus electronic.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `zavkuzaart`
- **endpoint**: `https://data.snb.ch/api/cube/zavkuzaart/data/json/en`
- **call**: `snb_fetch("zavkuzaart", title = "Customer payments at banks – Outgoing payments, by type of order")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube id `zavkuzaart`.
- `metadata$key` `{...}` holds three codes in `dim_order`; split on `,` into `D0,D1,D2`.
- Per `values`: drop nulls, ISO date, numeric value. JSON+CSV only, no SA toggle.
- Keep `data: true` leaves; the `D1` tree has many grouping-only nodes (`UEB`,
  `UEB_PBA`, `UEB_NPB`) that carry no rows.

## Dimensions
- `D0` (Outgoing payments): `T` total, `ZIB` payments between resident banks, `ZAB`
  payments involving a non-resident bank.
- `D1` (Type of order): `T` total; transfers `UEB` (deepest branch) split into
  `UEB_PBA_T` paper-based total, `UEB_NPB_T` non-paper-based total and its leaves
  `UEB_NPB_EBA` eBanking, `UEB_NPB_DKA` direct channels, `UEB_NPB_DAA` standing order,
  `UEB_NPB_U` other; plus `LAS` direct debits and `UZE` other outgoing payments.
- `D2` (Transactions and amount): `ATA` transactions in thousands, `BET` amount in CHF
  thousands, `BPT` amount per transaction in CHF.
- Default item: `D0=T, D1=T, D2=ATA`.

## Display
- **split**: D1
- **single-select**: D0, D2
- **default**: D0=T, D1=T, D2=BET
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes this cube raw; no SA dimension)

## Hierarchy
`T Total` = transfers + direct debits + other outgoing payments, but SNB lists it as their sibling. Nest the order types under it.
- derive: under-root T

## Caveats / simplifications
- `D1` mixes leaf totals (`UEB_T`, `UEB_PBA_T`, `UEB_NPB_T`) with finer leaves; summing
  across `D1` double-counts. Use a single level of the order-type tree at a time.
- `BPT` (amount per transaction) is a ratio, not an additive flow.
- Coverage begins 2012-03; there is no pre-2012 history in this cube.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube list + title from `R/snb_cubes.tsv`).
Datasheet authored 2026-06-01; parser verified 2026-06-01 (4,932 data rows, 90 series).
