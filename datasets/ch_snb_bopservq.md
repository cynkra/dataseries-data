# Swiss balance of payments – Current account services, by country – Quarter

- **id**: ch_snb_bopservq
- **title**: Balance of payments: services | de: Zahlungsbilanz: Dienstleistungen | fr: Balance des paiements : services | it: Bilancia dei pagamenti: servizi
- **concept**: External sector / Balance of payments
- **canonical**: no (alternate for Balance of payments)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 2012-Q1 .. 2025-Q4
- **series**: 1,755
- **updated**: 2025-Q4 (latest observation; SNB publishes ~3 months in arrears)

## What is special
Which countries Switzerland trades services with, around 50 partners plus regional totals, by service type and direction.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `bopservq`
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

## What is special (de)
Mit welchen Ländern die Schweiz Dienstleistungen handelt — rund 50 Partner plus Regionentotale — nach Dienstleistungsart und Richtung.

## What is special (fr)
Avec quels pays la Suisse échange des services — environ 50 partenaires plus les totaux régionaux — par type de service et par sens.

## What is special (it)
Con quali paesi la Svizzera scambia servizi — circa 50 partner più i totali regionali — per tipo di servizio e direzione.
