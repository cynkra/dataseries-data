# SNB conditional inflation forecast (annual)

- **id**: ch_snb_snbiproga
- **concept**: SNB policy & forecasts / Conditional inflation forecast
- **canonical**: yes (annual horizon; quarterly `ch_snb_snbiprogq` kept alongside)
- **source**: Swiss National Bank
- **license**: snb (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 2004-01-01 .. 2028-01-01
- **series**: 158
- **updated**: 2026-03

## What is special
A forecast cube, not a measurement cube, and that makes its shape unusual. The D0
dimension is a **forecast vintage**: one item per quarterly SNB monetary-policy
assessment (March/June/September/December of each year from 2004), each labelled with
the policy assumption it was conditioned on (e.g. "December 2005 (Forecast with Libor
at 1.00%)"). The label text itself records monetary-policy history: it switches from
"Libor" to "SNB policy rate" around mid-2019 when the SNB changed its instrument, and
tracks the negative-rate era (-0.75%) and the 2022-2024 hiking cycle. Because each
vintage is a separate series, the cube **extends into the future** (end 2028) even
though every value was published in the past: a 2026 assessment forecasts inflation
out several years. The data span runs forward of "today" by design.

This is the conditional inflation forecast that anchors SNB communication. The
annual cube is kept as the canonical low-frequency view; the quarterly cube
`snbiprogq` holds the same forecasts at quarterly resolution and longer horizon.
CONCEPT-UNIVERSE keeps both because they cover different horizons.

## Access
- **type**: SNB cube API
- **endpoint**: `https://data.snb.ch/api/cube/snbiproga/data/json/en`
- **call**: `snb_fetch("snbiproga")` (cube_id = id minus `ch_snb_` prefix)

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`.
- Two dimensions D0 (vintage) and D1 (series type). The `metadata.key` `{...}` gives
  both codes in `dim_order`; split on commas, pair positionally. Emit
  `D0, D1, date, value`; `date` ISO (first of year), `value` numeric (percent).
- Drop the year grouping nodes in D0 (`2004`, `2005`, ...; `data: false`); they are
  hierarchy headers grouping that year's four assessments. Keep the dated leaves
  (`M`/`J`/`S`/`D` + year + policy code, e.g. `D2005PL100P`).
- No SA toggle; JSON+CSV only. Live CSV `PublishingDate` = freshness signal.

## Dimensions
- `D0` (Assessment of): one leaf per quarterly assessment vintage, prefix `M`=March,
  `J`=June, `S`=September, `D`=December, then year, then the conditioning policy rate
  encoded in the suffix (`PL...` Libor era, `PP.../POFFP` SNB-policy-rate era). The
  grouping codes (bare years) are headers, not data.
- `D1` (Overview): `BI` observed inflation, `P` forecast. In this annual cube only
  `P` (forecast) leaves are populated in the stored data.

## Display
- **split**: D0
- **single-select**: D1
- **default**: D0=D2025POFFP, D1=P
- **transform**: level
- **seasonal adjustment**: n/a
- Opening on the forecast path (`D1=P`, the only series populated in this annual
  cube) of a recent, complete assessment vintage (`D0=D2025POFFP`, December 2025).
  The vintage dimension is the split: each line is one assessment's forecast fan, so
  the user adds older/newer vintages to compare how the forecast moved. The bare-year
  hierarchy nodes (`2004`, ...) are grouping headers (`data: false`) and are never a
  valid default.

## Caveats / simplifications
- Future-dated rows are expected: a forecast vintage projects beyond its publication
  date, so `end` (2028) is a forecast horizon, not a data freshness date. Use the
  latest vintage code in D0 to judge recency.
- 158 stored series = vintage x series-type combinations that the SNB actually
  published; coverage per vintage varies (later vintages forecast more years).
- The policy-rate assumption lives only in the D0 label text; there is no separate
  numeric column for it.

## Provenance
Script: `R/source_snb.R::snb_fetch`, cube from `R/snb_cubes.tsv` (`snbiproga`, topic
"SNB forecasts"). Datasheet authored 2026-06-01; parser verified 2026-06-01 (473
rows, 158 series).
