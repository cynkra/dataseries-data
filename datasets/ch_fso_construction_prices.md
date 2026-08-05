# Construction Price Index

- **id**: ch_fso_construction_prices
- **title**: Construction prices
- **concept**: Prices / Construction prices
- **canonical**: yes
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: semi-annual
- **coverage**: 1998-10 .. 2025-10
- **series**: 3
- **updated**: 2025-12-18

## What is special
The Swiss Construction Price Index (Baupreisindex, BAP) measures the price
development of construction work in Switzerland, surveyed semi-annually with
reference months **April and October**. The headline series for the whole of
Switzerland is captured on three work-type levels: the overall index
(Baugewerbe: Total), building construction (Hochbau) and civil engineering
(Tiefbau). Levels are on the **October 2020 = 100** base. One of the few
semi-annual price series in the catalog.

## Access
- **type**: fso-dam-excel — FSO DAM Excel asset
- **order number**: cc-t-05.05.01 (currently DAM asset 36269766)
- **call**: `fso_excel_download("cc-t-05.05.01")`

## Parsing recipe
- The workbook has one sheet per index base (`1998`, `2010`, `2015`, `2020`),
  plus `BAP` / `Info` cover sheets. Parse the **`2020`** sheet for the current
  base (Oct 2020 = 100).
- The sheet is region-blocked: column 1 carries `<REG_nn>` markers (REG_01 =
  Schweiz, REG_02..REG_08 = the 7 Greater Regions), each followed by its
  `<OBJ_nn>` work-type rows. The OBJ tags repeat in every block, so the match
  is **scoped to the Switzerland block** (from `<REG_01>` to the next `<REG_>`).
- Work-types are matched by OBJ tag in column 1: `<OBJ_02>` = Total,
  `<OBJ_03>` = Hochbau (building), `<OBJ_13>` = Tiefbau (civil engineering).
- Date columns are anchored on the **month name (row 5) + year (row 6)**, never a
  fixed column index. October -> first-of-month `YYYY-10-01`, April -> `YYYY-04-01`.
- European number parsing: strip `'` thousands separators and non-breaking
  spaces, `,` -> `.`; the `…` placeholder (value not yet available / suppressed)
  becomes NA and is dropped.

## Dimensions
- `worktype`: the type of construction work — `total` (Construction: Total),
  `hochbau` (Building construction), `tiefbau` (Civil engineering).

## Labels
- **units**: Index (October 2020 = 100)
- dim: worktype
  - **label**: Type of work
  - total: Construction: Total
  - hochbau: Building construction (Hochbau)
  - tiefbau: Civil engineering (Tiefbau)

## Display
- **split**: worktype
- **single-select**:
- **default**: worktype=total
- **transform**: yoy
- **seasonal adjustment**: n/a

The only dimension is `worktype`; the three levels are overlaid by the split. The
headline default opens on `total`. Because this is a pure price index whose point
is the rate of change, the headline transform is year-on-year (`yoy`) rather than
the raw index level. The series is not seasonally adjusted (semi-annual reference
months are reported as published).

## Caveats / simplifications
- Only the **Switzerland region (REG_01)** is captured; the 7 Greater-Region
  breakdowns (REG_02..REG_08) in the same sheet are not emitted.
- Only the **3 headline work-types** (Total / Hochbau / Tiefbau) are captured; the
  finer object detail (Neubau Mehrfamilienhaus, Renovation, Neubau Strasse, …)
  exists in the sheet but is dropped to keep the headline series legible.
- Only the **current base (2020)** sheet is emitted; the legacy 1998 / 2010 / 2015
  base sheets are re-indexed views of the same index and are not emitted, per the
  keep-current-base rule.
- `frequency` is set to `semi-annual` manually — `infer_frequency()` has no such
  bucket (April + October reference months only).

## Provenance
Script: `R/source_fso_excel_sets.R::fso_excel_ch_fso_construction_prices`.
Datasheet 2026-06-02; parser verified live 2026-06-02 (165 rows, 3 series, 0 NA
values; anchors Total/Switzerland Oct1998=78.7, Oct2020=100.0, Apr2025=115.8,
Oct2025=116.2 reproduced).
