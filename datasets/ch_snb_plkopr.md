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
Swiss inflation, the headline consumer price index only. For the breakdown into 595 basket items such as food, rent and transport, see the detailed series.

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

## What is special (de)
Schweizer Teuerung, nur der Gesamtindex der Konsumentenpreise. Für die Gliederung in 595 Warenkorbpositionen wie Nahrung, Miete und Verkehr siehe die Detailreihe.

## What is special (fr)
Inflation suisse, uniquement l'indice global des prix à la consommation. Pour la ventilation en 595 positions du panier — alimentation, loyer, transports — voir la série détaillée.

## What is special (it)
Inflazione svizzera, solo l'indice generale dei prezzi al consumo. Per la ripartizione nelle 595 posizioni del paniere come alimentari, pigioni e trasporti, si veda la serie dettagliata.
