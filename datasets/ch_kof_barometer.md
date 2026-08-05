# KOF Economic Barometer

- **id**: ch_kof_barometer
- **title**: KOF Economic Barometer | de: KOF Konjunkturbarometer | fr: Baromètre conjoncturel KOF | it: Barometro congiunturale KOF
- **concept**: Business cycle & sentiment / Leading barometer
- **canonical**: yes
- **source**: kof
- **license**: kof (CC BY, redistributable with attribution)
- **frequency**: monthly
- **coverage**: 1991-01 .. 2026-05
- **series**: 1
- **updated**: 2026-05

## What is special
The KOF Economic Barometer, Switzerland's headline leading indicator for the
business cycle, published monthly near month-end by the KOF Swiss Economic
Institute at ETH Zurich. A composite of a large basket of predictors, designed to
anticipate the year-on-year growth of Swiss GDP a few months ahead and normalised
so the long-run mean sits near 100: above 100 signals above-average expected
growth, below 100 the reverse.

## Access
- **type**: kof-api — KOF Time Series Database API **v2**
- **key**: `ch.kof.barometer`
- **endpoint**: `https://tsdb-api.kof.ethz.ch/v2/ts`
- **call**: `kof_fetch("ch.kof.barometer")`
  (`GET .../ts?keys=ch.kof.barometer&mime=csv&access_type=public`, no key required)
- `access_type=public` is what makes the call anonymous; without it the API
  redirects to KOF's Keycloak login. (API v1 on `datenservice.kof.ethz.ch` was
  discontinued in 2026-07 — see `docs/source-quirks.md`.)

## Parsing recipe
- Request the series as CSV via `&mime=csv`. The response has two columns:
  `date` and one value column named after the key.
- Rename the non-`date` column to `value`; coerce `value` to numeric.
- Convert `date` to ISO via `to_iso()` then `as.Date()`; periods are first-of-month
  (e.g. `1991-01-01`). Sort ascending.
- Frequency is inferred from the period strings (`infer_frequency`) and resolves to
  monthly. No dimension columns are emitted.

## Dimensions
None. The dataset is a single undifferentiated series (`dim_order` empty).

## Caveats / simplifications
- The barometer is periodically re-based and re-estimated by KOF, so historical
  values can be revised across the whole back-series, not just recent months.
- Under API v1 the per-key `ts` endpoint served only `ch.kof.barometer` (other keys
  412'd); API v2 lifted that, but whole-collection reads (`kof_set_fetch`) remain the
  route for the wider OGD family — see `ch_kof_esi`.
- The level is index-like and unitless (mean ~100); it is not a percentage or a
  growth rate despite tracking expected GDP growth.

## Provenance
Script: `R/source_kof.R::kof_fetch` (key `ch.kof.barometer`). Datasheet authored
2026-06-01; parser verified 2026-06-01 (425 rows, 1 series). Migrated to KOF API v2
and re-verified 2026-07-30.
