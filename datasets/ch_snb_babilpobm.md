# Banks' balance sheet items by currency for selected bank categories (monthly)

- **id**: ch_snb_babilpobm
- **title**: Bank balance sheets by currency
- **concept**: Money & banking / Banking & credit
- **canonical**: yes
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1987-12 .. 2026-03
- **series**: 872
- **updated**: 2026-03 release (PublishingDate in CSV header)

## What is special
The full monthly balance sheet of banks in Switzerland, line by line, back to
1987. Every position from the regulatory balance sheet appears as a code: on the
asset side liquid assets, amounts due from banks/customers, mortgage loans,
trading portfolio, replacement values, financial investments, participations,
down to total assets; on the liabilities side amounts due to banks/customers,
cash bonds, bond issues, provisions, the equity components (bank capital,
reserves, own shares, period profit) and total liabilities. What makes this cube
large is the three-way slicing: each balance-sheet item is crossed with a
**currency** split (all / CHF / EUR / USD) and a **bank-category** split (all
banks vs big banks), which is why it expands to 872 stored series. The currency
breakdown is the distinctive feature; it lets you watch FX composition of the
banking system's book, not just totals.

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
