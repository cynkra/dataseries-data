# Interest rates on new loan agreements, by product and maturity

- **id**: ch_snb_zikredlauf
- **title**: New lending rates | de: Zinssätze Neugeschäft | fr: Taux des nouveaux crédits | it: Tassi sui nuovi crediti
- **concept**: Interest rates & yields / Money-market rates
- **canonical**: no (alternate; one of the three money-market-rate cubes `zimoma` / `zikredlauf` / `zikrepro`, this one is the new-business lending-rate distribution)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2009-05 .. 2026-02
- **series**: 105
- **updated**: 2026-02 (latest published period)

## What is special
What Swiss banks charge on new loans and mortgages by maturity, as a full spread: mean, quartiles and median, not just an average.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `zikredlauf`
- **endpoint**: `https://data.snb.ch/api/cube/zikredlauf/data/json/en`
- **call**: `snb_fetch("zikredlauf", title = "Interest rates on new loan agreements, by product and maturity")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube id `zikredlauf`.
- `metadata$key` `{...}` holds three codes in `dim_order`; split on `,` into `D0,D1,D2`.
- Per `values`: drop nulls, ISO date, numeric value. JSON+CSV only, no SA toggle.
- All three dimensions are flat (leaves only), so no grouping nodes to drop.

## Dimensions
- `D0` (Product): `FH` fixed-rate mortgages, `VHBB` variable mortgages linked to a base
  rate, `FI` fixed-rate investment loans.
- `D1` (Maturity): ten buckets `L16M` (over 1m up to 6m) ... `L1015J` (over 10y up to
  15y), including overlapping ranges (`L515J`, `L715J`) that SNB publishes alongside the
  finer ones.
- `D2` (Reference values): `MP0` mean %, `25PQP` 25% quantile %, `MP1` median %,
  `75PQP` 75% quantile %, `AK` number of loan agreements.
- Default item: `D0=FH, D1=L1015J, D2=25PQP`.

## Display
- **split**: D1
- **single-select**: D0, D2
- **default**: D0=FH, D1=L35J, D2=MP1
- **transform**: level
- **seasonal adjustment**: n/a (this cube has no seasonal-adjustment dimension)

## Caveats / simplifications
- `D1` maturity buckets overlap (`L515J` spans the same range as `L57J`+`L710J`+...),
  so do not aggregate across maturities; pick one bucketing.
- `D2` mixes rate statistics (in %) with a count (`AK`), which is a different unit; keep
  them separate.
- Not every product x maturity cell is published, so the 105 series are a sparse subset
  of the full 3x10x5 grid.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube list + title from `R/snb_cubes.tsv`).
Datasheet authored 2026-06-01; parser verified 2026-06-01 (19,555 data rows, 105 series).
