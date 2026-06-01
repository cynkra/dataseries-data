# KOF Economic Barometer

- **id**: ch_kof_barometer
- **concept**: Business cycle & sentiment / Leading barometer
- **canonical**: yes
- **featured**: KOF Barometer
- **source**: KOF Swiss Economic Institute (ETH Zurich)
- **license**: kof (CC BY, redistributable with attribution)
- **frequency**: monthly
- **coverage**: 1991-01 .. 2026-05
- **series**: 1
- **updated**: 2026-05

## What is special
The headline Swiss leading indicator for the business cycle, published monthly
near month-end. A single composite index built from a large basket of underlying
predictors, designed to anticipate the year-over-year growth rate of Swiss GDP a
few months ahead. Normalised so the long-run mean sits around 100; readings above
100 signal above-average expected growth, below 100 the reverse. This is the only
series in the catalog from KOF, and it is the only KOF key the public API will
serve: every other KOF series returns HTTP 412. Plain one-column time series, no
dimensions, monthly back to 1991.

## Access
- **type**: KOF API
- **endpoint**: `https://datenservice.kof.ethz.ch/api/v1/public/ts`
- **call**: `kof_fetch("ch.kof.barometer")`
  (`GET .../ts?keys=ch.kof.barometer&mime=csv`, public, no key required)

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
- Only `ch.kof.barometer` is reachable on the public endpoint; the same fetcher
  pointed at any other KOF key returns HTTP 412 and yields nothing.
- The level is index-like and unitless (mean ~100); it is not a percentage or a
  growth rate despite tracking expected GDP growth.

## Provenance
Script: `R/source_kof.R::kof_fetch` (key `ch.kof.barometer`). Datasheet authored
2026-06-01; parser verified 2026-06-01 (425 rows, 1 series).
