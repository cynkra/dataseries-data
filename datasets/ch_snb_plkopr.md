# Consumer Price Index (LIK) – national index, long history

- **id**: ch_snb_plkopr
- **concept**: Prices / Consumer prices
- **canonical**: yes
- **featured**: Inflation
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1921-01 .. 2026-04
- **series**: 2

## What is special
The Swiss headline consumer price index (Landesindex der Konsumentenpreise), as
re-disseminated by the SNB. It is the **canonical CPI for the long view**: the SNB
chain reaches back to **January 1921** — over a century — whereas the detailed FSO
asset (`ch_fso_cpi`, the labelled alternate) only carries the full COICOP position
hierarchy from December 1982. So this is the series to reach for when you want the
headline index or year-on-year inflation across the whole modern history of the
Swiss franc; `ch_fso_cpi` is the one to reach for when you want the 443-position
basket breakdown. The cube carries the **total index only** (no sub-baskets): two
measures under one flat `D0` dimension — the index level (rebased December 2025 =
100) and its year-on-year change in percent.

## Access
- **type**: SNB cube API
- **endpoint**: `https://data.snb.ch/api/cube/plkopr/data/json/en`
- **call**: `snb_fetch("plkopr", title = "Consumer Price Index (LIK) – national index, long history")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube `plkopr`.
- Single dimension `D0`; `metadata.key` `{...}` carries one code. One long row per
  non-null observation with `date` (ISO month start) and numeric `value`.
- Two data-bearing codes only; no grouping nodes to drop.

## Dimensions
- `D0` Overview (measure): `LD2010100` National index, December 2025 = 100 (default);
  `VVP` Change from the corresponding month of the previous year, in %.

## Display
- **split**: D0
- **single-select**: n/a (single dimension)
- **default**: D0=LD2010100
- **transform**: yoy
- **seasonal adjustment**: n/a (the CPI is not seasonally adjusted)

## Caveats / simplifications
- Total index only — no COICOP sub-baskets. For the position hierarchy use the
  FSO alternate `ch_fso_cpi`.
- The `LD2010100` code label still reads "December 2025 = 100"; the base period
  follows whatever rebasing the SNB currently publishes.
- `VVP` is the YoY rate of the same index, provided for convenience; deriving `yoy`
  from `LD2010100` gives the same figure.

## Provenance
Script: `R/source_snb.R::snb_fetch` (title/topic from `R/snb_cubes.tsv`). Datasheet
authored 2026-06-02; coverage verified live 2026-06-02 (1921-01 .. 2026-04).
