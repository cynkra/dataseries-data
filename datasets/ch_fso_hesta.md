# Hotel sector: overnight stays by tourism region

- **id**: ch_fso_hesta
- **concept**: Tourism / Hotel overnight stays
- **canonical**: yes
- **featured**: Tourism
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2005-01 .. 2026-03
- **series**: 14
- **updated**: not published (live PX-Web pull; latest observation 2026-03)

## What is special
The HESTA accommodation statistics: monthly hotel overnight stays for
Switzerland and its 13 official tourism regions, back to 2005. The strong
seasonal swing is visible in the raw data (a region's January is several times
its November), which is why this is kept as the canonical tourism series rather
than an annual roll-up. The region breakdown is the distinctive axis: alpine
regions (Graubünden, Valais, Ticino) and the urban regions (Zurich, Geneva,
Basel) move on very different seasonal calendars, so the series is most useful
sliced by `Tourismusregion`. Code `8100` is the Switzerland total; the numeric
codes 1..14 are the regions. Only one indicator (overnight stays) is pulled; the
table also carries arrivals, which this dataset deliberately omits.

## Access
- **type**: FSO PX-Web (json-stat2)
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
- `Indikator` (Indicator): only `2` = overnight stays is fetched.

## Display
- **split**: Tourismusregion
- **single-select**: Indikator
- **default**: Tourismusregion=8100, Indikator=2
- **transform**: level
- **seasonal adjustment**: n/a (raw overnight-stay counts; strong seasonal swing is
  intentionally left in the data)

## Caveats / simplifications
- Arrivals and other HESTA indicators are not captured; only overnight stays.
- No `updated` date is published by the API; the latest monthly observation
  stands in for currency.

## Provenance
Script: `R/source_fso.R::fso_fetch` (explicit query built in
`R/pipeline.R`). Datasheet authored 2026-06-01.
