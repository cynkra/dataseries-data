# Weekly Economic Activity index (WEA)

- **id**: ch_seco_wwa
- **title**: Weekly economic activity (WEA) | de: Wöchentliche Wirtschaftsaktivität (WWA) | fr: Activité économique hebdomadaire (WEA) | it: Attività economica settimanale (WEA)
- **concept**: Business cycle & sentiment / High-frequency activity tracker
- **canonical**: yes
- **source**: seco
- **license**: seco (free reuse, attribution required)
- **frequency**: weekly
- **coverage**: 2005-01-03 .. 2026-05-11
- **series**: 2
- **updated**: 2026-06-02

## What is special
SECO's Weekly Economic Activity index (WEA), a high-frequency nowcasting indicator
built from weekly real-economy signals such as electricity consumption, payment
transactions and freight. It is scaled to the year-on-year growth rate of real
adjusted GDP, so a value of 2.0 means activity is running about 2% above the same
week a year earlier. It is already a growth rate and should not be differenced
again. A discontinued companion series measured activity against the pre-2020
level instead.

## Access
- **type**: seco-swissdata — SECO swissdata long CSV (native format; a JSON meta sidecar now exists, but the two series + units are stable so dimensions are built by hand)
- **set**: `wwa`
- **endpoint** (2026-06: SECO retired the old `/dam/...download` URLs — they now 502 — and serves the machine-readable files via `scheduler.swissdatas.ch`, linked from the new page `seco.admin.ch/wea`):
  - data: `https://scheduler.swissdatas.ch/scheduled/wwa.csv`
  - meta (optional, unused — dimensions hand-built): `https://scheduler.swissdatas.ch/scheduled/ch-seco-wwa.json`
- **call**: `seco_wwa_fetch("ch_seco_wwa")`

## Parsing recipe
- The CSV is already long and tidy with columns `structure,type,seas_adj,date,value`.
  Read it, coerce `date` via `to_iso()` (ISO weekly Monday dates pass through) to
  `Date`, `value` to numeric, drop NA, then keep only `structure` + `date` +
  `value` and arrange.
- `type` (always `index`) and `seas_adj` (always `csa`) are constant single-value
  columns; drop them. `(structure, date)` is unique on its own (verified: 0 dups).
- There is **no `_json.txt` meta sidecar** (unlike `ch_seco_gdp`), so `dimensions`,
  labels, units and notes are constructed in code. The two `structure` levels and
  their English labels come from the companion `wwa.xlsx` `beschriftung` sheet
  (`Index of weekly economic activity (WEA)` / `WEA compared with the pre-crisis
  level`); hardcoded here rather than re-fetched each run.
- `frequency` is `infer_frequency()` on the raw periods -> `weekly` (median 7-day
  gap on the ISO Monday dates).

## Dimensions
- `structure`: series. Two codes:
  - `seco_wwa` — Index of weekly economic activity (WEA), headline, 2005-> .
  - `seco_wwa_pre_covid` — WEA compared with the pre-crisis (Q4 2019) level,
    discontinued (2019-2022). Non-default alternate.
  This is the split / single-select dimension.

## Labels
- **units**: Scaled to the rate of growth of real, seasonally, calendar and sport-event adjusted GDP versus the same quarter of the previous year (percent) | de: Skaliert auf die Wachstumsrate des realen, saison-, kalender- und sportanlassbereinigten BIP gegenüber dem Vorjahresquartal (Prozent) | fr: Mis à l'échelle du taux de croissance du PIB réel corrigé des variations saisonnières, calendaires et des grands événements sportifs, par rapport au même trimestre de l'année précédente (pour cent) | it: Scalato al tasso di crescita del PIL reale destagionalizzato, corretto per gli effetti di calendario e dei grandi eventi sportivi, rispetto allo stesso trimestre dell'anno precedente (per cento)
- dim: structure
  - **label**: Series | de: Serie | fr: Série | it: Serie
  - seco_wwa: Index of weekly economic activity (WEA) | de: Index der wöchentlichen Wirtschaftsaktivität (WWA) | fr: Indice de l'activité économique hebdomadaire (WEA) | it: Indice dell'attività economica settimanale (WEA)
  - seco_wwa_pre_covid: WEA compared with the pre-crisis level (discontinued) | de: WWA im Vergleich zum Vorkrisenniveau (eingestellt) | fr: WEA par rapport au niveau d'avant-crise (abandonné) | it: WEA rispetto al livello pre-crisi (interrotto)

## Display
- **split**: structure
- **single-select**: structure
- **default**: structure=seco_wwa
- **transform**: level
- **seasonal adjustment**: not a dimension here. The published series is already
  seasonally + calendar + sport-event adjusted (the CSV `seas_adj` column is a
  constant `csa`), so there is no SA toggle. Do NOT apply a year-on-year transform:
  the values are *already* a (scaled) YoY GDP growth rate.

## Caveats / simplifications
- Values are a level on a growth-rate scale (scaled YoY real-GDP growth), so
  `transform=level` — applying `yoy` would double-difference and produce nonsense.
- `seco_wwa_pre_covid` is discontinued (last obs 2022-12-05) and measures a
  different thing (difference to Q4 2019 level, in %), so it is a non-default
  alternate, not comparable to the headline index without care.
- `type` and `seas_adj` are dropped because they are constant; if SECO ever adds a
  raw / unadjusted track the parser must reintroduce them to keep keys unique.
- No meta sidecar exists, so labels are maintained in the parser and can drift from
  SECO wording; cross-check against the `wwa.xlsx` `beschriftung` sheet on changes.

## Provenance
Script: `R/source_seco.R::seco_wwa_fetch`. Datasheet 2026-06-02; parser verified
live 2026-06-02 (1,265 rows, 2 series, span 2005-01-03 .. 2026-05-11; anchors
seco_wwa 2026-05-11 = 2.07064226892172, 2005-01-03 = 3.9011681763975).
