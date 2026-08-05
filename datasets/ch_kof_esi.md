# KOF Economic Sentiment Index (ESI)

- **id**: ch_kof_esi
- **title**: KOF Economic Sentiment Index | de: KOF Economic Sentiment Index | fr: KOF Economic Sentiment Index | it: KOF Economic Sentiment Index
- **concept**: Business cycle & sentiment / Sentiment composite
- **canonical**: yes
- **source**: kof
- **license**: kof (CC BY, attribution required)
- **frequency**: monthly
- **coverage**: 2007-04 .. 2026-05
- **series**: 2

## What is special
How Swiss firms rate their current and expected business situation, from ETH Zurich survey data. Two methodology versions run side by side.

## Access
- **type**: kof-api — KOF Time Series Database API **v2**, public **collection** (v1 called
  these "sets"; collections owned by the `public` user are open OGD)
- **endpoint**: `https://tsdb-api.kof.ethz.ch/v2/collections/public/<collection>/ts`
- **key**: `ogd_ch.kof.esi`
- **call**: `kof_set_fetch("ogd_ch.kof.esi")`
- `access_type=public` keeps the call anonymous; without it the API redirects to
  KOF's Keycloak login. (API v1 on `datenservice.kof.ethz.ch` was discontinued in
  2026-07 — see `docs/source-quirks.md`.)

## Parsing recipe
- `GET .../v2/collections/public/ogd_ch.kof.esi/ts?mime=csv&access_type=public` → a
  **wide** table (`date` + one column per series key). Pivot longer to
  `indicator, date, value`; filter NA (the collection is sparse — series start at
  different dates). `date` → ISO.

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
  public collection — deliberately not pursued. Other open KOF collections
  (`ogd_ch.kof.globalbaro`, `ogd_ch.kof.bts_total`) are available via the same helper.

## Provenance
Script: `R/source_kof.R::kof_set_fetch` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-02 (2 series, 460 rows, to 2026-05).
Migrated to KOF API v2 and re-verified 2026-07-30.
