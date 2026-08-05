# Consumer Price Index (LIK) – national index, long history

- **id**: ch_snb_plkopr
- **title**: Consumer prices (CPI) | de: Konsumentenpreise (LIK) | fr: Prix à la consommation (IPC) | it: Prezzi al consumo (IPC)
- **concept**: Prices / Consumer prices
- **canonical**: yes
- **featured**: Inflation
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1921-01 .. 2026-04
- **series**: 1

## What is special
The Swiss headline consumer price index (Landesindex der Konsumentenpreise), as
re-disseminated by the SNB. It is the **canonical CPI for the long view**: the SNB
chain reaches back to **January 1921** — over a century — whereas the detailed FSO
asset (`ch_fso_cpi`, the labelled alternate) only carries the full COICOP position
hierarchy from December 1982. So this is the series to reach for when you want the
headline index or year-on-year inflation across the whole modern history of the
Swiss franc; `ch_fso_cpi` is the one to reach for when you want the 443-position
basket breakdown. The cube carries the **total index only** (no sub-baskets). The
source ships two measures under one flat `D0` dimension — the index level (rebased
December 2025 = 100) and its year-on-year change — but the change is dropped (it is
the app's YoY % toggle applied to the index), so this is a single-series dataset:
just the index level.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `plkopr`
- **endpoint**: `https://data.snb.ch/api/cube/plkopr/data/json/en`
- **call**: `snb_fetch("plkopr", title = "Consumer Price Index (LIK) – national index, long history")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube `plkopr`.
- Single dimension `D0`; `metadata.key` `{...}` carries one code. One long row per
  non-null observation with `date` (ISO month start) and numeric `value`.
- `D0` has two data-bearing codes (`LD2010100` index, `VVP` YoY change); `VVP` is
  dropped downstream, leaving a single value, so `D0` collapses to a single-series
  dataset (no dimension).

## Dimensions
- None: the source's `D0` Overview dimension (`LD2010100` National index,
  December 2025 = 100; `VVP` year-on-year change in %) collapses once `VVP` is dropped
  as a redundant transform, leaving just the index level as a single series.

## Display
- **split**: n/a (single series)
- **single-select**: n/a
- **default**: n/a
- **transform**: yoy
- **seasonal adjustment**: n/a (the CPI is not seasonally adjusted)

## Caveats / simplifications
- Total index only — no COICOP sub-baskets. For the position hierarchy use the
  FSO alternate `ch_fso_cpi`.
- The index code label still reads "December 2025 = 100"; the base period
  follows whatever rebasing the SNB currently publishes.
- The source's `VVP` (YoY rate of the same index) is dropped, not stored: the app's
  YoY % toggle on the index gives the same figure. This is why the opening
  **transform** defaults to `yoy` — inflation is the headline read of a CPI.

## Provenance
Script: `R/source_snb.R::snb_fetch` (title/topic from `R/snb_cubes.tsv`). Datasheet
authored 2026-06-02; coverage verified live 2026-06-02 (1921-01 .. 2026-04).

## What is special (de)
Der Schweizer Landesindex der Konsumentenpreise, weiterveröffentlicht durch die
SNB. Er ist der **kanonische LIK für die lange Sicht**: Die SNB-Kette reicht zurück
bis **Januar 1921** — über ein Jahrhundert — während die detaillierte BFS-Quelle
(`ch_fso_cpi`, die gekennzeichnete Alternative) die vollständige
COICOP-Positionshierarchie erst ab Dezember 1982 führt. Diese Reihe ist also die
richtige, wenn Sie den Gesamtindex oder die Jahresteuerung über die gesamte moderne
Geschichte des Frankens brauchen; `ch_fso_cpi` ist die richtige, wenn Sie die
Aufgliederung des Warenkorbs mit 443 Positionen brauchen. Der Würfel enthält
**ausschliesslich den Gesamtindex** (keine Teilkörbe). Die Quelle liefert zwei
Messgrössen unter einer flachen `D0`-Dimension — den Indexstand (Basis Dezember
2025 = 100) und dessen Vorjahresveränderung —, doch die Veränderung wird
weggelassen (sie ist der YoY-%-Umschalter der App auf den Index angewendet). Somit
ist dies ein Einzelreihen-Datensatz: nur der Indexstand.

## What is special (fr)
L'indice suisse des prix à la consommation (Landesindex der Konsumentenpreise),
rediffusé par la BNS. C'est l'**IPC de référence pour la vue longue** : la chaîne
BNS remonte à **janvier 1921** — plus d'un siècle — alors que la source détaillée
de l'OFS (`ch_fso_cpi`, l'alternative étiquetée) ne porte la hiérarchie complète
des positions COICOP que depuis décembre 1982. C'est donc la série à retenir pour
l'indice global ou l'inflation sur un an sur toute l'histoire moderne du franc ;
`ch_fso_cpi` est celle à retenir pour la ventilation du panier en 443 positions. Le
cube ne porte **que l'indice total** (pas de sous-paniers). La source livre deux
mesures sous une dimension `D0` plate — le niveau de l'indice (rebasé décembre
2025 = 100) et sa variation sur un an — mais la variation est écartée (c'est le
bouton de variation annuelle de l'application appliqué à l'indice). Il s'agit donc
d'un jeu de données à série unique : le seul niveau de l'indice.

## What is special (it)
L'indice svizzero dei prezzi al consumo (Landesindex der Konsumentenpreise),
ridiffuso dalla BNS. È l'**IPC di riferimento per la visione lunga**: la catena BNS
risale al **gennaio 1921** — oltre un secolo — mentre la fonte dettagliata dell'UST
(`ch_fso_cpi`, l'alternativa etichettata) porta la gerarchia completa delle
posizioni COICOP solo dal dicembre 1982. È quindi la serie da usare per l'indice
generale o per l'inflazione annua lungo tutta la storia moderna del franco;
`ch_fso_cpi` è quella da usare per la ripartizione del paniere in 443 posizioni. Il
cubo riporta **solo l'indice totale** (nessun sottopaniere). La fonte fornisce due
misure sotto un'unica dimensione piatta `D0` — il livello dell'indice (base
dicembre 2025 = 100) e la sua variazione annua — ma la variazione è esclusa (è il
pulsante di variazione annua dell'applicazione applicato all'indice). Si tratta
quindi di un set di dati a serie singola: il solo livello dell'indice.
