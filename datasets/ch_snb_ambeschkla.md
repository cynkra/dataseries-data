# Employees, by economic activity

- **id**: ch_snb_ambeschkla
- **concept**: Labour / Employment / jobs
- **canonical**: no (alternate for Employment; overlaps FSO `ch_fso_besta`, flagged in CONCEPT-UNIVERSE; FSO is the intended canonical employment series)
- **source**: Swiss National Bank
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1991-Q3 .. 2025-Q4
- **series**: 60
- **updated**: 2025-Q4 (latest observation; PublishingDate in CSV header is the freshness signal)

## What is special
Employees broken down by economic activity (NACE-style sectors) crossed with an
employment type. The SNB version overlaps FSO `ch_fso_besta` (jobs by division); the
concept universe flags this and keeps FSO as the intended canonical, so this is the
labelled alternate. The distinctive feature is the two-axis cross: four head-count
bases (Total, full-time, part-time, full-time-equivalents) times ~14 leaf sectors,
which lets you read part-time intensity and FTE conversion by sector, something the
FSO jobs cube does not expose the same way. Values are in thousands of persons.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `ambeschkla`
- **endpoint**: `GET https://data.snb.ch/api/cube/ambeschkla/data/json/en`
- **call**: `snb_fetch("ambeschkla", title = "Employees, by economic activity")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`; map each `timeseries.metadata.key`
  `{...}` codes positionally onto dim ids `D0`,`D1`.
- Flatten the nested `dimensionItems` hierarchy to code -> label; keep grouping
  nodes (`data: false`) only for the tree, not as data rows.
- Quarterly dates are period starts (Jan/Apr/Jul/Oct); coerce to ISO `Date`.
- JSON+CSV only, no JSON-stat; no SA toggle.

## Dimensions
- `D0` (Employees): `VT` Total, `V` full-time, `T` part-time, `IV` in full-time
  equivalents (all leaf data codes).
- `D1` (Economic activity): leaf sectors with codes such as `T0` overall total,
  `VGHW` manufacturing, `BB` construction, `HIRK` motor-vehicle trade/repair,
  `GBG` hospitality, `VL` transport/storage, `EF` financial services, `V`
  insurance, `GW` real estate, `EU` education, `GS` health/social, `ED` other
  services, `OV` public administration. `D1_0/D1_1/D1_2` are non-data sector
  groupings (secondary/tertiary), each with its own `T*` subtotal.

## Display
- **split**: D1
- **single-select**:
- **default**: D0=VT, D1=T0
- **transform**: level
- **seasonal adjustment**: n/a (no SA dimension or SA codes)

## Hierarchy
The overview line dimension D0 carries a `VT Total` (employment level) shipped as a sibling of its sub-aggregates; nest them under it.
- dim: D0
- derive: under-root VT

## Caveats / simplifications
- Code `V` is reused across dimensions (full-time in `D0`, insurance in `D1`); the
  dim id disambiguates, do not collapse on the bare code.
- Default preview series is `D0 = IV`, `D1 = BB` (FTE in construction).

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube_id `ambeschkla`).
Datasheet 2026-06-01; parser verified 2026-06-01 (8,280 rows, 60 series).
