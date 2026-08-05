# Retail trade turnover (monthly)

- **id**: ch_fso_retail
- **title**: Retail trade turnover | de: Detailhandelsumsätze | fr: Chiffres d'affaires du commerce de détail | it: Fatturato del commercio al dettaglio
- **concept**: Domestic economy / Retail trade turnover
- **canonical**: yes
- **featured**: Retail trade

- **source**: fso
- **license**: fso - **frequency**: monthly
- **coverage**: 2000-01 .. 2026-04
- **series**: see provenance
- **updated**: 2026-05 (latest observation)

## What is special
The monthly retail trade turnover index — the headline read on Swiss consumer
spending. FSO **moved this series off the retired PX-Web STAT-TAB onto its SDMX
endpoint**. We keep the retail slice: NOGA division 47 (retail trade) and its
sub-classes. Each series comes in
several adjustment variants (raw, calendar-adjusted, seasonally + calendar adjusted)
and several indicator/result-type combinations (nominal total/domestic/foreign
turnover, real production volume; index vs. year-on-year change).

## Access
- **type**: fso-sdmx — FSO SDMX (disseminate.stats.swiss, agency CH1.KEU)
- **flow**: `CH1.KEU/DF_KEU_M1/1.0.0`
- **endpoint / order number**: flow `DF_KEU_M1` version `1.0.0`
  - data: `https://disseminate.stats.swiss/rest/data/CH1.KEU,DF_KEU_M1,1.0.0/all?detail=dataonly` (Accept: `application/vnd.sdmx.data+csv`)
  - structure: `https://disseminate.stats.swiss/rest/dataflow/CH1.KEU/DF_KEU_M1/1.0.0?references=all` (Accept: `application/vnd.sdmx.structure+json`)
- **call**: `fso_sdmx_fetch("ch_fso_retail", "CH1.KEU", "DF_KEU_M1", "1.0.0", title = list(en = "Retail trade turnover (monthly)"), noga_keep = <47*>)`

## Parsing recipe
SDMX-CSV: one column per DSD dimension (`NOGA`, `ADJUSTMENT`, `INDICATOR_KE`,
`UNIT_MEASURE`, `FREQ`) plus `TIME_PERIOD` (`YYYY-MM`) and `OBS_VALUE`. `FREQ` is
constant (M) and dropped. `TIME_PERIOD` is mapped to an ISO first-of-month date via
`to_iso()` (R/dates.R); NA values dropped. The four dimension codes are mapped to
English labels from the structure codelists `CL_NOGA_KE`, `CL_SEASONAL_ADJUST`,
`CL_INDICATOR_KE`, `CL_PRICES_RESULT_TYPE`. We filter NOGA to the retail division 47
codes (`47`, `4711`, `472`, `473`, …, `47P*`).

## Dimensions
- `NOGA` — retail trade activity. `47` is the headline total retail trade; the rest
  are sub-classes (food / non-food, fuel, specialised stores, etc.).
- `ADJUSTMENT` — seasonal-adjustment variant (`N` raw, `W` calendar adjusted, `Y`
  seasonally + calendar adjusted).
- `INDICATOR_KE` — turnover concept (`UTOT` total nominal, `UINL` domestic, `UEXP`
  foreign, `PTOT` real production volume).

The flow also carries a `UNIT_MEASURE` dimension (`IX` index, `VARM-12` year-on-year
change, `VARM-1` month-on-month change). We keep only the index `IX` and drop the two
change levels — they are exactly the app's YoY % and month-on-month transforms,
recomputed from the index — which collapses `UNIT_MEASURE` away entirely.

## Display
- **split**: NOGA
- **single-select**: ADJUSTMENT, INDICATOR_KE
- **default**: NOGA=47, ADJUSTMENT=Y, INDICATOR_KE=UTOT
- **transform**: level
- **seasonal adjustment**: single-select on `ADJUSTMENT`; default to seasonally +
  calendar adjusted (`Y`); raw (`N`) and calendar-only (`W`) available as toggles.

## Hierarchy
`47 Retail trade` is the total; the specialised-store divisions, the non-specialised
classes and the alternative totals sit under it, with the by-class-of-goods breakdown
(`47P`) as its own sub-branch.
- 47
  - 472
  - 473
  - 474
  - 475
  - 476
  - 477
  - 478_479
  - 4711
  - 4719
  - 4711_472
  - 4719_474-479
  - 47x473
  - 47PxTreib
  - 47P
    - 47P_Food
    - 47P_Bekl
    - 47P_Treib
    - 47P_UW

## Caveats / simplifications
- Only the retail division 47 NOGA codes are kept; the full `DF_KEU_M1` flow also
  carries the secondary sector and the rest of the tertiary sector (those live in
  `ch_fso_production` and could seed further datasets).
- The flow mixes index levels and change rates in `UNIT_MEASURE`; only the index
  (`IX`) is kept, since the change rates duplicate the app's transform toggle.

## Provenance
Script: `R/source_fso_sdmx.R::fso_sdmx_fetch` (wired in `R/pipeline.R`). Datasheet
authored 2026-06-01; parser verified 2026-06-01.

## What is special (de)
Der monatliche Detailhandelsumsatzindex — der Leitindikator für den Schweizer
Konsum. Das BFS hat diese Reihe **von der abgelösten STAT-TAB-Plattform auf
seinen SDMX-Endpunkt verschoben**. Wir übernehmen den Detailhandels-Ausschnitt:
NOGA-Abteilung 47 (Detailhandel) und ihre Unterklassen. Jede Reihe liegt in
mehreren Bereinigungsvarianten vor (unbereinigt, kalenderbereinigt, saison- und
kalenderbereinigt) sowie in mehreren Indikator- und Ergebnistyp-Kombinationen
(nominaler Gesamt-, Inland- und Auslandumsatz, reales Produktionsvolumen; Index
oder Veränderung gegenüber dem Vorjahr).

## What is special (fr)
L'indice mensuel du chiffre d'affaires du commerce de détail — l'indicateur
phare de la consommation suisse. L'OFS a **déplacé cette série de l'ancienne
plateforme STAT-TAB vers son point d'accès SDMX**. Nous reprenons la partie
commerce de détail : la division NOGA 47 (commerce de détail) et ses
sous-classes. Chaque série existe en plusieurs variantes de correction (brute,
corrigée des effets de calendrier, corrigée des variations saisonnières et des
effets de calendrier) et en plusieurs combinaisons d'indicateur et de type de
résultat (chiffre d'affaires nominal total, intérieur, étranger ; volume de
production réel ; indice ou variation sur un an).

## What is special (it)
L'indice mensile del fatturato del commercio al dettaglio — l'indicatore
principale dei consumi svizzeri. L'UST ha **spostato questa serie dalla
piattaforma STAT-TAB dismessa al proprio endpoint SDMX**. Riprendiamo la parte
relativa al commercio al dettaglio: la divisione NOGA 47 (commercio al
dettaglio) e le sue sottoclassi. Ogni serie è disponibile in più varianti di
correzione (grezza, corretta per gli effetti di calendario, destagionalizzata e
corretta per gli effetti di calendario) e in più combinazioni di indicatore e
tipo di risultato (fatturato nominale totale, interno ed estero; volume di
produzione reale; indice o variazione rispetto all'anno precedente).
