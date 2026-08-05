# Banks' balance sheet items by currency for selected bank categories (monthly)

- **id**: ch_snb_babilpobm
- **title**: Bank balance sheets by currency | de: Bankbilanzen nach Währung | fr: Bilans bancaires par monnaie | it: Bilanci bancari per valuta
- **concept**: Money & banking / Banking & credit
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1987-12 .. 2026-03
- **series**: 872
- **updated**: 2026-03 release (PublishingDate in CSV header)

## What is special
Assets and liabilities of banks in Switzerland month by month, item by item, split by currency and by bank size.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `babilpobm`
- **endpoint**: `https://data.snb.ch/api/cube/babilpobm/data/json/en`
- **call**: `snb_fetch("babilpobm", title = "Banks' balance sheet items by currency for selected bank categories - monthly")`

## Parsing recipe
- `/dimensions/en` gives the code->label map and the nested item hierarchy;
  `/data/json/en` gives the observations.
- `metadata.key` carries the four dimension codes in `dim_order`
  (`D0,INLANDAUSLAND,WAEHRUNG,BANKENGRUPPE`); `.snb_key_codes` splits the braces.
- Keep non-null values, parse `date` (month start) to ISO, cast value numeric.
  Values are in CHF millions.
- `PublishingDate` in the header is the freshness signal. JSON+CSV only, no SA
  toggle.

## Dimensions
- `D0` Balance sheet items: ~40 leaf codes under two grouping parents `AKT`
  (Assets) and `PAS` (Liabilities), which are non-data nodes. Leaves include
  `FMI` liquid assets, `FKU` amounts due from customers, `HYP` mortgage loans,
  `TOT` total assets, `VKE` customer deposits, `GKA` bank capital, `TOT1` total
  liabilities.
- `INLANDAUSLAND` Domestic and foreign: `T` total, `I` domestic, `A` foreign.
- `WAEHRUNG` Currency: `T` all currencies, `CHF`, `EUR`, `USD`.
- `BANKENGRUPPE` Bank category: `A40` all banks, `G15` big banks.

## Display
- **split**: D0
- **single-select**: INLANDAUSLAND, BANKENGRUPPE
- **default**: D0=TOT, INLANDAUSLAND=T, WAEHRUNG=T, BANKENGRUPPE=A40
- **transform**: level
- **seasonal adjustment**: n/a (no SA dimension; stock series at month end)

## Caveats / simplifications
- The two parent nodes `AKT` and `PAS` are grouping headers (`data: false`) and
  carry no series; only the leaf line items do.
- Equity and capital lines are signed (own shares and the non-eligible value
  adjustment are negative items by definition).
- Stock series at month end, in CHF millions.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `babilpobm`, title/topic from
`R/snb_cubes.tsv`). Datasheet authored 2026-06-01.

## What is special (de)
Aktiven und Passiven der Banken in der Schweiz Monat für Monat, Position für Position, nach Währung und Bankengrösse.

## What is special (fr)
Actifs et passifs des banques en Suisse mois par mois, poste par poste, par monnaie et par taille de banque.

## What is special (it)
Attivi e passivi delle banche in Svizzera mese per mese, voce per voce, per valuta e per dimensione della banca.
