# Balance sheet items of the SNB (monthly)

- **id**: ch_snb_snbbipo
- **title**: SNB balance sheet | de: SNB-Bilanz | fr: Bilan de la BNS | it: Bilancio della BNS
- **concept**: Money & banking / Monetary aggregates
- **canonical**: no (supporting series under Monetary aggregates;
  `ch_snb_snbmonagg` is canonical)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1996-12-01 .. 2026-04-01
- **series**: 28
- **updated**: 2026-04-01

## What is special
What the Swiss National Bank owns and owes each month. Foreign-currency investments and gold explain the expansion after 2008.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `snbbipo`
- **endpoint**: `https://data.snb.ch/api/cube/snbbipo/data/json/en`
- **call**: `snb_fetch("snbbipo")` (cube_id = id minus `ch_snb_` prefix)

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`.
- Single dimension D0; series `metadata.key` `{...}` gives the D0 code. Emit
  `D0, date, value`; `date` ISO (first of month), `value` numeric (CHF millions).
- Drop grouping nodes `D0_0` (Assets) and `D0_1` (Liabilities); keep the leaves.
- No SA toggle; JSON+CSV only. Live CSV `PublishingDate` = freshness signal.

## Dimensions
- `D0` (Overview), two side-branches:
  - Assets (`D0_0`): `GFG` gold, `D` foreign currency investments (default), `RIWF`
    IMF reserve position, `IZ` intl payment instruments, `W` monetary assistance
    loans, `FRGSF`/`FRGUSD` CHF/USD repo claims, `GSGSF` swap balances vs CHF, `IG`
    domestic money-market claims, `GD` secured loans, `FI` due from domestic
    correspondents, `WSF` CHF securities, `DS` loan to stabilisation fund, `UA`
    other assets, `T0` total assets.
  - Liabilities (`D0_1`): `N` banknotes, `GB` domestic-bank sight deposits, `VB` due
    to Confederation, `GBI` foreign-bank/institution sight deposits, `US` other
    sight liabilities, `VRGSF` CHF repo liabilities, `ES` SNB debt certificates,
    `UT` other time liabilities, `VF` FX liabilities, `AIWFS` SDR counterpart, `SP`
    other liabilities, `RE` provisions and equity, `T1` total liabilities.

## Display
- **split**: D0
- **single-select**: (none; single dimension)
- **default**: D0=T0
- **transform**: level
- **seasonal adjustment**: n/a

## Caveats / simplifications
- `T0` and `T1` are aggregate totals included alongside their components; exclude
  them if summing leaves to avoid double counting.
- Ragged start dates: some items begin after 1996-12; do not read missing early
  values as zero.
- Values are stock levels in CHF millions, end of month.

## Provenance
Script: `R/source_snb.R::snb_fetch`, cube from `R/snb_cubes.tsv` (`snbbipo`, topic
"Money and banking"). Datasheet authored 2026-06-01; parser verified 2026-06-01
(8,699 rows, 28 series).
