# Consumer Price Index (LIK) – national index, long history

- **id**: ch_snb_plkopr
- **title**: Consumer prices (CPI)
- **concept**: Prices / Consumer prices
- **canonical**: yes
- **featured**: Inflation
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1921-01 .. 2026-04
- **series**: 1

## What is special
The Swiss headline consumer price index (Landesindex der Konsumentenpreise), as
re-disseminated by the SNB. It is the **canonical CPI for the long view**: the SNB
chain reaches back to **January 1921** — over a century — whereas the detailed FSO
asset (`ch_fso_cpi`, the labelled alternate) only carries the full COICOP position
hierarchy from December 1982. So this is the series to reach for when you want the
headline index or year-on-year inflation across the whole modern history of the
Swiss franc; `ch_fso_cpi` is the one to reach for when you want the 443-position
basket breakdown. The cube carries the **total index only** (no sub-baskets). The
source ships two measures under one flat `D0` dimension — the index level (rebased
December 2025 = 100) and its year-on-year change — but the change is dropped (it is
the app's YoY % toggle applied to the index), so this is a single-series dataset:
just the index level.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `plkopr`
- **endpoint**: `https://data.snb.ch/api/cube/plkopr/data/json/en`
- **call**: `snb_fetch("plkopr", title = "Consumer Price Index (LIK) – national index, long history")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube `plkopr`.
- Single dimension `D0`; `metadata.key` `{...}` carries one code. One long row per
  non-null observation with `date` (ISO month start) and numeric `value`.
- `D0` has two data-bearing codes (`LD2010100` index, `VVP` YoY change); `VVP` is
  dropped downstream, leaving a single value, so `D0` collapses to a single-series
  dataset (no dimension).

## Dimensions
- None: the source's `D0` Overview dimension (`LD2010100` National index,
  December 2025 = 100; `VVP` year-on-year change in %) collapses once `VVP` is dropped
  as a redundant transform, leaving just the index level as a single series.

## Display
- **split**: n/a (single series)
- **single-select**: n/a
- **default**: n/a
- **transform**: yoy
- **seasonal adjustment**: n/a (the CPI is not seasonally adjusted)

## Caveats / simplifications
- Total index only — no COICOP sub-baskets. For the position hierarchy use the
  FSO alternate `ch_fso_cpi`.
- The index code label still reads "December 2025 = 100"; the base period
  follows whatever rebasing the SNB currently publishes.
- The source's `VVP` (YoY rate of the same index) is dropped, not stored: the app's
  YoY % toggle on the index gives the same figure. This is why the opening
  **transform** defaults to `yoy` — inflation is the headline read of a CPI.

## Provenance
Script: `R/source_snb.R::snb_fetch` (title/topic from `R/snb_cubes.tsv`). Datasheet
authored 2026-06-02; coverage verified live 2026-06-02 (1921-01 .. 2026-04).
