# Corporate loans, broken down by company size (monthly)

- **id**: ch_snb_bakredbetgrbm
- **title**: Corporate loans by company size | de: Unternehmenskredite nach Unternehmensgrösse | fr: Crédits aux entreprises par taille d'entreprise | it: Crediti alle imprese per dimensione dell'impresa
- **concept**: Money & banking / Banking & credit
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2002-01 .. 2026-03
- **series**: 150
- **updated**: 2026-03 release (PublishingDate in CSV header)

## What is special
How much Swiss banks lend to companies by company size, shown both as credit granted and credit actually drawn, so headroom is visible.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `bakredbetgrbm`
- **endpoint**: `https://data.snb.ch/api/cube/bakredbetgrbm/data/json/en`
- **call**: `snb_fetch("bakredbetgrbm", title = "Corporate loans, broken down by company size")`

## Parsing recipe
- `/dimensions/en` for code->label and the nested hierarchy; `/data/json/en` for
  observations.
- `metadata.key` carries the four dimension codes in `dim_order`
  (`D0,D1,D2,D3`); `.snb_key_codes` splits the braces and binds them.
- Keep non-null values, parse `date` (month start) to ISO, cast numeric. Values
  in CHF millions.
- `PublishingDate` header is the freshness signal. JSON+CSV only, no SA toggle.

## Dimensions
- `D0` Bank category: `AV1` banks in Switzerland, `AV2` cantonal, `AV3` big,
  `AV4` regional and savings, `AV10` Raiffeisen.
- `D1` Company size: `KC5A` <=9 employees, `KC5B` 10-49, `KC5C` 50-249, `KC5D`
  250+, `KC5E` public-sector entities.
- `D2` Type of loan: `T1` total loans, `H` mortgage loans, then under the
  grouping node `K` (other loans, non-data): `T2` total, `G` secured, `U`
  unsecured.
- `D3` Utilisation and credit lines: `F` utilisation (drawn), `B` credit lines
  (granted).

## Display
- **split**: D1
- **single-select**: D0, D2, D3
- **default**: D1=KC5A, D0=AV1, D2=T1, D3=F
- **transform**: level
- **seasonal adjustment**: n/a (no SA dimension; stock series at month end)

## Caveats / simplifications
- `K` (other loans) is a grouping node (`data: false`); only its children
  `T2/G/U` carry series.
- Source label typo preserved in dictionary: "50 to 249 employes".
- Not every size x bank x loan-type x utilisation cell is populated; 150 stored
  series are the non-empty combinations.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `bakredbetgrbm`, title/topic from
`R/snb_cubes.tsv`). Datasheet authored 2026-06-01.

## What is special (de)
Wie viel Schweizer Banken Unternehmen nach Unternehmensgrösse ausleihen, als gewährter Kredit und als tatsächlich beanspruchter Betrag, sodass der Spielraum sichtbar wird.

## What is special (fr)
Combien les banques suisses prêtent aux entreprises selon leur taille, en crédit accordé et en montant effectivement utilisé, si bien que la marge est visible.

## What is special (it)
Quanto le banche svizzere prestano alle imprese per dimensione, come credito concesso e come importo effettivamente utilizzato, così il margine è visibile.
