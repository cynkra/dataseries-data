# Foreign cross-border commuters by canton of work

- **id**: ch_fso_cross_border_commuters
- **title**: Cross-border commuters | de: Grenzgängerinnen und Grenzgänger | fr: Frontaliers | it: Frontalieri
- **concept**: Labour / Cross-border commuters
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 2002-Q3 .. 2026-Q1
- **series**: 27

## What is special
Foreign workers commuting into Switzerland each day, by canton. Around 410,000 people, concentrated in Geneva, Ticino, Basel and Vaud.

## Access
- **type**: fso-sdmx — FSO SDMX (disseminate.stats.swiss), sliced to the national total
- **flow**: `CH1.GGS/DF_GGS_1/1.0.0` (agency `CH1.GGS`, dataflow `DF_GGS_1`, version 1.0.0)
- **call**: `fso_sdmx_cross_border_commuters("ch_fso_cross_border_commuters")`

## Parsing recipe
- One pre-sliced SDMX key `_T._T.Q._T.` (DSD order `NOGA.CNTRY.FREQ.SEX.WORK_CANTON`)
  pins the national total over NOGA / country-of-residence / sex, leaving the
  `WORK_CANTON` breakdown. Getting the axis order wrong silently returns a wrong slice.
- `WORK_CANTON` codes use standard BFS numbering (`1`=ZH … `26`=JU; `_T`=Switzerland);
  labels are mapped in the wrapper. `TIME_PERIOD` (`YYYY-Qn`) → first-of-quarter ISO.

## Dimensions
- `canton`: 26 cantons of work plus `_T` Switzerland total (the default).

## Labels
- **units**: Number of cross-border commuters (estimate) | de: Anzahl Grenzgängerinnen und Grenzgänger (Schätzung) | fr: Nombre de frontaliers (estimation) | it: Numero di frontalieri (stima)
- dim: canton
  - **label**: Canton of work | de: Arbeitskanton | fr: Canton de travail | it: Cantone di lavoro
  - _T: Switzerland (total) | de: Schweiz (Total) | fr: Suisse (total) | it: Svizzera (totale)
  - 1: Zurich | de: Zürich | fr: Zurich | it: Zurigo
  - 10: Fribourg | de: Freiburg | fr: Fribourg | it: Friburgo
  - 11: Solothurn | de: Solothurn | fr: Soleure | it: Soletta
  - 12: Basel-Stadt | de: Basel-Stadt | fr: Bâle-Ville | it: Basilea Città
  - 13: Basel-Landschaft | de: Basel-Landschaft | fr: Bâle-Campagne | it: Basilea Campagna
  - 14: Schaffhausen | de: Schaffhausen | fr: Schaffhouse | it: Sciaffusa
  - 15: Appenzell A.Rh. | de: Appenzell A.Rh. | fr: Appenzell Rh.-Ext. | it: Appenzello Esterno
  - 16: Appenzell I.Rh. | de: Appenzell I.Rh. | fr: Appenzell Rh.-Int. | it: Appenzello Interno
  - 17: St. Gallen | de: St. Gallen | fr: Saint-Gall | it: San Gallo
  - 18: Grisons | de: Graubünden | fr: Grisons | it: Grigioni
  - 19: Aargau | de: Aargau | fr: Argovie | it: Argovia
  - 2: Bern | de: Bern | fr: Berne | it: Berna
  - 20: Thurgau | de: Thurgau | fr: Thurgovie | it: Turgovia
  - 21: Ticino | de: Tessin | fr: Tessin | it: Ticino
  - 22: Vaud | de: Waadt | fr: Vaud | it: Vaud
  - 23: Valais | de: Wallis | fr: Valais | it: Vallese
  - 24: Neuchatel | de: Neuenburg | fr: Neuchâtel | it: Neuchâtel
  - 25: Geneva | de: Genf | fr: Genève | it: Ginevra
  - 26: Jura | de: Jura | fr: Jura | it: Giura
  - 3: Lucerne | de: Luzern | fr: Lucerne | it: Lucerna
  - 4: Uri | de: Uri | fr: Uri | it: Uri
  - 5: Schwyz | de: Schwyz | fr: Schwytz | it: Svitto
  - 6: Obwalden | de: Obwalden | fr: Obwald | it: Obvaldo
  - 7: Nidwalden | de: Nidwalden | fr: Nidwald | it: Nidvaldo
  - 8: Glarus | de: Glarus | fr: Glaris | it: Glarona
  - 9: Zug | de: Zug | fr: Zoug | it: Zugo

## Display
- **split**: canton
- **single-select**:
- **default**: canton=_T
- **transform**: level
- **seasonal adjustment**: n/a

## Caveats / simplifications
- Values are a **model-based estimate**, hence non-integer; stored unrounded and
  labelled "estimate". A second view (by country of residence, 37 countries) is
  available from the same flow but not shipped here.
- Definitional: foreign cross-border commuters of foreign nationality.

## Provenance
Script: `R/source_fso_sdmx.R::fso_sdmx_cross_border_commuters` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-02 (2565 rows, CH total 2026-Q1 = 413,320).
