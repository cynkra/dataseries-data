# Consumer Price Index (LIK) – national index, long history

- **id**: ch_snb_plkopr
- **title**: Consumer prices (CPI) | de: Konsumentenpreise (LIK) | fr: Prix à la consommation (IPC) | it: Prezzi al consumo (IPC)
- **concept**: Prices / Consumer prices
- **canonical**: yes
- **featured**: Inflation
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1921-01 .. 2026-04
- **series**: 1

## What is special
Switzerland's consumer price index, the standard measure of inflation, compiled by
the Federal Statistical Office and re-disseminated by the SNB. This series carries
the headline total index only. For the breakdown into the 595 basket positions,
use `ch_fso_cpi`.

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
