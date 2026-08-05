# Hotel sector: overnight stays by tourism region

- **id**: ch_fso_hesta
- **title**: Hotel overnight stays | de: Hotellogiernächte | fr: Nuitées hôtelières | it: Pernottamenti alberghieri
- **concept**: Domestic economy / Hotel overnight stays
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2005-01 .. 2026-03
- **series**: 14
- **updated**: not published (live PX-Web pull; latest observation 2026-03)

## What is special
Hotel overnight stays in Switzerland each month, for the country and its 13 tourism regions. Alpine and urban regions peak in opposite seasons.

## Access
- **type**: fso-pxweb — FSO PX-Web (json-stat2)
- **table id**: `px-x-1003020000_103`
- **endpoint / table id**: `px-x-1003020000_103` (node; real table at
  `https://www.pxweb.bfs.admin.ch/api/v1/en/px-x-1003020000_103/px-x-1003020000_103.px`)
- **call**: `fso_fetch("ch_fso_hesta", "px-x-1003020000_103", fso_query, ...)`
  with an explicit query (not `fso_fetch_auto`).

## Parsing recipe
- POST a json-stat2 query (`response.format = "json-stat2"`). The explicit query
  selects: `Jahr` = all, `Monat` = items 1..12, `Tourismusregion` = all,
  `Indikator` = item `2` (overnight stays only).
- Time is split across `Jahr` + `Monat`; `.fso_make_date` recombines them into a
  first-of-month ISO `date` (`YYYY-MM-01`) and sets frequency monthly.
- FSO mixes annual aggregates into the monthly cube via a non-numeric `Monat`
  code (e.g. `Monat = "YYYY"`); those rows parse to an NA date and are dropped.
- Dimension **codes are German** even on the `/en/` endpoint (`Jahr`, `Monat`,
  `Tourismusregion`, `Indikator`); English labels come from the metadata. Codes
  are kept as the stored column values.
- Cell-cap note: total selection (~22 years x 12 months x 14 regions x 1
  indicator) stays under PX-Web's 5000-cell cap, so no chunking is needed here.

## Dimensions
- `Tourismusregion` (Tourist region): `8100` = Switzerland total; `1` Graubünden,
  `2` Eastern Switzerland, `3` Zurich Region, `4` Lucerne / Lake Lucerne,
  `5` Basel Region, `6` Bern Region, `8` Jura & Three-Lakes, `9` Vaud,
  `10` Geneva, `11` Valais, `12` Ticino, `13` Fribourg Region, `14` Aargau and
  Solothurn Region. (Codes 7 and any gaps are not present in the data.)

The source's `Indikator` (Indicator) column only ever carries `2` (overnight stays)
here, so it is dropped — a one-option picker is pure noise. "Overnight stays" is implied
by the dataset title. That leaves `Tourismusregion` as the single dimension.

## Display
- **split**: Tourismusregion
- **single-select**:
- **default**: Tourismusregion=8100
- **transform**: level
- **seasonal adjustment**: n/a (raw overnight-stay counts; strong seasonal swing is
  intentionally left in the data)

## Hierarchy
`8100 Switzerland` is the national total, the sum of the 13 tourism regions; FSO lists it flat alongside them. Nest the regions under Switzerland.
- derive: under-root 8100

## Caveats / simplifications
- Arrivals and other HESTA indicators are not captured; only overnight stays.
- No `updated` date is published by the API; the latest monthly observation
  stands in for currency.

## Provenance
Script: `R/source_fso.R::fso_fetch` (explicit query built in
`R/pipeline.R`). Datasheet authored 2026-06-01.
