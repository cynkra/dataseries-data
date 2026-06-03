# KOF Economic Sentiment Index (ESI)

- **id**: ch_kof_esi
- **concept**: Business cycle & sentiment / Sentiment composite
- **canonical**: yes
- **source**: KOF Swiss Economic Institute
- **license**: kof (CC BY, attribution required)
- **frequency**: monthly
- **coverage**: 2007-04 .. 2026-05
- **series**: 2

## What is special
KOF's **Economic Sentiment Index** — a survey-based sentiment composite, sibling to
the KOF Economic Barometer (`ch_kof_barometer`) but capturing firms' assessment of
the current and expected business situation. Two methodology vintages run in
parallel: the original "pre-Brexit" version and the standard 2018 version.

## Access
- **type**: KOF Datenservice public **sets** endpoint (open OGD; the per-key `ts`
  endpoint gates most keys behind HTTP 412 — the `sets` endpoint does not)
- **set**: `ogd_ch.kof.esi`
- **call**: `kof_set_fetch("ogd_ch.kof.esi")`

## Parsing recipe
- `GET .../api/v1/public/sets/ogd_ch.kof.esi?mime=csv` → a **wide** table (`date` +
  one column per series key). Pivot longer to `indicator, date, value`; filter NA
  (the set is sparse — series start at different dates). `date` (`YYYY-MM`) → ISO.

## Dimensions
- `indicator`: `ch.kof.esi.index` (pre-Brexit version) and `ch.kof.esi.index.v2018`
  (standard 2018 version, the default).

## Display
- **split**: indicator
- **single-select**:
- **default**: indicator=ch.kof.esi.index.v2018
- **transform**: level
- **seasonal adjustment**: n/a

## Caveats / simplifications
- Unitless index (mean ≈ 100); a reading > 100 is above-average sentiment. Periodic
  re-estimation revises the back-series (same caveat as the barometer).
- The COVID-era weekly KOF indicator (WBI) was discontinued by KOF and is not in any
  public set — deliberately not pursued. Other open KOF sets
  (`ogd_ch.kof.globalbaro`, `ogd_ch.kof.bts_total`) are available via the same helper.

## Provenance
Script: `R/source_kof.R::kof_set_fetch` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-02 (2 series, 460 rows, to 2026-05).
