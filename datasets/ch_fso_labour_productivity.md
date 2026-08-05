# Labour productivity (GDP per hour worked)

- **id**: ch_fso_labour_productivity
- **title**: Labour productivity | de: Arbeitsproduktivität | fr: Productivité du travail | it: Produttività del lavoro
- **concept**: National accounts / Labour productivity
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 1991 .. 2024
- **series**: 3

## What is special
Swiss output per hour worked, with real GDP and total hours on the same index base, so the productivity trend reads off one chart.

## Access
- **type**: fso-dam-csv — FSO DAM asset, master is a long CSV (not xlsx)
- **order number**: `ts-x-04.07.01.01` (asset 36178401)
- **call**: `fso_labour_productivity("ch_fso_labour_productivity")`

## Parsing recipe
- `fso_dam_csv_download("ts-x-04.07.01.01")` resolves + downloads the CSV master;
  read with `fileEncoding = "UTF-8-BOM"` (the file carries a BOM).
- Columns `PERIOD, INDICATOR, UNIT_MEA, VALUE, OBS_STATUS`. Key the dimension on
  `INDICATOR` (`GDP` / `Actual hours worked` / `Productivity`) — NOT on `UNIT_MEA`,
  which is the constant `"Index"` for all three (the legacy "duplicate idx" trap).
- `PERIOD` (year) → first-of-year ISO date.

## Dimensions
- `indicator`: `gdp` GDP volume, `hours` actual hours worked, `productivity` GDP per
  hour worked (the default).

## Labels
- **units**: Index (1991 = 100), chained volume (previous year's prices) | de: Index (1991 = 100), verkettete Volumen (Vorjahrespreise) | fr: Indice (1991 = 100), volumes chaînés (prix de l'année précédente) | it: Indice (1991 = 100), volumi concatenati (prezzi dell'anno precedente)
- dim: indicator
  - **label**: Indicator | de: Indikator | fr: Indicateur | it: Indicatore
  - gdp: Gross domestic product (volume) | de: Bruttoinlandprodukt (Volumen) | fr: Produit intérieur brut (volume) | it: Prodotto interno lordo (volume)
  - hours: Actual hours worked | de: Tatsächliche Arbeitsstunden | fr: Heures effectives de travail | it: Ore di lavoro effettive
  - productivity: Labour productivity (GDP per hour worked) | de: Arbeitsproduktivität (BIP pro Arbeitsstunde) | fr: Productivité du travail (PIB par heure travaillée) | it: Produttività del lavoro (PIL per ora lavorata)

## Display
- **split**: indicator
- **single-select**:
- **default**: indicator=productivity
- **transform**: level
- **seasonal adjustment**: n/a (annual)

## Caveats / simplifications
- It is an **index** (1991 = 100), not a level (CHF/hour) and not a %-change. Sibling
  FSO assets give current-price levels and by-branch/region cuts if wanted later.

## Provenance
Script: `R/source_fso_dam_csv.R::fso_labour_productivity` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-02 (productivity 2024 = 146.0786, exact match).

## What is special (de)
Schweizer Produktion pro Arbeitsstunde, mit realem BIP und Gesamtstunden auf derselben Indexbasis, sodass der Produktivitätstrend aus einer Grafik ablesbar ist.

## What is special (fr)
Production suisse par heure travaillée, avec le PIB réel et le total des heures sur la même base d'indice, si bien que la tendance de productivité se lit sur un seul graphique.

## What is special (it)
Produzione svizzera per ora lavorata, con PIL reale e ore totali sulla stessa base d'indice, così l'andamento della produttività si legge da un solo grafico.
