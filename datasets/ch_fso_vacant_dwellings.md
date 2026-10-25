# Vacant dwellings

- **id**: ch_fso_vacant_dwellings
- **title**: Vacant dwellings | de: Leerwohnungen | fr: Logements vacants | it: Abitazioni vuote
- **concept**: Domestic economy / Vacant dwellings
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 1995 .. 2026
- **series**: 2

## What is special
How many Swiss homes stand empty, and the official vacancy rate, the standard measure of housing shortage. Down to 0.93% in 2026.

## Access
- **type**: fso-sdmx — FSO SDMX (disseminate.stats.swiss), sliced to the national total
- **flow**: `CH1.LWZ/DF_LWZ_1/1.1.0` (agency `CH1.LWZ`, dataflow `DF_LWZ_1`, version 1.1.0)
- **call**: `fso_sdmx_vacant_dwellings("ch_fso_vacant_dwellings")`

## Parsing recipe
- One pre-sliced SDMX key — the full cube is ~2.5M rows at municipality level. KEY
  `8100._T._T..A` pins geography = `8100` (Switzerland; note this codelist has
  no `_T` total — the national code is the literal `8100`), rooms = `_T` (total),
  vacancy type = `_T` (total), all measures, FREQ = `A`.
- **Version 1.1.0, not 1.0.0.** FSO published the 2026 count (10 Sep 2026) only in
  version 1.1.0 of the flow; 1.0.0 stops at 2025. The ids of version 1.1.0 are
  the same except the measure codes: `MEASURE_DIMENSION` `OBS` = count of vacant
  dwellings, `RATE` = vacancy rate in %. The fetcher maps them back to the
  established codes (`OBS` -> `V`, `RATE` -> `PC`) so the series
  keep their codes and history. Versions 1.0.0 and 1.1.0 give identical values for
  1995-2025 (checked on all 31 counts and 29 rates); the rate has no value for
  1995 and 1996 (observation status `O`, empty) and those rows are dropped.
- Both versions carry the annotation `NonProductionDataflow=true`, as does every
  flow on the endpoint, so it is no sign that 1.1.0 is a draft; `/dataflow/CH1.LWZ/DF_LWZ_1/latest`
  resolves to 1.1.0.
- The PX table `px-x-0902020300_101` (Leer stehende Wohnungen) has not been
  updated since 2024, which is why the SDMX flow is the source. The dataset's
  source link points to the flow's own page, `https://www.bfs.admin.ch/asset/en/DF_LWZ_1`.
- `TIME_PERIOD` (`YYYY`) → first-of-year ISO date.

## Dimensions
- `measure`: `PC` Vacancy rate (%) — the default/headline — and `V` Vacant dwellings
  (number). Two different units, so single-select rather than a meaningful overlay.

## Labels
- dim: measure
  - **label**: Measure | de: Messgrösse | fr: Mesure | it: Misura
  - **units** PC: Percent | de: Prozent | fr: Pour cent | it: Percento
  - **units** V: Number of dwellings | de: Anzahl Wohnungen | fr: Nombre de logements | it: Numero di abitazioni
  - PC: Vacancy rate (%) | de: Leerwohnungsziffer (%) | fr: Taux de logements vacants (%) | it: Tasso di abitazioni vuote (%)
  - V: Vacant dwellings (number) | de: Leerwohnungen (Anzahl) | fr: Logements vacants (nombre) | it: Abitazioni vuote (numero)

## Display
- **split**: measure
- **single-select**:
- **default**: measure=PC
- **transform**: level
- **seasonal adjustment**: n/a (annual)

## Caveats / simplifications
- National total only. The cube also breaks down by canton/municipality, number of
  rooms (1..6+), and vacancy type (for sale / for rent / new / old / house type);
  all sliced out here for the headline series.
- The vacancy rate (`PC`) starts 1997; the count (`V`) starts 1995.

## Provenance
Script: `R/source_fso_sdmx.R::fso_sdmx_vacant_dwellings` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; switched to flow version 1.1.0 for the 2026 count 2026-10-25 (1995 .. 2026).

## What is special (de)
Wie viele Schweizer Wohnungen leer stehen, und die offizielle Leerwohnungsziffer, das Standardmass für Wohnungsknappheit. 2026 bei 0.93%.

## What is special (fr)
Combien de logements suisses sont vacants, et le taux de vacance officiel, la mesure de référence de la pénurie de logements. 0.93% en 2026.

## What is special (it)
Quante abitazioni svizzere sono vuote, e il tasso di sfitto ufficiale, la misura di riferimento della penuria di alloggi. 0.93% nel 2026.
