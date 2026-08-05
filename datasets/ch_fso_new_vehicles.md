# New registrations of passenger cars by fuel

- **id**: ch_fso_new_vehicles
- **title**: New car registrations by fuel
- **concept**: Domestic economy / New vehicle registrations
- **canonical**: yes
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2005 .. 2026
- **series**: 12
- **updated**: monthly

## What is special
Monthly new registrations of **passenger cars** in Switzerland, split by **fuel
type** — the cleanest read on the **EV transition**: petrol/diesel (incl. their
HEV variants), plug-in hybrids, battery-electric (BEV), fuel cell, and gas. A
high-frequency consumption + technology-shift indicator. As of spring 2026, BEVs
are ~25% of new-car registrations.

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
- **units**: Number of new registrations
- dim: fuel
  - **label**: Fuel
  - _T: Total
  - PC: Petrol
  - PH: Petrol hybrid (HEV)
  - DC: Diesel
  - DH: Diesel hybrid (HEV)
  - HP: Plug-in hybrid (petrol)
  - HD: Plug-in hybrid (diesel)
  - EL: Electric (BEV)
  - FC: Fuel cell (hydrogen)
  - GA: Gas
  - _O: Other
  - NM: No motor

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
