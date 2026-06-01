# SNB target range (daily)

- **id**: ch_snb_snbband
- **concept**: Money & banking / Monetary aggregates
- **canonical**: no (alternate / supporting series under Monetary aggregates;
  `ch_snb_snbmonagg` is canonical)
- **source**: Swiss National Bank
- **license**: snb (free reuse, attribution required)
- **frequency**: daily
- **coverage**: 2000-01-03 .. 2019-06-12
- **series**: 3
- **updated**: 2019-06-12

## What is special
A small, historically bounded cube that records the SNB's old monetary-policy
operating framework: the **target range for the 3-month CHF Libor**. It carries
three daily series, the upper and lower bound of the announced target range plus the
realised 3-month CHF Libor fixing itself, so you can see where the actual rate sat
inside the band. This is the regime the SNB ran from 2000 until it replaced the
Libor target with the **SNB policy rate** in June 2019, which is exactly why the
series **ends 2019-06-12**: the instrument was discontinued. It is a closed
historical artefact, useful for narrating the pre-policy-rate era (including the
2015 move to a negative target range), not a live indicator. Listed in
CONCEPT-UNIVERSE under Monetary aggregates as a supporting SNB series alongside the
monetary base and the SNB balance sheet.

## Access
- **type**: SNB cube API
- **endpoint**: `https://data.snb.ch/api/cube/snbband/data/json/en`
- **call**: `snb_fetch("snbband")` (cube_id = id minus `ch_snb_` prefix)

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`.
- Single dimension D0; the series' `metadata.key` `{...}` gives the D0 code. Emit
  `D0, date, value`; `date` ISO, `value` numeric (percent per annum).
- Drop grouping node `D0_0` (`data: false`), keep `UG`, `OG`, `L3MCHF`.
- No SA toggle; JSON+CSV only. Live CSV `PublishingDate` = freshness signal.

## Dimensions
- `D0` (Overview): `UG` lower limit of the target range, `OG` upper limit (the
  default view), `L3MCHF` the realised 3-month CHF Libor fixing. `UG`/`OG` nest
  under the grouping node `D0_0`; `L3MCHF` is a top-level leaf.

## Display
- **split**: D0
- **single-select**: n/a (single dimension)
- **default**: D0=OG
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube has no SA dimension)

## Caveats / simplifications
- Series is closed (ended 2019-06-12) and will not update; the `end` date is the
  retirement date of the Libor-target regime, not a stale pull.
- Values are interest rates in percent per annum, not stocks or flows.

## Provenance
Script: `R/source_snb.R::snb_fetch`, cube from `R/snb_cubes.tsv` (`snbband`, topic
"Money and banking"). Datasheet authored 2026-06-01; parser verified 2026-06-01
(15,054 rows, 3 series).
