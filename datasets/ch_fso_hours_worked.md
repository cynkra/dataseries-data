# Actual hours worked (annual working volume)

- **id**: ch_fso_hours_worked
- **title**: Hours worked
- **concept**: Labour / Working time and working volume
- **canonical**: yes
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 2010 .. 2025
- **series**: 45

## What is special
The **annual working volume (AVOL)** statistic: the total hours actually worked in
the Swiss economy, plus its two per-job intensities. One cube carries three measures —
the headline **usual weekly hours per job** (the "Swiss work ~31h/week, not 42" number),
the **annual hours worked per job**, and the **absolute annual volume of hours** (~8.1
billion hours). All three cut by sex and by working-time category (full-time vs the two
part-time bands), so the part-time gender split — Switzerland's defining labour-market
feature — reads directly.

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
