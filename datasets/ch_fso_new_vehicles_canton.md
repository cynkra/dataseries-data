# New registrations of passenger cars by canton and fuel

- **id**: ch_fso_new_vehicles_canton
- **title**: New car registrations by canton and fuel | de: Neuzulassungen von Personenwagen nach Kanton und Treibstoff | fr: Nouvelles immatriculations de voitures par canton et carburant | it: Nuove immatricolazioni di automobili per cantone e carburante
- **concept**: Domestic economy / New vehicle registrations
- **canonical**: no (the headline is the national `ch_fso_new_vehicles`; this is the canton breakdown, also the monthly canton layer of maps.dataseries.org)
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2005 .. 2026
- **series**: 324
- **updated**: monthly

## What is special
New cars registered each month in each of the 26 cantons, by fuel. The canton is the holder's address, so company and leasing fleets count where the company is domiciled, which lifts the EV share in a few cantons.

## Access
- **type**: fso-sdmx — FSO SDMX (disseminate.stats.swiss), sliced to one key with the canton dimension open
- **flow**: `CH1.MFZ_IVS/DF_IVS_0_GENERAL_M/1.0.0` (agency `CH1.MFZ_IVS`, dataflow `DF_IVS_0_GENERAL_M`, version 1.0.0)
- **call**: `fso_sdmx_new_vehicles_canton("ch_fso_new_vehicles_canton")`

## Parsing recipe
- Same flow and slice as `ch_fso_new_vehicles`, with the first key segment open:
  KEY `._T.N.100..M` (DSD order `UV_HGDE_KT.UV_RV_OWNER_TYPE.UV_RV_REGISTRATION_TYPE.UV_RV_VEHICLE_GROUP_AND_TYPE.UV_RV_FUEL.FREQ`)
  leaves canton and fuel open and pins owner = `_T`, registration = `N` (new),
  vehicle group = `100` (passenger cars), FREQ = `M`.
- `UV_HGDE_KT` codes are the BFS canton numbers (`1`=ZH … `26`=JU), leading zeros
  stripped, plus `_T` (Switzerland). `_U` (canton unknown) is dropped. The fetcher
  stops if any of the 26 cantons is missing.
- `TIME_PERIOD` (`YYYY-MM`) → first-of-month ISO date.

## Dimensions
- `canton`: `_T` Switzerland, then the 26 cantons by BFS number. Not declared as a
  hierarchy: the cantons sum slightly below `_T` because `_U` is dropped.
- `fuel`: Total, then the component fuels nested under it, as in `ch_fso_new_vehicles`.

## Labels
- **units**: Number of new registrations | de: Anzahl Neuzulassungen | fr: Nombre de nouvelles immatriculations | it: Numero di nuove immatricolazioni
- dim: canton
  - **label**: Canton | de: Kanton | fr: Canton | it: Cantone
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
- dim: fuel
  - **label**: Fuel | de: Treibstoff | fr: Carburant | it: Carburante
  - _T: Total | de: Total | fr: Total | it: Totale
  - PC: Petrol | de: Benzin | fr: Essence | it: Benzina
  - PH: Petrol hybrid (HEV) | de: Benzin-Hybrid (HEV) | fr: Hybride essence (HEV) | it: Ibrido benzina (HEV)
  - DC: Diesel | de: Diesel | fr: Diesel | it: Diesel
  - DH: Diesel hybrid (HEV) | de: Diesel-Hybrid (HEV) | fr: Hybride diesel (HEV) | it: Ibrido diesel (HEV)
  - HP: Plug-in hybrid (petrol) | de: Plug-in-Hybrid (Benzin) | fr: Hybride rechargeable (essence) | it: Ibrido plug-in (benzina)
  - HD: Plug-in hybrid (diesel) | de: Plug-in-Hybrid (Diesel) | fr: Hybride rechargeable (diesel) | it: Ibrido plug-in (diesel)
  - EL: Electric (BEV) | de: Elektrisch (BEV) | fr: Électrique (BEV) | it: Elettrico (BEV)
  - FC: Fuel cell (hydrogen) | de: Brennstoffzelle (Wasserstoff) | fr: Pile à combustible (hydrogène) | it: Cella a combustibile (idrogeno)
  - GA: Gas | de: Gas | fr: Gaz | it: Gas
  - _O: Other | de: Andere | fr: Autres | it: Altri
  - NM: No motor | de: Ohne Motor | fr: Sans moteur | it: Senza motore

## Display
- **split**: fuel
- **single-select**: canton
- **default**: canton=_T, fuel=_T
- **transform**: level
- **seasonal adjustment**: n/a (raw registrations, as in `ch_fso_new_vehicles`)

## Caveats / simplifications
- Passenger cars only (vehicle group `100`), new (`N`) registrations only.
- `_U` (canton unknown) is dropped, about 4'000 cars over 2005–2026, so the
  cantons do not add up exactly to `_T`.
- Canton = holder's address. Fleet and leasing registrations land at the
  company's domicile.

## Provenance
Script: `R/source_fso_sdmx.R::fso_sdmx_new_vehicles_canton` (wired in `R/pipeline.R`).
Moved from the maps.dataseries.org pull script `scripts/pull_canton_sdmx.py` on 2026-09-18.

## What is special (de)
Monatliche Neuzulassungen von Personenwagen in jedem der 26 Kantone, nach Treibstoff. Massgebend ist die Adresse des Halters, deshalb zählen Firmen- und Leasingflotten am Firmensitz, was den E-Auto-Anteil in einigen Kantonen erhöht.

## What is special (fr)
Nouvelles immatriculations mensuelles de voitures dans chacun des 26 cantons, par carburant. C'est l'adresse du détenteur qui compte : les flottes d'entreprise et de leasing sont comptées au siège de l'entreprise, ce qui relève la part des électriques dans quelques cantons.

## What is special (it)
Nuove immatricolazioni mensili di automobili in ciascuno dei 26 cantoni, per carburante. Conta l'indirizzo del detentore: le flotte aziendali e di leasing sono contate presso la sede dell'azienda, il che alza la quota di elettriche in alcuni cantoni.
