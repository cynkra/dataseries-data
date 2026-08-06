# New registrations of passenger cars by fuel

- **id**: ch_fso_new_vehicles
- **title**: New car registrations by fuel | de: Neuzulassungen von Personenwagen nach Treibstoff | fr: Nouvelles immatriculations de voitures par carburant | it: Nuove immatricolazioni di automobili per carburante
- **concept**: Domestic economy / New vehicle registrations
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2005 .. 2026
- **series**: 12
- **updated**: monthly

## What is special
New cars registered in Switzerland each month by fuel: petrol, diesel, hybrid, plug-in and battery-electric. EVs were about 25% in spring 2026.

## Access
- **type**: fso-sdmx — FSO SDMX (disseminate.stats.swiss), sliced to the national total
- **flow**: `CH1.MFZ_IVS/DF_IVS_0_GENERAL_M/1.0.0` (agency `CH1.MFZ_IVS`, dataflow `DF_IVS_0_GENERAL_M`, version 1.0.0)
- **call**: `fso_sdmx_new_vehicles("ch_fso_new_vehicles")`

## Parsing recipe
- One pre-sliced SDMX key, **not** a whole-flow pull (the full cube is millions of
  rows over cantons × owner × registration × group × fuel). KEY `_T._T.N.100..M`
  pins geography = `_T` (Switzerland total), owner = `_T` (total), registration =
  `N` (first registration of NEW vehicles), vehicle group = `100` (passenger cars),
  leaves fuel (`UV_RV_FUEL`) open, FREQ = `M`.
- `_T` on fuel is the exact sum of the component fuels (verified), so it is kept as
  the headline Total and the components nest under it as a hierarchy.
- `TIME_PERIOD` (`YYYY-MM`) → first-of-month ISO date. The pinned single-value dims
  collapse out automatically (`drop_degenerate_dims`).

## Dimensions
- `fuel`: Total, then Petrol / Petrol-HEV / Diesel / Diesel-HEV / Plug-in hybrid
  (petrol, diesel) / Electric (BEV) / Fuel cell / Gas / Other / No motor — all
  nested under Total as a hierarchy.

## Labels
- **units**: Number of new registrations | de: Anzahl Neuzulassungen | fr: Nombre de nouvelles immatriculations | it: Numero di nuove immatricolazioni
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
- **single-select**:
- **default**: fuel=_T
- **transform**: level
- **seasonal adjustment**: n/a (raw registrations; strong monthly seasonality is
  intentionally left in — use the YoY % toggle to read the trend)

## Caveats / simplifications
- Passenger cars only (vehicle group `100`); the cube also covers other vehicle
  groups (goods, agricultural, motorcycles, …) — out of scope for the EV read.
- New (`N`) registrations only; used-import registrations are excluded.

## Provenance
Script: `R/source_fso_sdmx.R::fso_sdmx_new_vehicles` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; SDMX slice verified live 2026-06-02 (2005-01 .. 2026-04).

## What is special (de)
Monatliche Neuzulassungen von Personenwagen in der Schweiz nach Treibstoff: Benzin, Diesel, Hybrid, Plug-in und Elektro. E-Autos lagen im Frühling 2026 bei rund 25%.

## What is special (fr)
Nouvelles immatriculations mensuelles de voitures en Suisse par carburant : essence, diesel, hybride, hybride rechargeable et électrique. Les électriques étaient à environ 25% au printemps 2026.

## What is special (it)
Nuove immatricolazioni mensili di automobili in Svizzera per carburante: benzina, diesel, ibrido, ibrido plug-in ed elettrico. Le elettriche erano circa il 25% nella primavera 2026.
