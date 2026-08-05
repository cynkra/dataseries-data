# Gross domestic product (GDP)

- **id**: ch_seco_gdp
- **title**: Gross domestic product (GDP) | de: Bruttoinlandprodukt (BIP) | fr: Produit intérieur brut (PIB) | it: Prodotto interno lordo (PIL)
- **concept**: National accounts / GDP (output, expenditure, income)
- **canonical**: yes
- **featured**: GDP
- **source**: seco
- **license**: seco (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1980-01 .. 2025-10
- **series**: 660
- **updated**: 2026-02-23

## What is special
The Swiss quarterly national accounts, and the single richest dataset in the
catalog. SECO publishes it **already in the swissdata format at source** (a tidy
long CSV plus a JSON meta sidecar with full en/de/fr/it labels), so our fetcher is
a passthrough rather than a scrape.

Three things make it distinctive:
- **Deep hierarchy.** The `structure` dimension is a 68-code tree covering all
  three accounting views of GDP under one root (`gdp`): the **production** approach
  (gross value added by NOGA industry, down to chem/pharma vs other manufacturing
  and finance vs insurance), the **expenditure** approach (consumption, investment,
  the trade balance, exports/imports of goods and services), and the **income**
  approach (compensation of employees, operating surplus, GNI, disposable income).
  `production`, `expenditure` and `income` are non-leaf grouping nodes carried as
  `data: false`.
- **Seasonal adjustment is a real dimension**, not a separate dataset. `seas_adj`
  has four levels: raw (`na`), seasonally+calendar adjusted (`csa`), sports-event
  adjusted (`nasa`), and seasonally+calendar+sports-event adjusted (`cssa`). The
  sports-event correction (large international sporting bodies are domiciled in
  Switzerland and book revenue in event years) is a Swiss-specific quirk.
- **Canonical GDP for the catalog.** The SNB re-exports of the same series
  (`gdppn`, `gdpap`) were dropped in favour of this one, which is the original and
  carries the full breakdown and the native quarterly frequency. The FSO annual
  expenditure table (`ch_fso_gdp_use`) is a redundant alternate.

## Access
- **type**: seco-swissdata — SECO swissdata (long CSV + JSON meta sidecar, native format)
- **set**: `ch-seco-gdp`
- **endpoint** (2026-06: SECO retired the old `/dam/...download` URLs — they now 502 — and serves the machine-readable files via `scheduler.swissdatas.ch`, linked from the new page `seco.admin.ch/gross-domestic-product`):
  - data: `https://scheduler.swissdatas.ch/scheduled/ch-seco-gdp.csv`
  - meta: `https://scheduler.swissdatas.ch/scheduled/ch-seco-gdp.json`
- **call**: `seco_fetch("ch_seco_gdp")`

## Parsing recipe
- The CSV is already long and tidy with columns `type,structure,seas_adj,date,value`.
  Read it, coerce `date` via `to_iso()` to `Date`, `value` to numeric, then
  `select(all_of(c(dim_order, "date", "value")))` and arrange.
- `dim_order` comes from the meta sidecar (`type, structure, seas_adj`); do not
  hardcode it.
- Remap the swissdata meta into our `dimensions` shape: `labels$dimnames[[d]]` is
  the dimension label, `labels[[d]][[code]]` is each level label (multilingual),
  and `hierarchy[[d]]` is the nested code tree (only `structure` has one). Units
  live under `meta$units$type`. `updated` = `updated_utc`; `notes` = `details`.
- No reshape, header rows, number-format cleanup, or date-serial decoding are
  needed; the source is already clean.

## Dimensions
- `type`: valuation / measure. `nom` (Swiss Francs at current prices), `real`
  (Swiss Francs, chain-linked volumes, reference year 2020), `gc_q` (contribution
  to real q-o-q GDP growth, percentage points), `gc_y` (contribution to real y-o-y
  GDP growth, percentage points). Single-select.
- `structure`: section, 68 codes in a production/expenditure/income hierarchy under
  root `gdp`. Leaf codes carry data; `production`, `expenditure`, `income` are
  grouping nodes (`data: false`). This is the split / multi-select dimension (the
  one with a `hierarchy`). NOGA industry ranges and ESA codes (B1GQ, P3, D1, etc.)
  are embedded in the labels.
- `seas_adj`: seasonal adjustment. `na` (raw), `csa` (seasonal+calendar), `nasa`
  (sports-event), `cssa` (seasonal+calendar+sports-event). Single-select.

## Display
- **split**: structure
- **single-select**: type, seas_adj
- **default**: structure=gdp, type=real, seas_adj=cssa
- **transform**: level
- **seasonal adjustment**: single-select; default to the **seasonally, calendar and
  sports-event adjusted** series (`cssa`) — the headline figure SECO itself reports.
  Swiss GDP carries value-added from major international sporting bodies domiciled
  here, which books in roughly four-year lumps; SECO's quarterly communiqués quote
  the sport-event-adjusted growth rate (e.g. "GDP adjusted for sporting events grew
  0.4% in Q1 2026"). The plain seasonally+calendar series (`csa`), raw (`na`) and
  sports-event-only (`nasa`) variants remain available as toggles. Opening on real
  (`type=real`), `cssa`, headline GDP total (`structure=gdp`) — not nominal
  consumption, which the most-observations heuristic would otherwise pick.

## Caveats / simplifications
- Series count (660) is the number of populated `type x structure x seas_adj`
  combinations, not 4 x 68 x 4; many cells are absent (e.g. growth-contribution
  `type`s exist mostly for the adjusted views and start later than 1980).
- The JSON meta carries no swissdata `dataseries` split/select UI hint, so none is
  passed through. The split dimension is inferred as the one with a `hierarchy`
  (`structure`); the others are single-select.
- Coverage start (1980) reflects the earliest level series; growth-contribution
  rows begin around 1990.

## Provenance
Script: `R/source_seco.R::seco_fetch`. Datasheet 2026-06-01; parser verified
2026-06-01 (107,100 rows, 660 series, span 1980-01 .. 2025-10).

## What is special (de)
Die vierteljährliche Volkswirtschaftliche Gesamtrechnung der Schweiz und der mit
Abstand reichhaltigste Datensatz im Katalog. Das SECO publiziert sie **bereits an
der Quelle im swissdata-Format** (eine schlanke Long-CSV plus JSON-Metadatei mit
vollständigen en/de/fr/it-Labels), weshalb unser Bezug eine Durchreiche und kein
Scraping ist.

Drei Dinge machen sie besonders:
- **Tiefe Hierarchie.** Die Dimension `structure` ist ein Baum mit 68 Codes, der
  alle drei Berechnungsansätze des BIP unter einer Wurzel (`gdp`) vereint: die
  **Produktionsseite** (Bruttowertschöpfung nach NOGA-Branche, bis hinunter zu
  Chemie/Pharma gegenüber übriger Industrie und Banken gegenüber Versicherungen),
  die **Verwendungsseite** (Konsum, Investitionen, Aussenbeitrag, Waren- und
  Dienstleistungsexporte/-importe) und die **Einkommensseite**
  (Arbeitnehmerentgelt, Betriebsüberschuss, BNE, verfügbares Einkommen).
  `production`, `expenditure` und `income` sind Gruppierungsknoten ohne eigene
  Daten (`data: false`).
- **Die Saisonbereinigung ist eine echte Dimension**, kein separater Datensatz.
  `seas_adj` hat vier Stufen: unbereinigt (`na`), saison- und kalenderbereinigt
  (`csa`), sportanlassbereinigt (`nasa`) sowie saison-, kalender- und
  sportanlassbereinigt (`cssa`). Die Sportanlass-Korrektur (grosse internationale
  Sportverbände haben ihren Sitz in der Schweiz und verbuchen Erträge in
  Turnierjahren) ist eine schweizerische Eigenheit.
- **Kanonisches BIP des Katalogs.** Die SNB-Reexporte derselben Reihe (`gdppn`,
  `gdpap`) wurden zugunsten dieser Quelle fallengelassen: Sie ist das Original,
  trägt die vollständige Gliederung und die native Quartalsfrequenz. Die jährliche
  BFS-Verwendungstabelle (`ch_fso_gdp_use`) ist eine redundante Alternative.

## What is special (fr)
Les comptes nationaux trimestriels de la Suisse, et de loin le jeu de données le
plus riche du catalogue. Le SECO le publie **déjà au format swissdata à la
source** (un CSV long et propre plus un fichier de métadonnées JSON avec des
libellés complets en/de/fr/it) ; notre récupération est donc un simple passage et
non un scraping.

Trois éléments le distinguent :
- **Hiérarchie profonde.** La dimension `structure` est un arbre de 68 codes
  réunissant les trois optiques du PIB sous une même racine (`gdp`) : l'optique
  **production** (valeur ajoutée brute par branche NOGA, jusqu'à chimie/pharma
  contre reste de l'industrie et banques contre assurances), l'optique **dépenses**
  (consommation, investissements, solde extérieur, exportations et importations de
  biens et services) et l'optique **revenus** (rémunération des salariés, excédent
  d'exploitation, RNB, revenu disponible). `production`, `expenditure` et `income`
  sont des nœuds de regroupement sans données propres (`data: false`).
- **La correction des variations saisonnières est une vraie dimension**, pas un
  jeu de données séparé. `seas_adj` compte quatre niveaux : brut (`na`), corrigé
  des variations saisonnières et des effets de calendrier (`csa`), corrigé des
  grands événements sportifs (`nasa`) et corrigé des trois à la fois (`cssa`). La
  correction sportive (de grandes fédérations internationales sont domiciliées en
  Suisse et comptabilisent leurs recettes les années de compétition) est une
  particularité suisse.
- **PIB de référence du catalogue.** Les réexportations BNS de la même série
  (`gdppn`, `gdpap`) ont été abandonnées au profit de celle-ci, qui est l'original
  et porte la ventilation complète ainsi que la fréquence trimestrielle native. Le
  tableau annuel des emplois de l'OFS (`ch_fso_gdp_use`) est une alternative
  redondante.

## What is special (it)
I conti nazionali trimestrali della Svizzera, di gran lunga il set di dati più
ricco del catalogo. La SECO li pubblica **già nel formato swissdata alla fonte**
(un CSV lungo e ordinato più un file di metadati JSON con etichette complete in
en/de/fr/it), quindi il nostro prelievo è un semplice inoltro e non uno scraping.

Tre elementi lo rendono particolare:
- **Gerarchia profonda.** La dimensione `structure` è un albero di 68 codici che
  riunisce le tre ottiche del PIL sotto un'unica radice (`gdp`): l'ottica della
  **produzione** (valore aggiunto lordo per ramo NOGA, fino a chimica/farmaceutica
  rispetto al resto dell'industria e banche rispetto alle assicurazioni), l'ottica
  della **spesa** (consumi, investimenti, saldo con l'estero, esportazioni e
  importazioni di beni e servizi) e l'ottica dei **redditi** (redditi da lavoro
  dipendente, risultato di gestione, RNL, reddito disponibile). `production`,
  `expenditure` e `income` sono nodi di raggruppamento senza dati propri
  (`data: false`).
- **La destagionalizzazione è una vera dimensione**, non un set di dati separato.
  `seas_adj` ha quattro livelli: grezzo (`na`), destagionalizzato e corretto per
  gli effetti di calendario (`csa`), corretto per i grandi eventi sportivi
  (`nasa`) e corretto per tutti e tre (`cssa`). La correzione sportiva (grandi
  federazioni internazionali hanno sede in Svizzera e contabilizzano i ricavi
  negli anni di competizione) è una particolarità svizzera.
- **PIL di riferimento del catalogo.** Le riesportazioni BNS della stessa serie
  (`gdppn`, `gdpap`) sono state abbandonate a favore di questa fonte, che è
  l'originale e porta la ripartizione completa e la frequenza trimestrale nativa.
  La tabella annuale degli impieghi dell'UST (`ch_fso_gdp_use`) è un'alternativa
  ridondante.
