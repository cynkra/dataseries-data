# Consumer sentiment index

- **id**: ch_seco_concon
- **title**: Consumer confidence | de: Konsumentenstimmung | fr: Climat de consommation | it: Clima di consumo
- **concept**: Business cycle & sentiment / Consumer confidence
- **canonical**: yes
- **featured**: Consumer confidence

- **source**: seco
- **license**: seco - **frequency**: quarterly
- **coverage**: 1972-Q4 .. 2026-Q2
- **series**: 26
- **updated**: 2026-05-05 (source publish date)

## What is special
The Swiss consumer sentiment survey, the canonical sentiment series, back to 1972 —
one of the longest survey histories in the catalog. SECO (the State Secretariat for
Economic Affairs) **runs** the survey and **publishes** the data directly in the
swissdata format, so this dataset is fetched at source and attributed to the true
producer. It **replaces** the earlier SNB re-export `ch_snb_concon`, which carried
the same numbers second-hand through the SNB cube API: the move corrects the
attribution and adds the seasonally-adjusted track that SECO publishes alongside the
raw balances.

The dataset exposes the headline **consumer sentiment index** (`ks_i63_index_q`) plus
the underlying balance components: past/expected economic situation, past/expected
prices, job security and unemployment outlook, past/future personal finances,
savings situation and outlook, and major-purchase timing. Each series is published
both raw (`na`) and seasonally + calendar adjusted (`csa`). The historical level
(1972–2023) has been re-aligned with the current methodology in use since 2024.

## Access
- **type**: seco-swissdata — SECO swissdata
- **set**: `ks-q`
- **endpoint** (2026-06: SECO retired the old `/dam/...download` URLs — they now 502 — and serves the machine-readable files via `scheduler.swissdatas.ch`, linked from the new page `seco.admin.ch/consumer-sentiment`. This is the long quarterly series since 1972 — `ks-q`; SECO also publishes a monthly `ks-m` and an experimental `ks-exp-m`):
  - data: `https://scheduler.swissdatas.ch/scheduled/ks-q.csv`
  - meta: `https://scheduler.swissdatas.ch/scheduled/ch-seco-ks-q.json`
- **call**: `seco_fetch("ch_seco_concon", data_url = <ks-q.csv>, meta_url = <ch-seco-ks-q.json>)`

## Parsing recipe
SECO already publishes the swissdata long format, so the fetch is a passthrough
(reuses `R/source_seco.R::seco_fetch`). The CSV is `structure,type,seas_adj,date,value`
with ISO first-of-quarter dates (`1972-10-01`). The JSON sidecar carries multilingual
`title`, `source_name`, `units`, `dim_order = [type, structure, seas_adj]`, and the
`labels` block (dimnames + per-code level labels). `.seco_dimensions()` maps `labels`
into the contract `dimensions` shape; there is no `hierarchy` in this source, so the
split/single-select/default below are declared here (the website derives them from
this datasheet, not from a hierarchy heuristic).

## Dimensions
- `structure` — survey item. `ks_i63_index_q` is the composite **6.3 Consumer
  sentiment index** (headline); the remaining codes are the component balances
  (`ks_i11_econ_hist_q` past economic situation, `ks_i12_econ_exp_q` economic outlook,
  `ks_i21_price_hist_q` / `ks_i22_price_exp_q` price situation/outlook,
  `ks_i31_job_secure_q` job security, `ks_i32_unemp_exp_q` unemployment outlook,
  `ks_i41_fin_pos_hist_q` / `ks_i42_fin_pos_exp_q` financial situation past/future,
  `ks_i51_save_q` saving, `ks_i52_spend_q` major-purchase timing, `ks_i53_save_exp_q`
  saving outlook, `ks_i62_index_q` the prior 6.2 index variant). All are data leaves.
- `type` — `index` (index points) or `sd` (standard deviation).
- `seas_adj` — `na` (raw) or `csa` (seasonally + calendar adjusted).

## Labels
- dim: structure
  - grp_prices: Prices | de: Preise | fr: Prix | it: Prezzi
  - grp_jobs: Employment | de: Beschäftigung | fr: Emploi | it: Occupazione
  - grp_saving: Saving | de: Sparen | fr: Épargne | it: Risparmio

## Display
- **split**: structure
- **single-select**: type, seas_adj
- **default**: structure=ks_i63_index_q, type=index, seas_adj=csa
- **transform**: level
- **seasonal adjustment**: single-select on `seas_adj`; default to the seasonally +
  calendar adjusted series (`csa`); raw (`na`) available as a toggle.

## Hierarchy
The headline **6.3 Consumer sentiment index** is the parent of the four sub-indices it
is actually computed from — expected economic development (1.2), past and expected
financial situation (4.1, 4.2) and the right time for major purchases (5.2) — per the
SECO methodology (BFS June-2024 survey publication). The remaining survey balances are
grouped by theme; the retired 6.2 index variant sits on its own.
- ks_i63_index_q
  - ks_i12_econ_exp_q
  - ks_i41_fin_pos_hist_q
  - ks_i42_fin_pos_exp_q
  - ks_i52_spend_q
