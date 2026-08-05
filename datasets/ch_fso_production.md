# Industry & construction turnover (quarterly)

- **id**: ch_fso_production
- **title**: Industry & construction turnover
- **concept**: Domestic economy / Industry & construction turnover
- **canonical**: yes

- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso
- **frequency**: quarterly
- **coverage**: 1999-Q1 .. 2026-Q1
- **series**: see provenance
- **updated**: 2026-Q1 (latest observation)

## What is special
The quarterly turnover / production index for the secondary sector — industry
(NOGA sections B–E) and construction (section F) — published as **one** dataset split
by NOGA section. FSO **migrated this series off the dead PX-Web STAT-TAB onto its new
SDMX 2.1 endpoint** (`disseminate.stats.swiss`, agency `CH1.KEU`, flow `DF_KEU_Q1`),
so it shares the `R/source_fso_sdmx.R` reader with `ch_fso_retail`. We keep the
secondary-sector slice: the industry aggregate `B-E` (and its sections B mining,
C manufacturing, D energy), construction `F`, and the construction divisions
41 (buildings), 42 (civil engineering), 43 (specialised construction), plus their
aggregate `41_43`.

## Access
- **type**: fso-sdmx — FSO SDMX (disseminate.stats.swiss, agency CH1.KEU)
- **flow**: `CH1.KEU/DF_KEU_Q1/1.0.0`
- **endpoint / order number**: flow `DF_KEU_Q1` version `1.0.0`
  - data: `https://disseminate.stats.swiss/rest/data/CH1.KEU,DF_KEU_Q1,1.0.0/all?detail=dataonly` (Accept: `application/vnd.sdmx.data+csv`)
  - structure: `https://disseminate.stats.swiss/rest/dataflow/CH1.KEU/DF_KEU_Q1/1.0.0?references=all` (Accept: `application/vnd.sdmx.structure+json`)
- **call**: `fso_sdmx_fetch("ch_fso_production", "CH1.KEU", "DF_KEU_Q1", "1.0.0", title = list(en = "Industry & construction turnover (quarterly)"), noga_keep = <B-E,B,C,D,F,41,42,43,41_43>)`

## Parsing recipe
SDMX-CSV: same shape as `ch_fso_retail` (dimension columns + `TIME_PERIOD` +
`OBS_VALUE`), but `TIME_PERIOD` is quarterly (`YYYY-Qn`), mapped to the ISO
first-of-quarter date via `to_iso()` (R/dates.R). `FREQ` (Q) is dropped; NA values
dropped. Dimension codes are labelled from the structure codelists `CL_NOGA_KE`,
`CL_SEASONAL_ADJUST`, `CL_INDICATOR_KE`, `CL_PRICES_RESULT_TYPE`. NOGA is filtered to
the secondary-sector section/division codes listed above.

## Dimensions
- `NOGA` — secondary-sector activity. `B-E` industry (B mining, C manufacturing,
  D energy), `F` construction, and construction divisions `41`/`42`/`43` (+ aggregate
  `41_43`).
- `ADJUSTMENT` — seasonal-adjustment variant (`N` raw, `W` calendar adjusted, `Y`
  seasonally + calendar adjusted).
- `INDICATOR_KE` — turnover concept (`UTOT` total nominal, `UINL` domestic, `UEXP`
  foreign, `PTOT` real production volume).

The flow also carries a `UNIT_MEASURE` dimension (`IX` index, `VARQ-4` year-on-year
change, `VARQ-1` quarter-on-quarter change). We keep only the index `IX` and drop the
two change levels — they are exactly the app's YoY % and quarter-on-quarter transforms,
recomputed from the index — which collapses `UNIT_MEASURE` away entirely.

## Display
- **split**: NOGA
- **single-select**: ADJUSTMENT, INDICATOR_KE
- **default**: NOGA=B-E, ADJUSTMENT=Y, INDICATOR_KE=PTOT
- **transform**: level
- **seasonal adjustment**: single-select on `ADJUSTMENT`; default to seasonally +
  calendar adjusted (`Y`); raw (`N`) and calendar-only (`W`) available as toggles.

## Hierarchy
Two NOGA aggregates head the tree: `B-E` Industry (mining, manufacturing, energy) and
`F` Construction (with the `41_43` total and its divisions).
- B-E
  - B
  - C
  - D
- F
  - 41
  - 42
  - 43
  - 41_43

## Caveats / simplifications
- Only the secondary-sector NOGA codes are kept; the full `DF_KEU_Q1` flow also
  carries the tertiary sector (covered for retail by `ch_fso_retail`).
- `INDICATOR_KE` defaults to the real production index (`PTOT`), the headline read
  for industry, rather than nominal turnover.

## Provenance
Script: `R/source_fso_sdmx.R::fso_sdmx_fetch` (wired in `R/pipeline.R`). Datasheet
authored 2026-06-01; parser verified 2026-06-01.
