# Foreign cross-border commuters by canton of work

- **id**: ch_fso_cross_border_commuters
- **title**: Cross-border commuters
- **concept**: Labour / Cross-border commuters
- **canonical**: yes
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 2002-Q3 .. 2026-Q1
- **series**: 27

## What is special
Foreign **cross-border commuters** (Grenzgänger) working in Switzerland, by canton
of work, quarterly since 2002. A distinctive feature of the Swiss labour market
(~410k people, concentrated in Geneva, Ticino, Basel, Vaud). The successor to the
legacy `ch.fso.ggs` series.

## Access
- **type**: FSO SDMX (disseminate.stats.swiss), sliced to the national total
- **flow**: agency `CH1.GGS`, dataflow `DF_GGS_1`, version 1.0.0
- **call**: `fso_sdmx_cross_border_commuters("ch_fso_cross_border_commuters")`

## Parsing recipe
- One pre-sliced SDMX key `_T._T.Q._T.` (DSD order `NOGA.CNTRY.FREQ.SEX.WORK_CANTON`)
  pins the national total over NOGA / country-of-residence / sex, leaving the
  `WORK_CANTON` breakdown. Getting the axis order wrong silently returns a wrong slice.
- `WORK_CANTON` codes use standard BFS numbering (`1`=ZH … `26`=JU; `_T`=Switzerland);
  labels are mapped in the wrapper. `TIME_PERIOD` (`YYYY-Qn`) → first-of-quarter ISO.

## Dimensions
- `canton`: 26 cantons of work plus `_T` Switzerland total (the default).

## Display
- **split**: canton
- **single-select**:
- **default**: canton=_T
- **transform**: level
- **seasonal adjustment**: n/a

## Caveats / simplifications
- Values are a **model-based estimate**, hence non-integer; stored unrounded and
  labelled "estimate". A second view (by country of residence, 37 countries) is
  available from the same flow but not shipped here.
- Definitional: foreign cross-border commuters of foreign nationality.

## Provenance
Script: `R/source_fso_sdmx.R::fso_sdmx_cross_border_commuters` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-02 (2565 rows, CH total 2026-Q1 = 413,320).
