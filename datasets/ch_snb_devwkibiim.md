# Bilateral exchange rate indices – Monthly

- **id**: ch_snb_devwkibiim
- **title**: Bilateral exchange-rate indices | de: Bilaterale Wechselkursindizes | fr: Indices de taux de change bilatéraux | it: Indici dei tassi di cambio bilaterali
- **keywords**: Swiss franc, CHF, FX | de: Franken, Wechselkurs | fr: franc suisse, taux de change | it: franco svizzero, tasso di cambio
- **concept**: Exchange rates / Bilateral FX
- **canonical**: yes
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1973-01 .. 2026-04
- **series**: 324

## What is special
Swiss franc exchange-rate index levels against 54 partner currencies, nominal and inflation-adjusted (CPI- or PPI-based). Yearly changes are not stored; the YoY toggle derives them.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `devwkibiim`
- **endpoint**: `https://data.snb.ch/api/cube/devwkibiim/data/json/en`
- **call**: `snb_fetch("devwkibiim", title = "Bilateral exchange rate indices – Monthly")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube `devwkibiim`.
- `metadata.key` `{...}` gives `D0,D1,D2` codes in order; one long row per non-null
  observation, `date` ISO month start, numeric `value`.
- The `R` (Real) node under `D0` is a non-data grouping header whose leaves are `K`
  and `P`; only `N`, `K`, `P` bear data. Drop the `V` (change) rows downstream if a
  level-only view is wanted, but they are kept here as published.

## Dimensions
- `D0` Real/Nominal: `N` nominal, `K` real CPI-based, `P` real PPI-based (`R` is the
  non-data parent of K/P).
- `D1` Countries: ~54 ISO-style partner codes (`US`, `DE`, `JP`, `CN`, `GB`, ...).

The source's `D2` Index/Change dimension (`I` index, `V` YoY % change) is reduced to the
index: `V` is exactly the app's YoY % transform, derived from `I`, so storing it would
duplicate a button. Keeping only `I` collapses `D2` away.

## Labels
- **units**: Index, December 2000 = 100 | de: Index, Dezember 2000 = 100 | fr: Indice, décembre 2000 = 100 | it: Indice, dicembre 2000 = 100

## Display
- **split**: D1
- **single-select**: D0
- **default**: D1=US, D0=K
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes no SA toggle for this cube)

## Caveats / simplifications
- The YoY-change representation (`V`) is dropped, not stored: it is derived from the
  index and reproduced on the fly by the app's YoY % toggle.
- "Real" is two deflator variants (CPI vs PPI), not a single real series.
- SNB has no seasonal-adjustment toggle.

## Provenance
Script: `R/source_snb.R::snb_fetch` (title/topic from `R/snb_cubes.tsv`). Datasheet
authored 2026-06-01.

## What is special (de)
Indexstände des Frankenkurses gegenüber 54 Partnerwährungen, nominal und teuerungsbereinigt (KPI- oder PPI-basiert). Jahresveränderungen werden nicht gespeichert; die YoY-Ansicht leitet sie ab.

## What is special (fr)
Niveaux d'indice du cours du franc face à 54 monnaies partenaires, nominaux et corrigés de l'inflation (base IPC ou IPP). Les variations annuelles ne sont pas stockées ; l'affichage en variation annuelle les déduit.

## What is special (it)
Livelli dell'indice del corso del franco rispetto a 54 valute partner, nominali e corretti per l'inflazione (base IPC o IPP). Le variazioni annue non sono memorizzate; la vista in variazione annua le deriva.
