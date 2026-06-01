# Yields on bond issues (daily)

- **id**: ch_snb_rendoblid
- **concept**: Interest rates & yields / Bond yields
- **canonical**: yes
- **source**: Swiss National Bank
- **license**: snb (free reuse, attribution required)
- **frequency**: daily
- **coverage**: 1988-01-04 .. 2025-07-31
- **series**: 22
- **updated**: 2025-07-31

## What is special
The canonical daily Swiss bond-yield series. Its headline leaf, 10-year
Confederation yield (`10J0`), is the standard Swiss long-rate benchmark, daily back
to 1988. The cube packs two distinct blocks under a single dimension D0: a maturity
term structure for Confederation issues (1J through 30J, including 15J) plus a 10y
EUR German-government leaf, and a separate 8-year-maturity cross-section of CHF bond
issues by borrower category (Confederation, cantons, mortgage-bond institutions,
banks, manufacturing/trade) and by rating for foreign borrowers (AAA/AA/A). So one
flat dimension actually encodes a curve and an issuer panel at once.

The CONCEPT-UNIVERSE picks this daily cube as canonical and explicitly **drops the
monthly roll-up `rendoblim`** under the native-frequency rule (keep the higher
frequency). The related spot-rate cube `rendeiduebd` is kept as a labelled
alternate. Note the duplicate 10y labels are disambiguated by code: `10J0` is the
Confederation 10y, `10J1` the EUR 10y.

## Access
- **type**: SNB cube API
- **endpoint**: `https://data.snb.ch/api/cube/rendoblid/data/json/en`
- **call**: `snb_fetch("rendoblid")` (cube_id = id minus `ch_snb_` prefix)

## Parsing recipe
- Fetch `/dimensions/en` (labels + nested hierarchy) and `/data/json/en` (values).
- Each series' `metadata.key` carries the D0 code in `{...}`; split on commas, pair
  positionally with `dim_order` (here a single dimension D0).
- Emit long rows `D0, date, value`; `date` ISO, `value` numeric.
- Drop the grouping nodes (`data: false`): `D0_0`, `D0_0_0`, `D0_0_1`, `D0_1`,
  `D0_1_0`, `D0_1_1` are hierarchy headers, not leaves.
- No SA toggle; JSON+CSV only (no JSON-stat). Live CSV `PublishingDate` = freshness.

## Dimensions
- `D0` (Overview), two branches:
  - Confederation/EUR curve: `1J`..`9J`, `10J0` (10y CHF Confederation, the default
    benchmark), `15J`, `20J`, `30J`; `10J1` = 10y EUR German government issues.
  - CHF issues by borrower at 8y maturity: `E` Confederation, `K` cantons, `P`
    mortgage bond institutions, `GK` commercial (incl. cantonal) banks, `IKH`
    manufacturing (incl. power plants) and trade; foreign CHF issues by rating
    `AAA`, `AA`, `A`.

## Display
- **split**: D0
- **single-select**: n/a (single dimension)
- **default**: D0=10J0
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube has no SA dimension)

## Caveats / simplifications
- These are par yields, not the zero-coupon spot rates of `rendeiduebd`; do not mix.
- The two duplicate "10 years" labels are only distinguishable by their codes
  (`10J0` vs `10J1`); rely on the code, not the label text.
- Monthly equivalent `rendoblim` is intentionally not ingested (roll-up of this).

## Provenance
Script: `R/source_snb.R::snb_fetch`, cube from `R/snb_cubes.tsv` (`rendoblid`,
topic "Interest rates"). Datasheet authored 2026-06-01; parser verified 2026-06-01
(155,268 rows, 22 series).
