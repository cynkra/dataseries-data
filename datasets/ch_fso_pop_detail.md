# Permanent resident population by nationality and sex

- **id**: ch_fso_pop_detail
- **title**: Resident population by nationality | de: Ständige Wohnbevölkerung nach Staatsangehörigkeit | fr: Population résidante permanente par nationalité | it: Popolazione residente permanente per nazionalità
- **concept**: Population and demographics / Resident population by nationality
- **canonical**: no (the headline resident population is `ch_fso_pop`, the 1861– demographic balance; this is the recent nationality × sex stock detail)
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 2010 .. 2025
- **series**: 9

## What is special
Swiss and foreign residents by sex, year-end count from the population register. The foreign share was about 27.7% in 2025.

## Access
- **type**: fso-sdmx — FSO SDMX (disseminate.stats.swiss), sliced to the national total
- **flow**: `CH1.STATPOP/DF_STATPOP_REGLING_PERM/1.0.0` (agency `CH1.STATPOP`, dataflow `DF_STATPOP_REGLING_PERM`, version 1.0.0)
- **call**: `fso_sdmx_pop_detail("ch_fso_pop_detail")`

## Parsing recipe
- One pre-sliced SDMX key `_T..._T.A` (DSD order
  `REG_LING.NATIONALITY_CATEGORY.SEX.AGE.FREQ`): all language regions, age total,
  annual; leaves nationality × sex. The flow holds permanent residents only (no
  `POPULATION_TYPE` dimension).
- **Flow `DF_STATPOP_REGLING_PERM`, not `DF_STATPOP_REGLING`.** The latter (permanent
  and non-permanent residents, sliced to `POPULATION_TYPE` = `1`) stops at 2024; the
  `_PERM` flow carries the 2025 year-end stock and gives identical values for every
  nationality × sex cell of 2010-2024. The dataset's source link points to the
  flow's page, `https://www.bfs.admin.ch/asset/en/DF_STATPOP_REGLING_PERM`.
- `NATIONALITY_CATEGORY` `_T`/`1`/`2` = Total/Swiss/Foreign; `SEX` `_T`/`1`/`2` =
  Total/Male/Female. `TIME_PERIOD` (`YYYY`) → first-of-year ISO (year-end stock).

## Dimensions
- `nationality`: Total / Swiss / Foreign.
- `sex`: Total / Male / Female.

## Labels
- **units**: Number of permanent residents (year-end stock) | de: Ständige Wohnbevölkerung (Jahresendbestand) | fr: Population résidante permanente (état en fin d'année) | it: Popolazione residente permanente (stato a fine anno)
- dim: nationality
  - **label**: Nationality | de: Staatsangehörigkeit | fr: Nationalité | it: Nazionalità
  - _T: Total | de: Total | fr: Total | it: Totale
  - 1: Swiss | de: Schweizer | fr: Suisses | it: Svizzeri
  - 2: Foreign | de: Ausländer | fr: Étrangers | it: Stranieri
- dim: sex
  - **label**: Sex | de: Geschlecht | fr: Sexe | it: Sesso
  - _T: Total | de: Total | fr: Total | it: Totale
  - 1: Male | de: Männlich | fr: Hommes | it: Maschi
  - 2: Female | de: Weiblich | fr: Femmes | it: Femmine

## Display
- **split**: nationality
- **single-select**:
- **default**: nationality=_T, sex=_T
- **transform**: level
- **seasonal adjustment**: n/a

## Caveats / simplifications
- National only; the flow also carries a full single-year age dimension (~100 codes)
  and language region — sliced out here for the headline nationality × sex stock.
- BEVNAT vital flows (births/deaths) are **not** added: only marriages exist on SDMX
  (and only 2020–2024), and births/deaths back to 1861 are already in `ch_fso_pop`.

## Provenance
Script: `R/source_fso_sdmx.R::fso_sdmx_pop_detail` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-02 (Total 2024 = 9,051,029, exact match to FSO). Switched to `DF_STATPOP_REGLING_PERM` for the 2025 stock 2026-10-25 (Total 2025 = 9,127,125).

## What is special (de)
Schweizer und ausländische Wohnbevölkerung nach Geschlecht, Jahresendbestand aus dem Bevölkerungsregister. Der Ausländeranteil lag 2025 bei rund 27.7%.

## What is special (fr)
Population résidante suisse et étrangère par sexe, effectif de fin d'année tiré du registre. La part étrangère était d'environ 27.7% en 2025.

## What is special (it)
Popolazione residente svizzera e straniera per sesso, effettivo di fine anno dal registro. La quota straniera era circa il 27.7% nel 2025.
