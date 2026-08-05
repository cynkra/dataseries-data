# Unemployment rate (ILO)

- **id**: ch_fso_unemp_rate
- **title**: Unemployment rate (ILO) | de: Erwerbslosenquote (ILO) | fr: Taux de chômage (BIT) | it: Tasso di disoccupazione (ILO)
- **concept**: Labour / Unemployment
- **canonical**: no (alternate — ILO definition; the registered/SECO `ch_snb_amarbma` is canonical)
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1991-01 .. 2026-03
- **series**: 5
- **updated**: 2026-05-18

## What is special
The unemployment rate on the ILO definition, derived from labour-force survey
data, which is the internationally comparable measure. It differs from registered
unemployment (`ch_snb_amarbma`), which counts people enrolled at regional job
centres; the two are not interchangeable.

## Access
- **type**: fso-dam-excel — FSO DAM Excel asset
- **order number**: je-d-03.03.01.03
- **call**: `fso_excel_download("je-d-03.03.01.03")`

## Parsing recipe
- Sheet `Monatswerte (1991-2026)` (the ILO rate; a separate sheet of age-group
  head-counts in thousands is **not** parsed here, it is a different unit and
  belongs to a different concept).
- Row 3 holds date headers (`Jan.91` ... `Dez.25`); the last 2026 columns carry a
  footnote digit (e.g. `Jan.262` = Jan 2026), handled by dropping the third digit.
  Century switch (year `00` -> 2000) via a threshold (>= 50 -> 1900s).
- Category labels at column 1, rows 4/6/7/9/10.

## Dimensions
The workbook provides **marginals, not a full cross-tabulation**, so two dimensions
are modelled as marginal breakdowns (each breakdown row sets one dim and holds the
other at total), giving 5 series:
- `origin`: total / Swiss / foreign.
- `sex`: total / men / women.

## Labels
- dim: origin
  - **label**: Nationality | de: Staatsangehörigkeit | fr: Nationalité | it: Nazionalità
  - tot: Total | de: Total | fr: Total | it: Totale
  - ch: Swiss nationals | de: Schweizerinnen und Schweizer | fr: Suisses | it: Svizzeri
  - ex: Foreign nationals | de: Ausländerinnen und Ausländer | fr: Étrangers | it: Stranieri
- dim: sex
  - **label**: Sex | de: Geschlecht | fr: Sexe | it: Sesso
  - tot: Total | de: Total | fr: Total | it: Totale
  - men: Men | de: Männer | fr: Hommes | it: Uomini
  - wom: Women | de: Frauen | fr: Femmes | it: Donne

## Display
- **split**: origin
- **single-select**:
- **default**: origin=tot, sex=tot
- **transform**: level
- **seasonal adjustment**: n/a

`origin` (nationality: total / Swiss / foreign) is the main breakdown a user compares as
lines, so it is the split; `sex` (total / men / women) is single-select. The headline
default opens on the overall total rate (`origin=tot, sex=tot`), the figure people quote,
rather than the Swiss-nationals slice the most-observations guess picked. The series are
already rates in %, so the transform stays at `level`.

## Caveats / simplifications
- Values are already in % (no European thousands separators present).
- Only the rate sheet is parsed; the age-group head-count sheet is excluded.

## Provenance
Script: `R/source_fso_excel_sets.R::fso_excel_ch_fso_unemp_rate`. Datasheet
2026-06-01; parser verified 2026-06-01 (2,115 rows, 5 series, 0 NA values).
