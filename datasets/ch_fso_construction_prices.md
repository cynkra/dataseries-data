# Construction Price Index

- **id**: ch_fso_construction_prices
- **title**: Construction prices | de: Baupreise | fr: Prix de la construction | it: Prezzi delle costruzioni
- **concept**: Prices / Construction prices
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: semi-annual
- **coverage**: 1998-10 .. 2026-04
- **series**: 3
- **updated**: 2026-06-18

## What is special
Price index for construction work in Switzerland, surveyed each April and October. Covers building construction and civil engineering separately.

## Access
- **type**: fso-dam-excel — FSO DAM Excel asset
- **order number**: cc-t-05.05.01 (currently DAM asset 36269766)
- **call**: `fso_excel_download("cc-t-05.05.01")`

## Parsing recipe
- The workbook has one sheet per index base (`1998`, `2010`, `2015`, `2020`, `2025`),
  plus `BAP` / `Info` cover sheets. Parse the **`2020`** sheet (Oct 2020 = 100).
- **The `2025` sheet (Oct 2025 = 100) is new and deliberately not parsed (decision of
  2026-10-25).** FSO's April 2026 press release quotes the headline on the new base
  (100.6, +0.6% on October 2025), and the headline table is titled "Basis Oktober
  2025 = 100". But the multi-base workbook is built to carry every base side by
  side, and all sheets, the `2020` one included, were extended to April 2026 (Total
  117.0 on the 2020 base, 100.6 on the 2025 base). The old base is therefore still
  extended, so the series keeps its base and its history. The `2025` sheet has the
  same layout as the `2020` sheet (same `<REG_nn>` / `<OBJ_nn>` tags, same rows 5-6
  month and year anchors, 147 rows against 155) and can be parsed by changing the
  sheet name. Up to October 2025 it is a pure rescale of the `2020` sheet (Total
  October 1998: 67.7 against 78.7); the April 2026 step differs slightly (+0.6%
  against +0.7%), and the new base comes with a new basket (Hochbau weight 76.46%
  against 77.67%). Switch when FSO stops extending the `2020` sheet.
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
- **units**: Index (October 2020 = 100) | de: Index (Oktober 2020 = 100) | fr: Indice (octobre 2020 = 100) | it: Indice (ottobre 2020 = 100)
- dim: worktype
  - **label**: Type of work | de: Arbeitsart | fr: Type de travaux | it: Tipo di lavori
  - total: Construction: Total | de: Baugewerbe: Total | fr: Construction : total | it: Costruzioni: totale
  - hochbau: Building construction (Hochbau) | de: Hochbau | fr: Bâtiment | it: Edilizia
  - tiefbau: Civil engineering (Tiefbau) | de: Tiefbau | fr: Génie civil | it: Genio civile

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
- Only the **2020 base** sheet is emitted; the 1998 / 2010 / 2015 base sheets are
  re-indexed views of the same index and are not emitted. FSO's headline base is
  now October 2025 = 100 (sheet `2025`), see Parsing recipe for why the 2020 base
  stays while FSO keeps extending it.
- `frequency` is set to `semi-annual` manually — `infer_frequency()` has no such
  bucket (April + October reference months only).

## Provenance
Script: `R/source_fso_excel_sets.R::fso_excel_ch_fso_construction_prices`.
Datasheet 2026-06-02; parser verified live 2026-06-02 (165 rows, 3 series, 0 NA
values; anchors Total/Switzerland Oct1998=78.7, Oct2020=100.0, Apr2025=115.8,
Oct2025=116.2 reproduced).

## What is special (de)
Preisindex für Bauarbeiten in der Schweiz, halbjährlich im April und Oktober erhoben. Erfasst Hochbau und Tiefbau getrennt.

## What is special (fr)
Indice des prix des travaux de construction en Suisse, relevé chaque avril et octobre. Bâtiment et génie civil sont couverts séparément.

## What is special (it)
Indice dei prezzi dei lavori di costruzione in Svizzera, rilevato ogni aprile e ottobre. Edilizia e genio civile sono coperti separatamente.