- ks_i11_econ_hist_q
- @grp_prices
  - ks_i21_price_hist_q
  - ks_i22_price_exp_q
- @grp_jobs
  - ks_i31_job_secure_q
  - ks_i32_unemp_exp_q
- @grp_saving
  - ks_i51_save_q
  - ks_i53_save_exp_q
- ks_i62_index_q

## Caveats / simplifications
- Producer attribution corrected: this is SECO's own publication, replacing the SNB
  re-export `ch_snb_concon` (retired). Same survey, fetched at source, with the SA
  track added.
- Values are survey balances / index points, not levels; the composite
  `ks_i63_index_q` is the series most users want.
- The pre-2024 history was re-based by SECO to align with the current methodology.

## Provenance
Script: `R/source_seco.R::seco_fetch` (wired in `R/pipeline.R`). Datasheet authored
2026-06-01; parser verified 2026-06-01.

## What is special (de)
Die Schweizer Konsumentenstimmungserhebung, die kanonische Stimmungsreihe,
zurück bis 1972 — eine der längsten Umfragehistorien im Katalog. Das SECO
(Staatssekretariat für Wirtschaft) **führt** die Erhebung durch und
**publiziert** die Daten direkt im swissdata-Format, weshalb dieser Datensatz an
der Quelle bezogen und dem tatsächlichen Produzenten zugeschrieben wird. Er
**ersetzt** den früheren SNB-Reexport `ch_snb_concon`, der dieselben Zahlen aus
zweiter Hand über die SNB-Würfel-API führte: Der Wechsel korrigiert die
Zuschreibung und ergänzt die saisonbereinigte Variante, die das SECO neben den
Rohsalden veröffentlicht.

Der Datensatz enthält den **Index der Konsumentenstimmung** (`ks_i63_index_q`)
sowie die zugrunde liegenden Saldokomponenten: vergangene und erwartete
Wirtschaftslage, vergangene und erwartete Preise, Arbeitsplatzsicherheit und
Arbeitslosigkeitserwartung, vergangene und künftige Finanzlage der Haushalte,
Sparsituation und Sparaussichten sowie der Zeitpunkt für grössere Anschaffungen.
Jede Reihe erscheint sowohl unbereinigt (`na`) als auch saison- und
kalenderbereinigt (`csa`). Das historische Niveau (1972–2023) wurde an die seit
2024 verwendete Methodik angeglichen.

## What is special (fr)
L'enquête suisse sur le climat de consommation, la série de référence en matière
de climat, remontant à 1972 — l'un des historiques d'enquête les plus longs du
catalogue. Le SECO (Secrétariat d'État à l'économie) **réalise** l'enquête et
**publie** les données directement au format swissdata ; ce jeu de données est
donc repris à la source et attribué au véritable producteur. Il **remplace** la
réexportation BNS `ch_snb_concon`, qui reprenait les mêmes chiffres de seconde
main via l'API des cubes de la BNS : le changement corrige l'attribution et
ajoute la variante corrigée des variations saisonnières que le SECO publie à
côté des soldes bruts.

Le jeu de données expose l'**indice du climat de consommation**
(`ks_i63_index_q`) ainsi que les composantes de solde sous-jacentes : situation
économique passée et attendue, prix passés et attendus, sécurité de l'emploi et
perspectives de chômage, situation financière passée et future des ménages,
situation et perspectives d'épargne, et opportunité des achats importants.
Chaque série paraît aussi bien brute (`na`) que corrigée des variations
saisonnières et des effets de calendrier (`csa`). Le niveau historique
(1972–2023) a été réaligné sur la méthodologie en vigueur depuis 2024.

## What is special (it)
L'indagine svizzera sul clima di consumo, la serie di riferimento in materia di
clima, risalente al 1972 — una delle storie d'indagine più lunghe del catalogo.
La SECO (Segreteria di Stato dell'economia) **conduce** l'indagine e
**pubblica** i dati direttamente nel formato swissdata; questo set di dati è
quindi ripreso alla fonte e attribuito al vero produttore. **Sostituisce** la
riesportazione BNS `ch_snb_concon`, che riportava le stesse cifre di seconda
mano tramite l'API dei cubi BNS: il passaggio corregge l'attribuzione e aggiunge
la variante destagionalizzata che la SECO pubblica accanto ai saldi grezzi.

Il set di dati espone l'**indice del clima di consumo** (`ks_i63_index_q`) e le
componenti di saldo sottostanti: situazione economica passata e attesa, prezzi
passati e attesi, sicurezza del posto di lavoro e prospettive di disoccupazione,
situazione finanziaria passata e futura delle economie domestiche, situazione e
prospettive di risparmio e momento opportuno per gli acquisti importanti. Ogni
serie è pubblicata sia grezza (`na`) sia destagionalizzata e corretta per gli
effetti di calendario (`csa`). Il livello storico (1972–2023) è stato riallineato
alla metodologia in uso dal 2024.
