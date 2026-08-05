# Employment outlook index by economic division

- **id**: ch_fso_besta_outlook
- **title**: Employment outlook | de: Beschäftigungsaussichten | fr: Perspectives d'emploi | it: Prospettive occupazionali
- **concept**: Labour / Employment outlook
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 2004-Q1 .. 2026-Q1
- **series**: 20

## What is special
The **forward-looking** labour indicator from the FSO employment barometer (BESTA):
firms' employment-outlook index by economic division, quarterly. A reading above 1.0
signals net hiring intent over the coming three months, below 1.0 net reduction —
the leading complement to the jobs (`ch_fso_besta`) and vacancies
(`ch_fso_vacancies`) series.

## Access
- **type**: fso-pxweb — FSO PX-Web / STAT-TAB (the BESTA theme-0602 family is reachable, unlike
- **table id**: `px-x-0602000000_105`
  most PX-Web cubes)
- **table**: `px-x-0602000000_105`
- **call**: `fso_fetch("ch_fso_besta_outlook", "px-x-0602000000_105", besta_outlook_query, quarter_col = "Quartal")`

## Parsing recipe
- Query pins the **composite index** (`Voraussichtliche Beschäftigungsentwicklung` =
  `5`) weighted by **jobs** (`Gewichtung` = `1`) across all economic divisions; both
  pinned dims are single-valued and drop out as degenerate, leaving
  `Wirtschaftsabteilung`. 1780 cells, under the 5000-cell cap (no chunking).
- `Quartal` (`YYYYQn`) → first-of-quarter ISO via `quarter_col`.

## Dimensions
- `Wirtschaftsabteilung` (Economic division): 20 NOGA aggregates. `5-96` = Total (the
  default), `5-43` Sector II, `45-96` Sector III, plus the divisional breakdown
  (manufacturing, construction, trade, finance, health, …). Same coding as `ch_fso_besta`.

## Display
- **split**: Wirtschaftsabteilung
- **single-select**:
- **default**: Wirtschaftsabteilung=5-96
- **transform**: level
- **seasonal adjustment**: n/a (it is already a diffusion-style ratio)

## Hierarchy
NOGA division ranges nest by containment (`5-96` ⊃ `5-43`/`45-96` ⊃ groups); derived.
- derive: noga-range

## Caveats / simplifications
- It is an **index** (ratio around 1.0, observed 0.67–1.22), not a level/count — do
  not apply a YoY transform. Flag the 1.0 neutral line.
- Not seasonally adjusted. The "by businesses" weighting variant and the component
  shares (maintain/increase/decrease) are not shipped; the jobs-weighted composite
  matches the BESTA headline convention.

## Provenance
Script: `R/source_fso.R::fso_fetch` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-02 (1780 rows, 20 divisions, Total Q1 2026 ≈ 1.03).
