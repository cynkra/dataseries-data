# Services-sector turnover (quarterly)

- **id**: ch_fso_services
- **title**: Services turnover | de: Umsätze Dienstleistungssektor | fr: Chiffres d'affaires des services | it: Fatturato dei servizi
- **concept**: Domestic economy / Services turnover
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 2021-Q1 .. 2026-Q1
- **series**: 132

## What is special
The turnover index for the **tertiary (services) sector**, completing the
sector-turnover triad alongside retail (`ch_fso_retail`) and industry/construction
(`ch_fso_production`). Same FSO source as the production series, disjoint NOGA
codes. History is genuinely short — services turnover is a newer FSO product, base
2021 = 100; the secondary-sector codes in the same flow reach back to 1999, the
tertiary ones do not.

## Access
- **type**: fso-sdmx — FSO SDMX (disseminate.stats.swiss)
- **flow**: `CH1.KEU/DF_KEU_Q1/1.0.0` (agency `CH1.KEU`, dataflow `DF_KEU_Q1`, version 1.0.0)
- **call**: `fso_sdmx_fetch("ch_fso_services", "CH1.KEU", "DF_KEU_Q1", "1.0.0", noga_keep = .SDMX_SERVICES_NOGA)`

## Parsing recipe
- Reuses `fso_sdmx_fetch` unchanged (identical DSD to `ch_fso_production`); the NOGA
  slice `.SDMX_SERVICES_NOGA` (`G-NxK, G, H, I, J, L, M, N`) keeps only tertiary codes.
- `UNIT_MEASURE` carries the index (`IX`) plus YoY (`VARQ-4`) and QoQ (`VARQ-1`)
  change leaves; the latter two are pruned via `REDUNDANT_LEVELS` (the app recomputes
  them from the index), which collapses `UNIT_MEASURE` to a single value → dropped.

## Dimensions
- `NOGA`: tertiary sections — `G-NxK` tertiary sector excl. financial & insurance
  (the default), plus `G` trade, `H` transport, `I` accommodation/food, `J` ICT,
  `L` real estate, `M` professional/scientific, `N` administrative services.
- `ADJUSTMENT`: `N` raw, `W` calendar-adjusted, `Y` seasonally + calendar-adjusted.
- `INDICATOR_KE`: `UTOT` total turnover, `UINL` domestic, `UEXP` foreign (nominal).

## Display
- **split**: NOGA
- **single-select**: ADJUSTMENT, INDICATOR_KE
- **default**: NOGA=G-NxK, ADJUSTMENT=Y, INDICATOR_KE=UTOT
- **transform**: level
- **seasonal adjustment**: use the `ADJUSTMENT` dimension (no separate toggle)

## Hierarchy
`G-NxK` (tertiary sector) is the total; the NOGA service sections sit under it.
- G-NxK
  - G
  - H
  - I
  - J
  - L
  - M
  - N

## Caveats / simplifications
- Nominal turnover **index** (2021 = 100); no absolute CHF values are published.
- The `G-NxK` aggregate label comes back in German from the codelist (its English
  name is missing upstream) — read it as "Tertiary sector (excl. financial & insurance)".

## Provenance
Script: `R/source_fso_sdmx.R::fso_sdmx_fetch` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; SDMX slice verified live 2026-06-02 (2574 rows, 132 series).
