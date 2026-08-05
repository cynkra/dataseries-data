# Gross domestic product (GDP)

- **id**: ch_seco_gdp
- **title**: Gross domestic product (GDP) | de: Bruttoinlandprodukt (BIP) | fr: Produit intérieur brut (PIB) | it: Prodotto interno lordo (PIL)
- **concept**: National accounts / GDP (output, expenditure, income)
- **canonical**: yes
- **featured**: GDP
- **source**: seco
- **license**: seco (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1980-01 .. 2025-10
- **series**: 660
- **updated**: 2026-02-23

## What is special
Swiss economic output each quarter from all three angles, production, spending and income, including a correction for sporting-body revenue.

## Access
- **type**: seco-swissdata — SECO swissdata (long CSV + JSON meta sidecar, native format)
- **set**: `ch-seco-gdp`
- **endpoint** (2026-06: SECO retired the old `/dam/...download` URLs — they now 502 — and serves the machine-readable files via `scheduler.swissdatas.ch`, linked from the new page `seco.admin.ch/gross-domestic-product`):
  - data: `https://scheduler.swissdatas.ch/scheduled/ch-seco-gdp.csv`
  - meta: `https://scheduler.swissdatas.ch/scheduled/ch-seco-gdp.json`
- **call**: `seco_fetch("ch_seco_gdp")`

## Parsing recipe
- The CSV is already long and tidy with columns `type,structure,seas_adj,date,value`.
  Read it, coerce `date` via `to_iso()` to `Date`, `value` to numeric, then
  `select(all_of(c(dim_order, "date", "value")))` and arrange.
- `dim_order` comes from the meta sidecar (`type, structure, seas_adj`); do not
  hardcode it.
- Remap the swissdata meta into our `dimensions` shape: `labels$dimnames[[d]]` is
  the dimension label, `labels[[d]][[code]]` is each level label (multilingual),
  and `hierarchy[[d]]` is the nested code tree (only `structure` has one). Units
  live under `meta$units$type`. `updated` = `updated_utc`; `notes` = `details`.
- No reshape, header rows, number-format cleanup, or date-serial decoding are
  needed; the source is already clean.

## Dimensions
- `type`: valuation / measure. `nom` (Swiss Francs at current prices), `real`
  (Swiss Francs, chain-linked volumes, reference year 2020), `gc_q` (contribution
  to real q-o-q GDP growth, percentage points), `gc_y` (contribution to real y-o-y
  GDP growth, percentage points). Single-select.
- `structure`: section, 68 codes in a production/expenditure/income hierarchy under
  root `gdp`. Leaf codes carry data; `production`, `expenditure`, `income` are
  grouping nodes (`data: false`). This is the split / multi-select dimension (the
  one with a `hierarchy`). NOGA industry ranges and ESA codes (B1GQ, P3, D1, etc.)
  are embedded in the labels.
- `seas_adj`: seasonal adjustment. `na` (raw), `csa` (seasonal+calendar), `nasa`
  (sports-event), `cssa` (seasonal+calendar+sports-event). Single-select.

## Display
- **split**: structure
- **single-select**: type, seas_adj
- **default**: structure=gdp, type=real, seas_adj=cssa
- **transform**: level
- **seasonal adjustment**: single-select; default to the **seasonally, calendar and
  sports-event adjusted** series (`cssa`) — the headline figure SECO itself reports.
  Swiss GDP carries value-added from major international sporting bodies domiciled
  here, which books in roughly four-year lumps; SECO's quarterly communiqués quote
  the sport-event-adjusted growth rate (e.g. "GDP adjusted for sporting events grew
  0.4% in Q1 2026"). The plain seasonally+calendar series (`csa`), raw (`na`) and
  sports-event-only (`nasa`) variants remain available as toggles. Opening on real
  (`type=real`), `cssa`, headline GDP total (`structure=gdp`) — not nominal
  consumption, which the most-observations heuristic would otherwise pick.

## Caveats / simplifications
- Series count (660) is the number of populated `type x structure x seas_adj`
  combinations, not 4 x 68 x 4; many cells are absent (e.g. growth-contribution
  `type`s exist mostly for the adjusted views and start later than 1980).
- The JSON meta carries no swissdata `dataseries` split/select UI hint, so none is
  passed through. The split dimension is inferred as the one with a `hierarchy`
  (`structure`); the others are single-select.
- Coverage start (1980) reflects the earliest level series; growth-contribution
  rows begin around 1990.

## Provenance
Script: `R/source_seco.R::seco_fetch`. Datasheet 2026-06-01; parser verified
2026-06-01 (107,100 rows, 660 series, span 1980-01 .. 2025-10).

## What is special (de)
Schweizer Wirtschaftsleistung pro Quartal aus allen drei Blickwinkeln — Produktion, Verwendung und Einkommen — inklusive einer Korrektur für Erträge von Sportverbänden.

## What is special (fr)
Production économique suisse par trimestre sous les trois optiques — production, dépenses et revenus — avec une correction pour les recettes des fédérations sportives.

## What is special (it)
Produzione economica svizzera per trimestre nelle tre ottiche — produzione, spesa e redditi — con una correzione per i ricavi delle federazioni sportive.
