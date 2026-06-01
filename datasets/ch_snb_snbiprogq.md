# SNB conditional inflation forecast (quarterly)

- **id**: ch_snb_snbiprogq
- **concept**: SNB policy & forecasts / Conditional inflation forecast
- **canonical**: yes (quarterly horizon; annual `ch_snb_snbiproga` kept alongside)
- **source**: Swiss National Bank
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 2001-01-01 .. 2028-10-01
- **series**: 176
- **updated**: 2026-03

## What is special
The quarterly resolution of the SNB's conditional inflation forecast, and the
fuller of the two forecast cubes. Like the annual cube, D0 is a **forecast vintage**
(one item per quarterly monetary-policy assessment since 2004), each labelled with
its conditioning policy rate; the label text traces the Libor-to-policy-rate
instrument change at mid-2019, the negative-rate era and the 2022-2024 hikes. What
sets the quarterly cube apart: the stored data start in **2001** (earlier than the
annual cube's 2004) because the D1 `BI` "observed inflation" path is carried back
further, and the default view here is `BI` rather than the forecast. So this cube
lets you align each historical forecast fan against the realised quarterly CPI it
was later measured against. It also reaches further forward (end 2028-10) at quarterly
steps. Values are future-dated by construction, since each vintage projects ahead.

CONCEPT-UNIVERSE keeps both this and the annual `snbiproga` because they serve
different horizons; this quarterly one is the higher-resolution forecast view.

## Access
- **type**: SNB cube API
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
