# Swiss balance of payments – Current account – Quarter

- **id**: ch_snb_bopcurrq
- **title**: Balance of payments: current account | de: Zahlungsbilanz: Leistungsbilanz | fr: Balance des paiements : compte courant | it: Bilancia dei pagamenti: conto corrente
- **concept**: External sector / Balance of payments
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1983-Q1 .. 2025-Q4
- **series**: 116
- **updated**: 2025-Q4 (latest observation; SNB publishes ~3 months in arrears)

## What is special
The detailed current account of the Swiss balance of payments, quarterly back to
1983. This is the canonical BoP series for the current-account concept. Its value is
the deep component hierarchy on `D0`: goods (foreign trade, non-monetary gold,
merchanting), services (transport split into passengers/freight/other, tourism,
insurance, financial services, licence fees, R&D, business services), primary income
(labour income plus investment income broken into direct/portfolio/other/reserves
with dividends, reinvested earnings and interest), and secondary income. Crossed with
the `D1` accounting entry (Receipts / Expenses / Net), so one component such as
"Financial services" is three series. Switzerland's structural current-account surplus
and the large role of merchanting and investment income are visible here. Grouping
nodes (`data:false`, e.g. "Goods", "Services") carry no observations and are dropped;
only `data:true` leaves and totals appear in the CSV.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `bopcurrq`
- **endpoint**: cube id `bopcurrq` (id minus the `ch_snb_` prefix)
- **call**: `snb_fetch("bopcurrq", title = "Swiss balance of payments – Current account – Quarter")`, which issues
  `GET https://data.snb.ch/api/cube/bopcurrq/dimensions/en` and
  `GET https://data.snb.ch/api/cube/bopcurrq/data/json/en`

## Parsing recipe
- Two endpoints. `/dimensions/en` gives the dimension labels and the nested
  `dimensionItems` hierarchy; `/data/json/en` gives the `timeseries`, each carrying a
  `metadata.key` like `...{<code>,<code>}` whose brace-delimited codes are the
  per-dimension item ids in `dim_order`.
- `.snb_key_codes` extracts the codes from each key and maps them positionally to
  `D0`, `D1`. Observations with `value == null` are skipped. `date` is ISO already.
- Flatten the hierarchy with `.snb_flatten` (code -> label) and `.snb_hierarchy`
  (nested tree). The tidy long table is keyed by `D0`, `D1`, `date`, `value`.
- No seasonal-adjustment toggle exists at SNB; values are as published (raw).
- Freshness signal is the `PublishingDate` line in the CSV variant of the cube; the
  stored file keeps only the latest observation date as the proxy.

## Dimensions
- `D0` Component: the current-account breakdown. Leaf codes include `T0/T1`
  (foreign-trade totals), `DGZ` non-monetary gold, `T3` merchanting, services leaves
  (`T6` tourism, `F` financial services, `L1` licence fees, ...), primary income
  (`A` labour income, direct-investment `DDIV/DRE/DZ`, portfolio `P0DP/P0ST`), and
  secondary income (`OH` public sector, `IM` immigrant transfers). `PMTWV` is a pro
  memoria merchanting line.
- `D1` Accounting entry: `E` Receipts, `A` Expenses, `S` Net. Default view `A,A`.

## Display
- **split**: D0
- **single-select**: D1
- **default**: D0=L0, D1=S
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes raw values, no SA dimension)

## Caveats / simplifications
- Grouping nodes (`data:false`) hold no data and never reach the CSV; the hierarchy is
  preserved in meta so a UI can still render the tree.
- Many leaves repeat the label "Total" under different parents; the code, not the
  label, is the identity.

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube `bopcurrq`, topic
"Balance of payments"). Datasheet authored 2026-06-01; parser verified 2026-06-01
(18,868 rows, 116 series).
