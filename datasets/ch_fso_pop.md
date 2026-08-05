# Permanent resident population (demographic balance)

- **id**: ch_fso_pop
- **title**: Resident population | de: Ständige Wohnbevölkerung | fr: Population résidante permanente | it: Popolazione residente permanente
- **concept**: Population & demographics / Resident population
- **canonical**: yes
- **featured**: Population
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 1861 .. 2024
- **series**: 11
- **updated**: 2025-08-27

## What is special
How Switzerland's population changes each year: births, deaths, immigration, emigration and naturalisations, with the stock at each year end.

## Access
- **type**: fso-dam-excel — FSO DAM Excel asset
- **order number**: su-d-01.02.04.05
- **call**: `fso_excel_download("su-d-01.02.04.05")`

## Parsing recipe
- Sheet `su-d-01.02.04.05`. Year in column 1; demographic components across the
  remaining columns, modelled as one dimension `item` with 11 levels.
- Older years record unavailable components as `...`; those cells are dropped, so
  coverage varies by component (population stocks / births / deaths / birth surplus
  / absolute change run the full 1861-2024 = 163 obs; immigration/emigration only
  43; adjustments 33; naturalisation 135).
- Column 13 (percentage change) is excluded as a ratio, not a person count.
- European number parsing wired in (all values here are plain integers).

## Dimensions
- `item`: demographic component (population stock, live births, deaths, birth
  surplus, immigration, emigration, migration balance, naturalisations,
  adjustments, ...). The source's `change_abs` ("absolute change") row is dropped —
  it is the first difference of the population stock, a trivial and rarely-used
  derivative the user can read straight off the stock series.

## Labels
- dim: item
  - **label**: Demographic component | de: Demografische Komponente | fr: Composante démographique | it: Componente demografica
  - pop_stock_jan: Population on 1 January | de: Bevölkerung am 1. Januar | fr: Population au 1er janvier | it: Popolazione al 1° gennaio
  - live_births: Live births | de: Lebendgeburten | fr: Naissances vivantes | it: Nati vivi
  - deaths: Deaths | de: Todesfälle | fr: Décès | it: Decessi
  - birth_surplus: Excess of births over deaths | de: Geburtenüberschuss | fr: Excédent des naissances | it: Eccedenza delle nascite
  - immigration: Immigration | de: Einwanderung | fr: Immigration | it: Immigrazione
  - emigration: Emigration | de: Auswanderung | fr: Émigration | it: Emigrazione
  - migration_bal: Net migration | de: Wanderungssaldo | fr: Solde migratoire | it: Saldo migratorio
  - naturalisation: Acquisition of Swiss citizenship | de: Erwerb des Schweizer Bürgerrechts | fr: Acquisition de la nationalité suisse | it: Acquisizione della cittadinanza svizzera
  - adjustments: Adjustments | de: Bereinigungen | fr: Ajustements | it: Rettifiche
  - pop_stock_dec: Population on 31 December | de: Bevölkerung am 31. Dezember | fr: Population au 31 décembre | it: Popolazione al 31 dicembre

## Display
- **split**: item
- **single-select**: 
- **default**: item=pop_stock_jan
- **transform**: level
- **seasonal adjustment**: n/a

The single `item` dimension is the breakdown a user compares as lines. The headline
default opens on the population stock on 1 January (`pop_stock_jan`), which spans the
full 1861-2024 history and is the natural headline for a resident-population series,
rather than the most-observations guess (`birth_surplus`). The flow components (births,
deaths, migration, naturalisations) are picked from the same list.

## Caveats / simplifications
- Per-cell drop of `...` means series have different start years; this is faithful
  to the source rather than padded.

## Provenance
Script: `R/source_fso_excel_sets.R::fso_excel_ch_fso_pop`. Datasheet 2026-06-01;
parser verified 2026-06-01 (1,395 rows, 11 series, 0 NA values).

## What is special (de)
Wie sich die Schweizer Bevölkerung jährlich verändert: Geburten, Todesfälle, Ein- und Auswanderung sowie Einbürgerungen, mit dem Bestand per Jahresende.

## What is special (fr)
Comment la population suisse évolue chaque année : naissances, décès, immigration, émigration et naturalisations, avec l'effectif en fin d'année.

## What is special (it)
Come cambia ogni anno la popolazione svizzera: nascite, decessi, immigrazione, emigrazione e naturalizzazioni, con l'effettivo a fine anno.
