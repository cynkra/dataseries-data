# SNB conditional inflation forecast (quarterly)

- **id**: ch_snb_snbiprogq
- **title**: Inflation forecast (SNB) | de: Inflationsprognose (SNB) | fr: Prévision d'inflation (BNS) | it: Previsione d'inflazione (BNS)
- **concept**: Prices / Inflation forecast
- **canonical**: yes (sole canonical for this concept; an annual view is derived on demand by calendar-year averaging the quarterly forecast)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 2001-01-01 .. 2028-10-01
- **series**: 176
- **updated**: 2026-03

## What is special
The SNB's conditional inflation forecast, one path per quarterly monetary-policy
assessment, each labelled with the policy rate it assumes. Alongside the forecasts
it carries the observed inflation path, so any historical forecast can be aligned
against the inflation that actually followed. Values extend into the future by
construction.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `snbiprogq`
- **endpoint**: `https://data.snb.ch/api/cube/snbiprogq/data/json/en`
- **call**: `snb_fetch("snbiprogq")` (cube_id = id minus `ch_snb_` prefix)

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`.
- Two dimensions D0 (vintage) and D1 (series type). The `metadata.key` `{...}` gives
  both codes in `dim_order`; split on commas, pair positionally. Emit
  `D0, D1, date, value`; `date` ISO (first of quarter), `value` numeric (percent).
- Drop the year grouping nodes in D0 (`2004`, `2005`, ...; `data: false`); keep the
  dated assessment leaves (`M`/`J`/`S`/`D` + year + policy code).
- No SA toggle; JSON+CSV only. Live CSV `PublishingDate` = freshness signal.

## Dimensions
- `D0` (Assessment of): one leaf per quarterly assessment vintage, prefix `M`=March,
  `J`=June, `S`=September, `D`=December, then year, then the conditioning policy rate
  encoded in the suffix (`PL...` Libor era, `PP.../POFFP` SNB-policy-rate era). Bare
  year codes are grouping headers, not data.
- `D1` (Overview): `BI` observed inflation (the default view, the realised CPI path),
  `P` forecast. Both are populated, so each vintage pairs a forecast fan with the
  observed series.

## Display
- **split**: D0
- **single-select**: D1
- **default**: D0=D2025POFFP, D1=BI
- **transform**: level
- **seasonal adjustment**: n/a
- Opening on the observed-inflation path (`D1=BI`), which is the realised quarterly
  CPI series running back to 2001 and the broadest series in the cube, paired with a
  recent assessment vintage (`D0=D2025POFFP`, December 2025). The vintage dimension is
  the split: each line is one assessment, so the user adds vintages to lay forecast
  fans against the observed path. Bare-year codes (`2004`, ...) are grouping headers
  (`data: false`), never a valid default.

## Caveats / simplifications
- Future-dated rows are expected: forecasts project beyond publication, so `end`
  (2028-10) is a forecast horizon, not a freshness date. Judge recency from the
  latest D0 vintage.
- Earlier start (2001) than the annual cube reflects the `BI` observed-inflation
  history, not earlier forecasts.
- The conditioning policy-rate assumption lives only in the D0 label text; there is
  no separate numeric field for it.

## Provenance
Script: `R/source_snb.R::snb_fetch`, cube from `R/snb_cubes.tsv` (`snbiprogq`, topic
"SNB forecasts"). Datasheet authored 2026-06-01; parser verified 2026-06-01 (2,312
rows, 176 series).
