# Jobs by economic division (quarterly)

- **id**: ch_fso_besta
- **title**: Jobs by economic division | de: Beschäftigte nach Wirtschaftsabteilung | fr: Emplois par division économique | it: Impieghi per divisione economica
- **concept**: Labour / Employment / jobs
- **canonical**: yes
- **featured**: Employment
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1991-07 .. 2026-01
- **series**: 60
- **updated**: not published (live PX-Web pull; latest observation 2026Q1)

## What is special
BESTA, the FSO employment statistics: the number of jobs in Switzerland by
economic division (NOGA), quarterly back to 1991. This is the canonical Swiss
employment series. Its defining feature is the **deep division hierarchy**: 60
NOGA aggregates from the grand total `5-96` down through sectors (`5-43` Sector
II, `45-96` Sector III) to individual two-digit divisions (e.g. `21`
Pharmaceuticals, `64` Financial services, `86` Human health). This lets you read
the structural shift of the Swiss economy (manufacturing flat, health and
business services up) off one table. CONCEPT-UNIVERSE flags an overlap with SNB
`ambeschkla` (employees by activity); BESTA is chosen as canonical because it is
the FSO authoritative jobs series with the finer NOGA breakdown.

## Access
- **type**: fso-pxweb — FSO PX-Web (json-stat2)
- **table id**: `px-x-0602000000_101`
- **endpoint / table id**: `px-x-0602000000_101` (node; real table at
  `.../px-x-0602000000_101/px-x-0602000000_101.px`)
- **call**: `fso_fetch("ch_fso_besta", "px-x-0602000000_101", besta_query,
  quarter_col = "Quartal", chunk_by = "Quartal", chunk_size = 40L)` with an
  explicit query (not `fso_fetch_auto`).

## Parsing recipe
- The full cube is ~60 divisions x 10 employment-rate levels x 3 sexes x ~139
  quarters (~250k cells), far over the 5000-cell cap. The query takes the
  **headline slice**: `Wirtschaftsabteilung` = all, `Beschäftigungsgrad` = item
  `TOT`, `Geschlecht` = item `TOT`, `Quartal` = all.
- Even the headline slice (60 x 139) exceeds the cap, so the call **chunks by
  `Quartal`** in groups of 40 quarters; each chunk is a separate POST and the
  parts are `rbind`-ed back together. Dimensions/metadata are stable across
  chunks.
- Time is a single `Quartal` code like `1991Q3`; `.fso_make_date` maps quarter q
  to month `(q-1)*3+1` and emits a first-of-quarter ISO `date`
  (Q1->01, Q2->04, Q3->07, Q4->10), frequency quarterly.
- Dimension **codes are German** even on `/en/` (`Wirtschaftsabteilung`,
  `Beschäftigungsgrad`, `Geschlecht`, `Quartal`); kept as stored column values.

## Dimensions
- `Wirtschaftsabteilung` (Economic division): 60 NOGA codes. `5-96` = total;
  `5-43` Sector II, `45-96` Sector III; `10-33` Manufacturing and its parts
  (`21` Pharmaceuticals, `26` Watches/electronics, ...); `41-43` Construction;
  service divisions `45`..`96`. Range codes like `10-12` are aggregates of the
  contained two-digit divisions.

The source's `Beschäftigungsgrad` (Employment rate) and `Geschlecht` (Gender) columns
only ever carry `TOT` here, so both are dropped: a one-option picker is pure noise. That
leaves `Wirtschaftsabteilung` as the single dimension.

## Display
- **split**: Wirtschaftsabteilung
- **single-select**:
- **default**: Wirtschaftsabteilung=5-96
- **transform**: level
- **seasonal adjustment**: n/a (no seasonal-adjustment dimension; only the total
  employment-rate, total-sex slice is fetched)

## Hierarchy
The NOGA division codes are contiguous ranges that nest by containment
(`5-96` Total ⊃ `5-43` Sector II ⊃ `10-33` Manufacturing ⊃ divisions); the tree is
derived from those ranges.
- derive: noga-range

## Caveats / simplifications
- Only the total-level, total-sex slice is captured. The full-time/part-time and
  men/women breakdowns of this exact table are dropped here; the sex breakdown
  lives in the sibling dataset `ch_fso_jobs_sex` (table `_102`).
- No `updated` date is published by the API; latest quarter stands in.

## Provenance
Script: `R/source_fso.R::fso_fetch` (explicit chunked query built in
`R/pipeline.R`). Datasheet authored 2026-06-01.

## What is special (de)
BESTA, die Beschäftigungsstatistik des BFS: die Zahl der Stellen in der Schweiz
nach Wirtschaftsabteilung (NOGA), vierteljährlich zurück bis 1991. Dies ist die
kanonische Schweizer Beschäftigungsreihe. Ihr prägendes Merkmal ist die **tiefe
Abteilungshierarchie**: 60 NOGA-Aggregate vom Gesamttotal `5-96` über die Sektoren
(`5-43` Sektor II, `45-96` Sektor III) bis zu einzelnen zweistelligen Abteilungen
(z. B. `21` Pharma, `64` Finanzdienstleistungen, `86` Gesundheitswesen). So lässt
sich der Strukturwandel der Schweizer Wirtschaft (Industrie flach, Gesundheit und
Unternehmensdienstleistungen im Aufwärtstrend) aus einer einzigen Tabelle
ablesen. CONCEPT-UNIVERSE markiert eine Überschneidung mit dem SNB-Würfel
`ambeschkla` (Beschäftigte nach Wirtschaftszweig); BESTA gilt als kanonisch, weil
es die massgebende BFS-Stellenreihe mit der feineren NOGA-Gliederung ist.

## What is special (fr)
BESTA, la statistique de l'emploi de l'OFS : le nombre d'emplois en Suisse par
division économique (NOGA), trimestriel depuis 1991. C'est la série suisse de
l'emploi de référence. Sa caractéristique majeure est la **hiérarchie détaillée
des divisions** : 60 agrégats NOGA, du total général `5-96` aux secteurs
(`5-43` secteur II, `45-96` secteur III) jusqu'aux divisions à deux chiffres
(p. ex. `21` pharmacie, `64` services financiers, `86` santé humaine). On y lit
la mutation structurelle de l'économie suisse (industrie stable, santé et
services aux entreprises en hausse) dans un seul tableau. CONCEPT-UNIVERSE
signale un recoupement avec le cube BNS `ambeschkla` (emplois par branche) ;
BESTA est retenue comme canonique parce qu'elle est la série de référence de
l'OFS avec la ventilation NOGA la plus fine.

## What is special (it)
BESTA, la statistica dell'impiego dell'UST: il numero di posti di lavoro in
Svizzera per divisione economica (NOGA), trimestrale a partire dal 1991. È la
serie svizzera dell'impiego di riferimento. Il suo tratto distintivo è la
**gerarchia dettagliata delle divisioni**: 60 aggregati NOGA, dal totale
generale `5-96` ai settori (`5-43` settore II, `45-96` settore III) fino alle
singole divisioni a due cifre (p. es. `21` farmaceutica, `64` servizi
finanziari, `86` sanità). Permette di leggere il mutamento strutturale
dell'economia svizzera (industria stabile, sanità e servizi alle imprese in
crescita) da un'unica tabella. CONCEPT-UNIVERSE segnala una sovrapposizione con
il cubo BNS `ambeschkla` (impieghi per ramo economico); BESTA è scelta come
canonica perché è la serie UST autorevole con la ripartizione NOGA più fine.
