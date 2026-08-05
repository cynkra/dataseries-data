# Harmonised Index of Consumer Prices (HICP)

- **id**: ch_fso_hicp
- **title**: Harmonised CPI (HICP) | de: Harmonisierter Konsumentenpreisindex (HVPI) | fr: IPC harmonisé (IPCH) | it: IPC armonizzato (IPCA)
- **concept**: Prices / Consumer prices
- **canonical**: no (alternate for Consumer prices — the EU-harmonised methodology, for cross-country comparison)
- **source**: eurostat
- **license**: eurostat (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2004-12 .. 2025-12
- **series**: 13
- **updated**: 2026-02-06

## What is special
The **EU-harmonised** consumer price index for Switzerland (Harmonised Index of
Consumer Prices, 2015 = 100), published by **Eurostat** — not the FSO. It is the
internationally comparable inflation measure: all 27+ HICP economies are computed
on a common COICOP basket and method, so this is the series to use when comparing
Swiss inflation against the euro area or EU. We carry the all-items aggregate
**CP00** plus the **12 main COICOP divisions** CP01..CP12 (= 13 series).

This is **distinct from `ch_fso_cpi`** (the national Landesindex der
Konsumentenpreise, LIK): the LIK is the FSO's domestic-method index with a far
deeper position hierarchy (~595 positions) and a Dec-2025=100 base, whereas the
HICP is the harmonised method on a 2015=100 base with a different (smaller)
basket — notably the HICP excludes owner-occupied housing costs, which the LIK
includes. Reach for `ch_fso_hicp` for EU comparability and for `ch_fso_cpi` for
the domestic headline / detailed basket.

## Access
- **type**: eurostat-sdmx — Eurostat SDMX 2.1 REST (SDMX-CSV)
- **flow**: `prc_hicp_midx` (monthly index)
- **dataflow**: `prc_hicp_midx`
- **call**: `eurostat_hicp_fetch("ch_fso_hicp")` issues one SDMX-CSV GET per COICOP code

## Parsing recipe
- One GET per COICOP code (13 total) against
  `https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/prc_hicp_midx/M.I15.{COICOP}.CH/?format=SDMX-CSV`.
- SDMX-CSV header: `DATAFLOW,LAST UPDATE,freq,unit,coicop,geo,TIME_PERIOD,OBS_VALUE,OBS_FLAG,CONF_STATUS`.
  Read all columns as character (`OBS_VALUE` then coerced numeric).
- `date` from `TIME_PERIOD` (YYYY-MM) via `to_iso()` → first of month.
- `value` = `OBS_VALUE` (numeric). Drop NA values/dates.
- `updated` parsed from `LAST UPDATE` ("DD/MM/YY HH:MM:SS").
- COICOP English labels from the ESTAT COICOP codelist TSV
  (`.../codelist/ESTAT/COICOP?format=TSV`), not hardcoded.
- Value anchors (fail-closed): CP00 2004-12 = 96.90, CP00 2025-12 = 107.07.

## Dimensions
- `coicop`: the COICOP consumption purpose. `CP00` = All-items HICP (parent);
  `CP01`..`CP12` = the 12 main divisions (Food and non-alcoholic beverages,
  Alcoholic beverages/tobacco, Clothing, Housing/utilities, Furnishings, Health,
  Transport, Communications, Recreation and culture, Education, Restaurants and
  hotels, Miscellaneous). Hierarchy: CP00 → CP01..CP12.

## Labels
- **units**: Index (2015 = 100) | de: Index (2015 = 100) | fr: Indice (2015 = 100) | it: Indice (2015 = 100)
- dim: coicop
  - **label**: COICOP consumption purpose | de: COICOP-Verwendungszweck | fr: Fonction de consommation COICOP | it: Funzione di consumo COICOP

## Display
- **split**: coicop
- **single-select**:
- **default**: coicop=CP00
- **transform**: yoy
- **seasonal adjustment**: n/a (the HICP index is published unadjusted)

## Caveats / simplifications
- 2015 = 100 base; the all-items 2015 monthly mean is 100 by construction.
- Only the all-items aggregate + 12 main divisions are carried, not the deeper
  COICOP sub-classes (CP011, CP0111, ...) — those are available in the same flow
  but out of scope for the headline view.
- HICP basket differs from the national LIK (notably excludes owner-occupied
  housing), so HICP and `ch_fso_cpi` levels are not directly comparable.
- Coverage starts 2004-12 (the first month Eurostat publishes the CH HICP index
  on the 2015=100 base).
- English labels only (the codelist also carries other EU languages).

## Provenance
Source: **Eurostat** (NOT the FSO) — flow `prc_hicp_midx`, key `M.I15.{COICOP}.CH`.
Script: `R/source_eurostat.R::eurostat_hicp_fetch`. Datasheet 2026-06-02; parser
verified live 2026-06-02 (3,289 rows, 13 series, 0 NA values; CP00 2004-12 = 96.90,
CP00 2025-12 = 107.07, CP00 2015 mean = 100.00).
