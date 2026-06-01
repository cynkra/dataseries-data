# Job vacancies by economic division

- **id**: ch_fso_vacancies
- **concept**: Labour / Job vacancies
- **canonical**: yes
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1992-04 .. 2026-01
- **series**: 60
- **updated**: not published (live PX-Web pull; latest observation 2026Q1)

## What is special
The FSO job-vacancies statistics, a **leading indicator** for the labour market:
when firms post more openings, employment tends to follow. Quarterly back to
1992, by economic division. What makes this dataset distinctive is the
`Offene Stellen` dimension, which carries three different units of the same
concept in one table: the **count** of vacancies (`1`), an **index** rebased to
2015Q2 = 100 (`2`), and the **vacancy rate** in % of jobs (`3`). The mixed units
are why the value span runs from 0.2 (a rate) to 127017 (a count) in the same
column. The 20 NOGA divisions are a coarser cut than BESTA's 60 (e.g. one
`68-75` aggregate instead of separate real-estate and professional-services
codes). Pairs with `ch_fso_besta` (jobs) as the demand-side counterpart.

## Access
- **type**: FSO PX-Web (json-stat2)
- **endpoint / table id**: `px-x-0602000000_103` (node; real table at
  `.../px-x-0602000000_103/px-x-0602000000_103.px`)
- **call**: `fso_fetch_auto("ch_fso_vacancies", "px-x-0602000000_103", ...)`
  (auto-query, no hand-written selection).

## Parsing recipe
- `fso_fetch_auto` reads the table metadata, selects **all values of every
  dimension** (the project stores the complete source), detects the time
  dimension, and sizes the chunk so each call stays under the 5000-cell cap.
- Here the time dimension is `Quartal`, so the call chunks by `Quartal`. The
  chunk size is `floor(4500 / cells_per_period)` where `cells_per_period` is the
  product of the non-time dimension sizes (`Offene Stellen` x
  `Wirtschaftsabteilung`); parts are `rbind`-ed back together.
- Time is a single `Quartal` code like `2003Q2`; `.fso_make_date` maps it to a
  first-of-quarter ISO `date` (Q1->01, Q2->04, Q3->07, Q4->10), frequency
  quarterly. Rows whose time code is non-numeric (annual aggregate) parse to NA
  and are dropped.
- Dimension **codes are German** even on `/en/` (`Offene Stellen`,
  `Wirtschaftsabteilung`, `Quartal`); kept as stored column values.

## Dimensions
- `Offene Stellen` (Job vacancies, the unit/measure): `1` = count of vacancies,
  `2` = index (2015Q2 = 100), `3` = rate (in %). All three are kept, so values
  mix counts, index points and percentages.
- `Wirtschaftsabteilung` (Economic division): 20 NOGA codes. `5-96` total;
  `5-43` Sector II, `45-96` Sector III; division/aggregate codes such as
  `10-33` Manufacturing, `41-43` Construction, `55-56` Hotels and gastronomy,
  `64-66` Finance, `68-75` Real estate and scientific services, `86-88` Health.

## Display
- **split**: Wirtschaftsabteilung
- **single-select**: Offene Stellen
- **default**: Wirtschaftsabteilung=5-96, Offene Stellen=1
- **transform**: level
- **seasonal adjustment**: n/a

`Wirtschaftsabteilung` (the 20 NOGA economic divisions) is the breakdown a user compares
as lines, so it is the split; `Offene Stellen` is a unit/measure dimension (count / index
/ rate), so it is single-select rather than split. The headline default opens on the
economy-wide total division (`5-96`) and the primary measure, the count of vacancies
(`Offene Stellen=1`), not the 2015Q2-rebased index the most-observations guess picked.
Transform stays at `level`.

## Caveats / simplifications
- The three `Offene Stellen` measures share one `value` column; consumers must
  read the unit from that dimension, not the value magnitude.
- Coverage start differs by slice: the count/rate begin earlier than the index
  series; the dataset start (1992-04) is the earliest across all slices.
- No `updated` date is published by the API; latest quarter stands in.

## Provenance
Script: `R/source_fso.R::fso_fetch_auto` (auto-query; entry in `R/pipeline.R`).
Datasheet authored 2026-06-01.
