# Swiss balance of payments – Current account services, by country – Quarter

- **id**: ch_snb_bopservq
- **title**: Balance of payments: services
- **concept**: External sector / Balance of payments
- **canonical**: no (alternate for Balance of payments)
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 2012-Q1 .. 2025-Q4
- **series**: 1,755
- **updated**: 2025-Q4 (latest observation; SNB publishes ~3 months in arrears)

## What is special
The services trade of the current account broken down **by counterpart country**,
which the headline BoP cubes do not provide. It is the widest cube in this group:
three dimensions (country x service component x accounting entry) multiply out to
1,755 leaf series, the largest in the SNB balance-of-payments set. Country coverage
(`D0`) runs from regional totals (Europe, EU, EU27, Africa, America, Asia, Oceania)
down to ~50 individual partners (Germany, US, China, UK, Singapore, Gulf Arabian
countries, ...). Service components (`D1`) match the bopcurrq services split. Shorter
history than the other BoP cubes, starting only 2012, because country-level services
detail was introduced with the BPM6 standard. Alternate to `ch_snb_bopcurrq` for the
concept: same producer, the unique value is the geographic dimension.

## Access
- **type**: SNB cube API
- **endpoint**: cube id `bopservq`
- **call**: `snb_fetch("bopservq", title = "Swiss balance of payments – Current account services, by country – Quarter")`,
  hitting `https://data.snb.ch/api/cube/bopservq/dimensions/en` and `.../data/json/en`

## Parsing recipe
- Three dimensions `D0`, `D1`, `D2`. Each `timeseries` key holds three brace-delimited
  codes mapped positionally to those dims; null observations skipped; ISO dates.
- Flatten labels and hierarchy with `source_snb.R`. Long table keyed by `D0`, `D1`,
  `D2`, `date`, `value`. No SA toggle; raw values.

## Dimensions
- `D0` Countries: regional grouping nodes (`D0_1` Europe, `D0_3` America, ...) with
  per-region `Total` codes and individual countries beneath. Note overlapping
  aggregates `EU`, `EU27`, and `D0_7` "All countries (excluding Rest of the world)".
- `D1` Component: service categories. `DT` Total for all services, plus `T0` transport,
  `T1` tourism, `V` insurance/pension, `F` financial, `L` licence fees, `TCI`
  telecom/computer/info, `FE` R&D, `B` consulting, `THG` technical/trade-related, `UD`
  other. Default `B`.
- `D2` Accounting entry: `E` Receipts, `A` Expenses, `S` Net. Default `A`.

## Display
- **split**: D0
- **single-select**: D2
- **default**: D0=T0, D1=DT, D2=S
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes raw values, no SA dimension)

## Hierarchy
The service-component line dimension D1 carries a `DT Total for all services` shipped as a sibling of the individual services (transport, tourism, financial, …); nest them under the total.
- dim: D1
- derive: under-root DT

## Caveats / simplifications
- Many partner x component x entry combinations are sparse; only non-null observations
  reach the CSV, so per-series spans vary. The country code `B` (Belgium) and component
  code `B` (consulting) collide across dimensions; they are disambiguated by column
  position, not value.
- Grouping nodes (`data:false`) hold no observations.

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube `bopservq`, topic
"Balance of payments"). Datasheet authored 2026-06-01; parser verified 2026-06-01
(98,280 rows, 1,755 series).
