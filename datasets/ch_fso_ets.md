# Employed persons by economic sector and sex (ETS)

- **id**: ch_fso_ets
- **title**: Employed persons (ETS) | de: Erwerbstätige (ETS) | fr: Personnes actives occupées (SPAO) | it: Persone occupate (SPO)
- **concept**: Labour / Employment / employed persons
- **canonical**: no (alternate / sector-and-sex breakdown of the employment concept; `ch_fso_besta` is the headline)
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1991-04 .. 2025-10
- **series**: 69
- **updated**: 2026-03-17

## What is special
Employment statistics (ETS): the number of employed persons on the domestic
concept, cut by economic sector and by sex. Where BESTA counts jobs by fine NOGA
division, ETS counts people and carries the full sector tree on one axis, so the
male/female split of any sector reads directly off the chart.

## Access
- **type**: fso-dam-csv — FSO DAM asset, master is a long CSV (not xlsx)
- **order number**: `ts-x-03.02.01.08` (asset 36461448)
- **call**: `fso_ets("ch_fso_ets")`

## Parsing recipe
- `fso_dam_csv_download("ts-x-03.02.01.08")` resolves + downloads the CSV master;
  read with `fileEncoding = "UTF-8-BOM"` (the file carries a BOM).
- Columns `INDICATORS_HRCHY, INDICATORS_FR/DE, GENDER_FR/DE, DETAILS_FR/DE,
  PERIOD, FREQ, MEASURE_FR/DE, VALUE, STATUS`.
- **Filter `FREQ == "Q"`** to keep quarterly averages and drop the annual `A`/`Y`
  rows (those repeat the year as one observation and would double-count).
- Sector dimension is keyed on `INDICATORS_HRCHY` (`P`, `P_1..P_3`, `P_x_y`); the
  NOGA section letter is in `DETAILS_DE` (`A`, `B-F`, `G-T`, single letters) and
  drives the authored EN labels. Sex is recoded from `GENDER_DE`
  (`Total`/`Männer`/`Frauen` → `total`/`male`/`female`).
- `PERIOD` is `YYYY-Qn`; `to_iso()` maps it to a first-of-quarter ISO `date`
  (Q1→01-01, Q2→04-01, Q3→07-01, Q4→10-01).
- NA `VALUE` rows are dropped (the 1991-Q1 quarter is all NA, so the series start
  at 1991-Q2).

## Dimensions
- `sector` (Economic sector, hierarchical): `P` Total → `P_1` Sector 1
  (agriculture) / `P_2` Sector 2 (industry & construction) / `P_3` Sector 3
  (services); leaves are the NOGA-2008 sections (`P_1_1` A; `P_2_1` B-C, `P_2_2`
  D, `P_2_3` E, `P_2_4` F; `P_3_1` G … `P_3_14` T). 23 codes.
- `sex` (Sex): `total` Total, `male` Men, `female` Women.

