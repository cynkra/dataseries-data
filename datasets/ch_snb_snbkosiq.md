# Business cycle signals

- **id**: ch_snb_snbkosiq
- **title**: Business cycle signals | de: Konjunktursignale | fr: Signaux conjoncturels | it: Segnali congiunturali
- **concept**: Business cycle & sentiment / Business cycle signals
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 2011-01 .. 2026-01
- **series**: 24
- **updated**: 2026-01 (use API PublishingDate header for exact day)

## What is special
What Swiss companies tell the National Bank each quarter about turnover, capacity, hiring, margins, prices and wage expectations.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `snbkosiq`
- **endpoint**: `https://data.snb.ch/api/cube/snbkosiq/data/json/en`
- **call**: `snb_fetch("snbkosiq", title = "Business cycle signals")`

## Parsing recipe
- Fetch two docs: `/dimensions/en` (code -> label map + nested hierarchy) and
  `/data/json/en` (the observations).
- Each timeseries `metadata.key` looks like `EPB@SNB.snbkosiq{AI}`; the codes
  inside `{...}` are the dimension-item codes in `D0..Dn` order. Here there is one
  dimension, so the brace holds a single `D0` code.
- Emit a long tibble: dimension code columns + `date` + `value`. Dates arrive as
  ISO period strings and become the first day of the quarter (`2011-01-01`,
  `-04-01`, `-07-01`, `-10-01`). Drop observations with null `value`.
- Freshness: the live CSV variant (`/data/csv/en`) carries a `PublishingDate`
  header line; that is the publish signal. The stored long CSV is `D0,date,value`
  only.

## Dimensions
- `D0` (Overview): the signal, 24 codes. Examples: `UVJQ`/`UVQ` turnover vs
  year-back / previous quarter, `KA` capacity utilisation, `BS` procurement
  difficulties, `ML`/`NM` margin situation / sustainability, `KVK` lending
  conditions, `LS` liquidity, `PK`/`RS` staff shortages / recruitment difficulty,
  `UERW`/`BERW` expected turnover / employment, `EPE`/`VPE` expected purchase /
  sales price change, `AI`/`BI` planned equipment / construction investment,
  `LELJ`/`LEFJ` wage increases current / next year (%), `IERW` expected inflation
  (%) with children `IERWM` (6-12 months) and `IERWJ` (3-5 years), `F25` sales
  prices vs year-back quarter.

## Display
- **split**: D0
- **single-select**: (none; single dimension)
- **default**: D0=KA
- **transform**: level
- **seasonal adjustment**: n/a
- The 24 signals share one flat dimension (`D0`), which is the split: each line is
  one signal, so the user adds signals to compare. There is no total/composite, so
  the default is a representative business-cycle gauge, `KA` capacity utilisation.
  The `IERW` "expected inflation" parent is a grouping node (`data: false`); its
  children `IERWM`/`IERWJ` carry the data. Signals are mostly diffusion indices, not
  price indices, so the transform is level (not yoy), and units are mixed across
  signals.

## Caveats / simplifications
- Units are mixed across `D0`: most items are diffusion indices, but the wage and
  inflation-expectation items are in percent. There is no per-item unit column;
  the meaning lives in the `D0` label.
- The SNB hierarchy is one level deep apart from `IERW`; the flattened long table
  keeps only leaf codes, so the `IERW` parent appears only via its two children.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `snbkosiq`, title from `R/snb_cubes.tsv`,
topic "Business surveys"). Datasheet authored 2026-06-01.

## What is special (de)
Was Schweizer Unternehmen der Nationalbank vierteljährlich zu Umsatz, Kapazität, Personalsuche, Margen, Preisen und Lohnerwartungen berichten.

## What is special (fr)
Ce que les entreprises suisses rapportent chaque trimestre à la Banque nationale sur le chiffre d'affaires, les capacités, l'embauche, les marges, les prix et les salaires attendus.

## What is special (it)
Cosa le imprese svizzere riferiscono trimestralmente alla Banca nazionale su fatturato, capacità, assunzioni, margini, prezzi e attese salariali.
