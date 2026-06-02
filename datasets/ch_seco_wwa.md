# Weekly Economic Activity index (WEA)

- **id**: ch_seco_wwa
- **concept**: Business cycle / high-frequency activity tracker
- **canonical**: yes
- **source**: State Secretariat for Economic Affairs (SECO)
- **license**: seco (free reuse, attribution required)
- **frequency**: weekly
- **coverage**: 2005-01-03 .. 2026-05-11
- **series**: 2
- **updated**: 2026-06-02

## What is special
The catalog's **first weekly series**. SECO's Weekly Economic Activity index
(WEA, German WWA) is a high-frequency nowcasting indicator built from a basket of
weekly real-economy signals (electricity consumption, payment transactions,
freight, foot traffic, etc.). It is **scaled to the year-on-year growth rate of
real, seasonally / calendar / sport-event adjusted GDP**, so a WEA value of `2.0`
reads as "activity running about 2% above the same week a year earlier" — it is a
level on a growth-rate scale, not something to be differenced again.

SECO publishes it in the swissdata long-CSV format, like `ch_seco_gdp`, but
**without the `_json.txt` meta sidecar**, so the dimension/label metadata is built
by hand in the parser (optionally cross-checked against the companion `wwa.xlsx`
`beschriftung` sheet, which carries the en/de/fr/it labels).

The `structure` dimension carries two series: the headline **seco_wwa** index
(2005-> , the default) and **seco_wwa_pre_covid**, a discontinued variant
(2019-12 .. 2022-12) that measured weekly activity relative to the Q4 2019
pre-crisis level rather than YoY.

## Access
- **type**: SECO swissdata long CSV (native format, no meta sidecar)
- **endpoint**:
  - data: `https://www.seco.admin.ch/dam/seco/en/dokumente/Wirtschaft/Wirtschaftslage/indikatoren/wwa.csv.download.csv/wwa.csv`
  - labels (optional): `https://www.seco.admin.ch/dam/seco/en/dokumente/Wirtschaft/Wirtschaftslage/indikatoren/wwa.xlsx.download.xlsx/wwa.xlsx` (`beschriftung` sheet)
- **call**: `seco_wwa_fetch("ch_seco_wwa")`

## Parsing recipe
- The CSV is already long and tidy with columns `structure,type,seas_adj,date,value`.
  Read it, coerce `date` via `to_iso()` (ISO weekly Monday dates pass through) to
  `Date`, `value` to numeric, drop NA, then keep only `structure` + `date` +
  `value` and arrange.
- `type` (always `index`) and `seas_adj` (always `csa`) are constant single-value
  columns; drop them. `(structure, date)` is unique on its own (verified: 0 dups).
- There is **no `_json.txt` meta sidecar** (unlike `ch_seco_gdp`), so `dimensions`,
  labels, units and notes are constructed in code. The two `structure` levels and
  their English labels come from the companion `wwa.xlsx` `beschriftung` sheet
  (`Index of weekly economic activity (WEA)` / `WEA compared with the pre-crisis
  level`); hardcoded here rather than re-fetched each run.
- `frequency` is `infer_frequency()` on the raw periods -> `weekly` (median 7-day
  gap on the ISO Monday dates).

## Dimensions
- `structure`: series. Two codes:
  - `seco_wwa` — Index of weekly economic activity (WEA), headline, 2005-> .
  - `seco_wwa_pre_covid` — WEA compared with the pre-crisis (Q4 2019) level,
    discontinued (2019-2022). Non-default alternate.
  This is the split / single-select dimension.

## Display
- **split**: structure
- **single-select**: structure
- **default**: structure=seco_wwa
- **transform**: level
- **seasonal adjustment**: not a dimension here. The published series is already
  seasonally + calendar + sport-event adjusted (the CSV `seas_adj` column is a
  constant `csa`), so there is no SA toggle. Do NOT apply a year-on-year transform:
  the values are *already* a (scaled) YoY GDP growth rate.

## Caveats / simplifications
- Values are a level on a growth-rate scale (scaled YoY real-GDP growth), so
  `transform=level` — applying `yoy` would double-difference and produce nonsense.
- `seco_wwa_pre_covid` is discontinued (last obs 2022-12-05) and measures a
  different thing (difference to Q4 2019 level, in %), so it is a non-default
  alternate, not comparable to the headline index without care.
- `type` and `seas_adj` are dropped because they are constant; if SECO ever adds a
  raw / unadjusted track the parser must reintroduce them to keep keys unique.
- No meta sidecar exists, so labels are maintained in the parser and can drift from
  SECO wording; cross-check against the `wwa.xlsx` `beschriftung` sheet on changes.

## Provenance
Script: `R/source_seco.R::seco_wwa_fetch`. Datasheet 2026-06-02; parser verified
live 2026-06-02 (1,265 rows, 2 series, span 2005-01-03 .. 2026-05-11; anchors
seco_wwa 2026-05-11 = 2.07064226892172, 2005-01-03 = 3.9011681763975).