## Labels
- **units**: Number of employed persons (domestic concept, quarterly average) | de: Anzahl Erwerbstätige (Inlandkonzept, Quartalsdurchschnitt) | fr: Nombre de personnes actives occupées (concept intérieur, moyenne trimestrielle) | it: Numero di persone occupate (concetto interno, media trimestrale)
- dim: sector
  - **label**: Economic sector | de: Wirtschaftssektor | fr: Secteur économique | it: Settore economico
  - P: Total | de: Total | fr: Total | it: Totale
  - P_1: Sector 1: Agriculture, forestry and fishing | de: Sektor 1: Land- und Forstwirtschaft, Fischerei | fr: Secteur 1 : agriculture, sylviculture et pêche | it: Settore 1: agricoltura, silvicoltura e pesca
  - P_1_1: A Agriculture, forestry and fishing | de: A Land- und Forstwirtschaft, Fischerei | fr: A Agriculture, sylviculture et pêche | it: A Agricoltura, silvicoltura e pesca
  - P_2: Sector 2: Industry and construction | de: Sektor 2: Industrie und Bau | fr: Secteur 2 : industrie et construction | it: Settore 2: industria e costruzioni
  - P_2_1: B-C Mining, quarrying and manufacturing | de: B-C Bergbau und verarbeitendes Gewerbe | fr: B-C Industries extractives et manufacturières | it: B-C Attività estrattive e manifatturiere
  - P_2_2: D Electricity, gas, steam and air conditioning supply | de: D Energieversorgung | fr: D Production et distribution d'énergie | it: D Fornitura di energia
  - P_2_3: E Water supply; sewerage, waste management and remediation | de: E Wasserversorgung und Abfallentsorgung | fr: E Production et distribution d'eau; gestion des déchets | it: E Fornitura d'acqua; gestione dei rifiuti
  - P_2_4: F Construction | de: F Baugewerbe | fr: F Construction | it: F Costruzioni
  - P_3: Sector 3: Services | de: Sektor 3: Dienstleistungen | fr: Secteur 3 : services | it: Settore 3: servizi
  - P_3_1: G Wholesale and retail trade; repair of motor vehicles | de: G Handel; Reparatur von Motorfahrzeugen | fr: G Commerce; réparation d'automobiles | it: G Commercio; riparazione di autoveicoli
  - P_3_2: H Transportation and storage | de: H Verkehr und Lagerei | fr: H Transports et entreposage | it: H Trasporto e magazzinaggio
  - P_3_3: I Accommodation and food service activities | de: I Gastgewerbe | fr: I Hébergement et restauration | it: I Alloggio e ristorazione
  - P_3_4: J Information and communication | de: J Information und Kommunikation | fr: J Information et communication | it: J Informazione e comunicazione
  - P_3_5: K Financial and insurance activities | de: K Finanz- und Versicherungsdienstleistungen | fr: K Activités financières et d'assurance | it: K Attività finanziarie e assicurative
  - P_3_6: L Real estate activities | de: L Grundstücks- und Wohnungswesen | fr: L Activités immobilières | it: L Attività immobiliari
  - P_3_7: M Professional, scientific and technical activities | de: M Freiberufliche, wissenschaftliche und technische Dienstleistungen | fr: M Activités spécialisées, scientifiques et techniques | it: M Attività professionali, scientifiche e tecniche
  - P_3_8: N Administrative and support service activities | de: N Sonstige wirtschaftliche Dienstleistungen | fr: N Activités de services administratifs et de soutien | it: N Attività amministrative e di servizi di supporto
  - P_3_9: O Public administration and defence; compulsory social security | de: O Öffentliche Verwaltung, Verteidigung, Sozialversicherung | fr: O Administration publique, défense, sécurité sociale | it: O Amministrazione pubblica, difesa, sicurezza sociale
  - P_3_10: P Education | de: P Erziehung und Unterricht | fr: P Enseignement | it: P Istruzione
  - P_3_11: Q Human health and social work activities | de: Q Gesundheits- und Sozialwesen | fr: Q Santé humaine et action sociale | it: Q Sanità e assistenza sociale
  - P_3_12: R Arts, entertainment and recreation | de: R Kunst, Unterhaltung und Erholung | fr: R Arts, spectacles et activités récréatives | it: R Attività artistiche e di intrattenimento
  - P_3_13: S Other service activities | de: S Sonstige Dienstleistungen | fr: S Autres activités de services | it: S Altre attività di servizi
  - P_3_14: T Activities of households as employers | de: T Private Haushalte als Arbeitgeber | fr: T Ménages en tant qu'employeurs | it: T Famiglie come datori di lavoro
- dim: sex
  - **label**: Sex | de: Geschlecht | fr: Sexe | it: Sesso
  - total: Total | de: Total | fr: Total | it: Totale
  - male: Men | de: Männer | fr: Hommes | it: Uomini
  - female: Women | de: Frauen | fr: Femmes | it: Donne

## Display
- **split**: sector
- **single-select**:
- **default**: sector=P, sex=total
- **transform**: level
- **seasonal adjustment**: n/a (quarterly averages, not seasonally adjusted)

## Caveats / simplifications
- **Domestic concept (Inlandkonzept)**: counts persons employed in Switzerland
  regardless of residence, so it differs from the resident-based labour-force
  count; not directly comparable with BESTA *jobs* magnitudes.
- The annual `A`/`Y` rows in the master are deliberately discarded — only the
  quarterly average (`FREQ=="Q"`) survives.
- The sector tree mixes aggregates and leaves under one column; the parent nodes
  (`P`, `P_1`, `P_2`, `P_3`) carry their own series and should be read as totals,
  not summed with their children.

## Provenance
Script: `R/source_fso_dam_csv.R::fso_ets` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-02 (Total P both sexes
2025-Q4 = 5,391,587; agriculture P_1 2025-Q4 = 114,803.9, exact match).
Display reworked 2026-06-03: split = sector (the hierarchical industry tree is the
set of lines), sex = exclusive single-select (Total / Men / Women); sector×sex is
a clean 23×3 rectangle so every chip is populated.
