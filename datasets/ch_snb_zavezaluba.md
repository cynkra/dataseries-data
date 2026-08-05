# Payments and cash withdrawals

- **id**: ch_snb_zavezaluba
- **title**: Payments and cash withdrawals | de: Zahlungen und Bargeldbezüge | fr: Paiements et retraits d'espèces | it: Pagamenti e prelievi di contante
- **concept**: Payment systems / Payments & cash
- **canonical**: no (alternate for Payments & cash; the flow cube of the `zave*` family, paired with the stock cube `zavezaka`)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2005-01 .. 2026-03
- **series**: 113
- **updated**: 2026-03 (latest published period)

## What is special
What Swiss card payments are spent on and where, in shops or online, at home or abroad, plus cash withdrawn at ATMs.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `zavezaluba`
- **endpoint**: `https://data.snb.ch/api/cube/zavezaluba/data/json/en`
- **call**: `snb_fetch("zavezaluba", title = "Payments and cash withdrawals")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube id `zavezaluba`.
- `metadata$key` `{...}` holds five codes in `dim_order` order; split on `,` into
  `D0,D1,D2,D3,D4`.
- Per `values`: drop nulls, ISO date, numeric value. JSON+CSV only, no SA toggle.
- Keep `data: true` leaves only; the grouping nodes (`Z`, `PG`, `B`) carry no rows.

## Dimensions
- `D0` (Payments/Cash withdrawals): `ZT` payments total, `PGT` card-present total,
  `PGKL` of which contactless, `DG` card-not-present, `BT` cash withdrawals total,
  `BE` of which enhanced coverage at the card-issuing bank.
- `D1` (Payment cards): `K` credit, `D` debit, `EG` e-money.
- `D2` (Card origin): `IZ` domestic, `AZ` foreign.
- `D3` (Place of transaction): `II` domestic, `IA` foreign.
- `D4` (Transactions and amount): `TT` transactions in thousands, `BMF` amount in CHF
  millions, `BTF` amount per transaction in CHF.
- Default item: `D0=BT, D1=D, D2=AZ, D3=II, D4=BMF`.

## Display
- **split**: D0
- **single-select**: D1, D2, D3, D4
- **default**: D0=ZT, D1=D, D2=IZ, D3=II, D4=BMF
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes this cube raw; no SA dimension)

## Caveats / simplifications
- Not every cell of the 6x3x2x2x3 grid exists; SNB only publishes meaningful crosses,
  so the cube is sparse and the 113 series do not fill the full Cartesian product.
- `PGKL` (contactless) and `BE` (enhanced cash coverage) start mid-2017, so those
  series are short relative to the 2005 base.
- `BTF` (amount per transaction) is a ratio of the other two metrics, not an
  independent flow; do not sum it.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube list + title from `R/snb_cubes.tsv`).
Datasheet authored 2026-06-01; parser verified 2026-06-01 (19,462 data rows, 113 series).
