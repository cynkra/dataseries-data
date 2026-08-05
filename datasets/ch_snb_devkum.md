# Foreign exchange rates – Month

- **id**: ch_snb_devkum
- **title**: Bilateral exchange rates | de: Bilaterale Wechselkurse | fr: Taux de change bilatéraux | it: Tassi di cambio bilaterali
- **concept**: Exchange rates / Bilateral FX
- **canonical**: yes
- **featured**: Exchange rates
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1914-01 .. 2026-04
- **series**: 54
- **updated**: 2026-04 (latest observation)

## What is special
The headline bilateral CHF exchange-rate table, with a history reaching back to
**1914**, the longest FX record in the catalog. Quotes are CHF per foreign-currency
unit, with the unit baked into each currency label (EUR 1, GBP 1, but DKK 100, JPY
100, etc.), so the multiplier matters when comparing rates. Each currency is
published as both a **monthly average** (M0) and an **end-of-month** value (M1).
Beyond spot rates it carries two **USD forward rates** (3-month and 6-month, CHF per
1 USD), which is unusual for a spot-rate table. Currencies are grouped by region
(Europe, America, Africa, Asia and Australia, SDR, USD forward rates); the group
nodes are non-data headers. Note the CSV begins well after 1914 for most currencies
(e.g. ARS from 1999); the 1914 start reflects the earliest long series (USD/major
European), not every pair.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `devkum`
- **endpoint**: `https://data.snb.ch/api/cube/devkum/data/json/en`
- **call**: `snb_fetch("devkum", title = "Foreign exchange rates – Month")`

## Parsing recipe
- Fetch `/dimensions/en` (code -> label tree, with nested `dimensionItems`) and
  `/data/json/en` (the observations) for cube `devkum`.
- Each timeseries `metadata.key` (e.g. `...{M0,USD1}`) carries the dimension-item
  codes in `dim_order` order; `.snb_key_codes` extracts them from the `{...}` block.
- One long row per non-null observation: `D0`, `D1`, `date`, `value`. Dates are
  ISO month starts; values numeric.
- Non-data grouping nodes (`D1_0` Europe, `D1_1` America, ...) carry no key and never
  appear as rows; they survive only as `hierarchy` in the dimension tree.

## Dimensions
- `D0` Monthly average/End of month: `M0` monthly average, `M1` end of month.
- `D1` Currency: ISO-ish codes with the quote unit embedded (`EUR1`, `GBP1`,
  `DKK100`, `JPY100`, `XDR1` for the SDR, `USD3M`/`USD6M` USD forward rates).
  Defaults to `USD1`.

## Display
- **split**: D1
- **single-select**: D0
- **default**: D1=USD1, D0=M0
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube, no SA dimension)

## Caveats / simplifications
- Quote convention is CHF per stated unit; the unit (1 vs 100) differs per currency.
- SNB has no seasonal-adjustment toggle; raw rates only.
- Coverage per currency varies widely; early history exists only for major pairs.

## Provenance
Script: `R/source_snb.R::snb_fetch` (title/topic from `R/snb_cubes.tsv`). Datasheet
authored 2026-06-01.

## What is special (de)
Die zentrale Tabelle der bilateralen Frankenkurse, mit einer Historie zurück bis
**1914** — der längste Devisenkurs-Datensatz im Katalog. Notiert wird CHF je
Fremdwährungseinheit, wobei die Einheit im Währungslabel steckt (EUR 1, GBP 1, aber
DKK 100, JPY 100 usw.); beim Vergleich von Kursen ist der Multiplikator daher
wesentlich. Jede Währung erscheint sowohl als **Monatsdurchschnitt** (M0) wie auch
als **Monatsendwert** (M1). Über die Kassakurse hinaus enthält sie zwei
**USD-Terminkurse** (3 und 6 Monate, CHF je 1 USD), was für eine Kassakurstabelle
ungewöhnlich ist. Die Währungen sind nach Region gruppiert (Europa, Amerika, Afrika,
Asien und Australien, SZR, USD-Terminkurse); die Gruppenknoten sind Überschriften
ohne eigene Daten. Zu beachten: Für die meisten Währungen beginnt die CSV deutlich
nach 1914 (z. B. ARS ab 1999); der Beginn 1914 spiegelt die frühesten langen Reihen
(USD und wichtige europäische Währungen), nicht jedes Währungspaar.

## What is special (fr)
Le tableau de référence des taux de change bilatéraux du franc, avec un historique
remontant à **1914** — le plus long relevé de change du catalogue. Les cotations
sont en CHF par unité de devise étrangère, l'unité étant intégrée au libellé de
chaque monnaie (EUR 1, GBP 1, mais DKK 100, JPY 100, etc.) ; le multiplicateur
compte donc lorsqu'on compare des taux. Chaque monnaie est publiée à la fois en
**moyenne mensuelle** (M0) et en **valeur de fin de mois** (M1). Au-delà des taux
au comptant, le tableau porte deux **taux à terme USD** (3 et 6 mois, CHF pour
1 USD), ce qui est inhabituel pour une table de taux au comptant. Les monnaies sont
groupées par région (Europe, Amérique, Afrique, Asie et Australie, DTS, taux à
terme USD) ; les nœuds de groupe sont des en-têtes sans données. À noter : pour la
plupart des monnaies, le CSV commence bien après 1914 (p. ex. ARS dès 1999) ; le
début en 1914 reflète les séries longues les plus anciennes (USD et grandes devises
européennes), pas chaque paire.

## What is special (it)
La tabella di riferimento dei tassi di cambio bilaterali del franco, con una
storia che risale al **1914** — la più lunga rilevazione di cambi del catalogo. Le
quotazioni sono in CHF per unità di valuta estera, con l'unità inclusa
nell'etichetta di ogni valuta (EUR 1, GBP 1, ma DKK 100, JPY 100 ecc.); il
moltiplicatore conta quindi nel confronto tra tassi. Ogni valuta è pubblicata sia
come **media mensile** (M0) sia come **valore di fine mese** (M1). Oltre ai tassi a
pronti, la tabella riporta due **tassi a termine USD** (3 e 6 mesi, CHF per 1 USD),
cosa insolita per una tabella di tassi a pronti. Le valute sono raggruppate per
regione (Europa, America, Africa, Asia e Australia, DSP, tassi a termine USD); i
nodi di gruppo sono intestazioni senza dati. Da notare: per la maggior parte delle
valute il CSV inizia ben dopo il 1914 (p. es. ARS dal 1999); l'inizio nel 1914
riflette le serie lunghe più antiche (USD e principali valute europee), non ogni
coppia.
