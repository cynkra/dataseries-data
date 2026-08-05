# Actual hours worked (annual working volume)

- **id**: ch_fso_hours_worked
- **title**: Hours worked | de: Arbeitsstunden | fr: Heures de travail | it: Ore di lavoro
- **concept**: Labour / Working time and working volume
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 2010 .. 2025
- **series**: 45

## What is special
Hours actually worked in the Swiss economy: the total annual volume, the annual
hours per job, and the usual weekly hours per job — the figure behind "the Swiss
work about 31 hours a week, not 42". All three are cut by sex and by full-time or
part-time band, so Switzerland's high part-time rate among women is directly
visible.

## Access
- **type**: fso-dam-csv — FSO DAM asset, master is a long SDMX-style CSV (not xlsx)
- **order number**: `ts-x-03.02.03.01.02.01` (asset 36577051)
- **call**: `fso_hours_worked("ch_fso_hours_worked")`

## Parsing recipe
- `fso_dam_csv_download("ts-x-03.02.03.01.02.01")` resolves + downloads the CSV master;
  read with `fileEncoding = "UTF-8-BOM"` (the file carries a BOM).
- Columns `TIME_PERIOD, SEX, NAT, WORKTIME, NOGA1, SECTOR, EMP_STATUS, REGION, VALUE,
  VALUE_Y, VALUE_W, STATUS`. The cube has more dimensions than we keep: **slice to the
  national total** by filtering `NAT == "_T" & NOGA1 == "_T" & SECTOR == "_T" &
  EMP_STATUS == "_T" & REGION == "_T"`, leaving `SEX x WORKTIME`.
- The three measures are **parallel columns, not rows** — pivot them into a `measure`
  dimension: `VALUE` → `volume` (annual volume of hours), `VALUE_Y` → `annual` (hours
  per job per year), `VALUE_W` → `weekly` (usual hours per week per job).
- `TIME_PERIOD` (year) → first-of-year ISO date.

## Dimensions
- `measure`: `weekly` usual hours/week per job (the default), `annual` hours/year per
  job, `volume` annual volume of hours worked (total, ~8.1 bn hours).
- `sex`: `_T` total, `M` men, `F` women.
- `worktime`: `_T` total, `FT` full-time, `PT` part-time, `PT_I` part-time I (50-89%),
  `PT_II` part-time II (under 50%).

## Labels
- dim: measure
  - **label**: Measure | de: Messgrösse | fr: Mesure | it: Misura
  - weekly: Usual hours worked per week per job | de: Normalarbeitszeit pro Woche und Stelle | fr: Heures hebdomadaires habituelles par emploi | it: Ore settimanali abituali per impiego
  - annual: Annual hours worked per job | de: Jahresarbeitszeit pro Stelle | fr: Heures annuelles par emploi | it: Ore annue per impiego
  - volume: Annual volume of hours worked (total) | de: Jahresarbeitsvolumen (Total) | fr: Volume annuel d'heures travaillées (total) | it: Volume annuo di ore lavorate (totale)
- dim: sex
  - **label**: Sex | de: Geschlecht | fr: Sexe | it: Sesso
  - _T: Total | de: Total | fr: Total | it: Totale
  - M: Men | de: Männer | fr: Hommes | it: Uomini
  - F: Women | de: Frauen | fr: Femmes | it: Donne
- dim: worktime
  - **label**: Working time | de: Arbeitszeit | fr: Temps de travail | it: Tempo di lavoro
  - _T: Total | de: Total | fr: Total | it: Totale
  - FT: Full-time | de: Vollzeit | fr: Plein temps | it: Tempo pieno
  - PT: Part-time | de: Teilzeit | fr: Temps partiel | it: Tempo parziale
  - PT_I: Part-time I (50-89%) | de: Teilzeit I (50-89%) | fr: Temps partiel I (50-89%) | it: Tempo parziale I (50-89%)
  - PT_II: Part-time II (under 50%) | de: Teilzeit II (unter 50%) | fr: Temps partiel II (moins de 50%) | it: Tempo parziale II (meno del 50%)

## Display
- **split**: worktime
- **single-select**: measure
- **default**: measure=weekly, sex=_T, worktime=_T
- **transform**: level
- **seasonal adjustment**: n/a (annual)

The three dimensions form a **complete cube** — every `sex × worktime × measure` combo
is populated for all 16 years (45 series × 16 = 720 rows, zero empty combos), so any
chip the user clicks is non-empty. The chart lines are the working-time categories
(Total / Full-time / Part-time / Part-time I / Part-time II). `measure` is an exclusive
selector because its three levels are **different units** (usual weekly hours per job,
annual hours per job, absolute annual volume of hours) that must never overlay; `sex`
is a Total / Men / Women radio. The default opens on the headline "~31 h/week" series
(2024 = 30.94 h), Total sex, all working-time lines.

## Hierarchy
`Total` splits into full-time and part-time, and part-time into the two intensity bands.
- _T
  - FT
  - PT
    - PT_I
    - PT_II

## Caveats / simplifications
- We keep only the **national totals** of nationality, economic branch (NOGA), sector,
  employment status and region; the source cube has all of those cuts if wanted later.
- `weekly` is **usual** (contractual) hours, while `annual`/`volume` count hours
  **actually** worked (net of absence, overtime); don't divide one by the other naively.
- Part-time bands `PT_I` + `PT_II` sum to `PT`; `FT` + `PT` = `_T` for the volume
  measure, but the per-job intensities (`weekly`/`annual`) are averages, not additive.

## Provenance
Script: `R/source_fso_dam_csv.R::fso_hours_worked` (wired in `R/pipeline.R`, topic Labour).
Datasheet authored 2026-06-02; verified live 2026-06-02 (weekly _T/_T 2024 = 30.9443 h
= FSO "30h56min"; annual volume _T/_T 2024 = 8.117 bn hours — both exact matches).
Display verified live 2026-06-03 (45/45 cube combos populated, default + spot-checks all
return 16 rows; all dim levels flag data:true; validate_dataset() passes).
