# Payments and cash withdrawals

- **id**: ch_snb_zavezaluba
- **title**: Payments and cash withdrawals | de: Zahlungen und Bargeldbezüge | fr: Paiements et retraits d'espèces | it: Pagamenti e prelievi di contante
- **concept**: Payment systems / Payments and cash
- **canonical**: no (alternate for Payments and cash; the flow cube of the `zave*` family, paired with the stock cube `zavezaka`)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2005-01 .. 2026-03
- **series**: 113
- **updated**: 2026-03 (latest published period)

## What is special
Card payments and cash withdrawals by card type, card origin (Swiss or foreign cards) and place of transaction (in Switzerland or abroad), as transaction counts and CHF amounts. Foreign cards appear only for transactions in Switzerland. There is no breakdown by what the money is spent on.

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

## Labels
- dim: D4
  - **units** TT: Thousands of transactions | de: Tausend Transaktionen | fr: Milliers de transactions | it: Migliaia di transazioni
  - **units** BMF: CHF millions | de: Mio. CHF | fr: Millions de CHF | it: Milioni di CHF
  - **units** BTF: CHF | de: CHF | fr: CHF | it: CHF

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

## What is special (de)
Kartenzahlungen und Bargeldbezüge nach Kartenart, Herkunft der Karte (Schweizer oder ausländische Karten) und Ort der Transaktion (in der Schweiz oder im Ausland), als Transaktionszahlen und Beträge in CHF. Ausländische Karten erscheinen nur für Transaktionen in der Schweiz. Eine Gliederung nach Verwendungszweck gibt es nicht.

## What is special (fr)
Paiements par carte et retraits d'espèces selon le type de carte, l'origine de la carte (suisse ou étrangère) et le lieu de la transaction (en Suisse ou à l'étranger), en nombre de transactions et en montants en CHF. Les cartes étrangères n'apparaissent que pour les transactions en Suisse. Il n'existe pas de ventilation selon l'objet de la dépense.

## What is special (it)
Pagamenti con carta e prelievi di contante per tipo di carta, origine della carta (svizzera o estera) e luogo della transazione (in Svizzera o all'estero), come numero di transazioni e importi in CHF. Le carte estere compaiono solo per le transazioni in Svizzera. Non esiste una ripartizione per scopo di spesa.
