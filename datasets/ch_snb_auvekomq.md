# Switzerland's international investment position - Overview - Quarter

- **id**: ch_snb_auvekomq
- **title**: International investment position | de: Auslandvermögen | fr: Position extérieure | it: Posizione patrimoniale sull'estero
- **concept**: External sector / International investment position
- **canonical**: yes (IIP overview; the by-currency `auvercurrq` and external-debt `auverdeptq` cuts are companions)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1985-Q1 .. 2025-Q4
- **series**: 63
- **updated**: 2025-Q4 (latest observation; PublishingDate in CSV header is the freshness signal)

## What is special
What Switzerland owns abroad and owes abroad, and the net position, as end-of-quarter stocks down to the central bank's reserve assets.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `auvekomq`
- **endpoint**: `GET https://data.snb.ch/api/cube/auvekomq/data/json/en`
- **call**: `snb_fetch("auvekomq", title = "Switzerland's international investment position - Overview - Quarter")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`; map each `timeseries.metadata.key`
  `{...}` codes positionally onto dim ids `D0`,`D1`.
- Recurse `dimensionItems` to flatten code -> label and rebuild the multi-level
  `Component` tree; grouping nodes (`data: false`, e.g. `D1_1`, `D1_2`, `D1_4`,
  `D1_5`) are tree-only.
- Quarterly dates are period starts; coerce to ISO `Date`.
- JSON+CSV only, no JSON-stat; no SA toggle.

## Dimensions
- `D0` (Accounting entry): `A` assets, `P` liabilities, `N` net IIP.
- `D1` (Component): `T0` total plus a deep functional tree. Data leaves include
  direct investment (`T1`, `B0` equity, `K0` debt instruments), portfolio (debt
  securities `S0T/STK/STL`, equity `T3/A/K1`), `D` derivatives, other investment
  (currency & deposits and loans split by SNB / banks / public / other sectors,
  with `FGB/VGB/VGK/FGK` due-from/due-to sub-items, `UA/UP` other assets/liab), and
  reserve assets (`G` gold, `RIWF` IMF reserve position, `S1` SDRs, FX investments
  `W/BE`, `U` other).

## Display
- **split**: D1
- **single-select**: D0
- **default**: D0=N, D1=T0
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube has no seasonal-adjustment dimension)

## Hierarchy
`T0 Total` is the published aggregate of the IIP functional categories (IMF BPM6), shipped flat as a sibling. Nest them under it (the source sub-trees are preserved).
- derive: under-root T0

## Caveats / simplifications
- Stocks, not flows; CHF millions, end of quarter. The many `T*` codes are subtotals
  at different tree depths, so summing leaves across levels double-counts.
- Default preview series is `D0 = A`, `D1 = A` (`A` here is the equity-securities
  shares leaf, not assets; the entry axis is `D0`).

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube_id `auvekomq`).
Datasheet 2026-06-01; parser verified 2026-06-01 (10,056 rows, 63 series).

## What is special (de)
Was die Schweiz im Ausland besitzt und schuldet, samt Nettoposition, als Bestände per Quartalsende bis hin zu den Währungsreserven der Nationalbank.

## What is special (fr)
Ce que la Suisse possède et doit à l'étranger, et la position nette, en stocks de fin de trimestre jusqu'aux réserves monétaires de la banque centrale.

## What is special (it)
Cosa la Svizzera possiede e deve all'estero, e la posizione netta, come stock di fine trimestre fino alle riserve monetarie della banca centrale.
