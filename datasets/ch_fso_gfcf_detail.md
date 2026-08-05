# Gross fixed capital formation by institutional sector and asset type

- **id**: ch_fso_gfcf_detail
- **title**: Investment (GFCF) detail | de: Investitionen (Bruttoanlageinvestitionen) im Detail | fr: Investissements (FBCF) en détail | it: Investimenti (IFL) in dettaglio
- **concept**: National accounts / Investment (gross fixed capital formation)
- **canonical**: no (headline total-economy GFCF is in `ch_seco_gdp` as part of the GDP expenditure breakdown; this is the institutional-sector × asset-type detail)
- **source**: fso
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 1995 .. 2024
- **series**: 37

## What is special
Investment (gross fixed capital formation) by institutional sector and asset type:
who invests, and in what. Construction is split into building and civil
engineering, and equipment and software are separated out. The national accounts
(`ch_seco_gdp`) carry only the single economy-wide total.

## Access
- **type**: fso-dam-csv — FSO DAM asset, master is a long CSV (not xlsx)
- **order number**: `ts-x-04.02.05.02` (asset 36182144)
- **codelist appendix** (level labels, ODS): `https://dam-api.bfs.admin.ch/hub/api/dam/assets/36182144/appendix` — EN labels are transcribed into the parser (file labels are FR/DE/IT only).
- **call**: `fso_gfcf_detail("ch_fso_gfcf_detail")`

## Parsing recipe
- `fso_dam_csv_download("ts-x-04.02.05.02")` resolves + downloads the CSV master;
  read with `fileEncoding = "UTF-8-BOM"` (the file carries a BOM).
- Columns `SECTOR, PERIOD, CLASSIFICATION, UNIT_MEAS, VALUE, STATUS`.
- **Filter `UNIT_MEAS == "MCHF"`** (CHF-million levels). The file also carries `AC`
  (% change at current prices) and `ACPP` (% change at previous-year prices) leaves
  on the *same* `(SECTOR, CLASSIFICATION, PERIOD)` key — keeping them triple-counts
  every observation and breaks (dims, date) uniqueness. The app reproduces %-change
  from the level via its transform toggle.
- Dims: `sector` ← `SECTOR`, `asset` ← `CLASSIFICATION`. `PERIOD` (year) →
  first-of-year ISO date. Drop NA values.

## Dimensions
- `sector`: `S1` total economy (the default), `S11` non-financial corporations,
  `S12` financial corporations, `S121T127` financial institutions (excl. S128/S129),
  `S12Q` insurance & pension funds, `S13` general government, `S1314` social-security
  funds, `S14` households, `S15` NPISH. Every sector carries the full asset
  breakdown (construction / building / civil engineering / equipment).
- `asset`: `P51G` gross fixed capital formation total, `P5111_N111_112G` construction,
  `P5111_N113T117G` equipment / fixed assets & software, with construction split into
  `6011` building construction and `6010` civil engineering. Hierarchy:
  P51G → {Construction → (Building, Civil engineering), Equipment}.
  `P51G` (the grand total) is present only for `S1` in the source; the breakdown
  assets (construction, building, civil engineering, equipment) exist for all 9 sectors.

## Labels
- **units**: CHF million, current prices | de: Mio. CHF, zu laufenden Preisen | fr: Millions de CHF, aux prix courants | it: Milioni di CHF, a prezzi correnti
- dim: sector
  - **label**: Institutional sector | de: Institutioneller Sektor | fr: Secteur institutionnel | it: Settore istituzionale
  - S1: Total economy | de: Gesamtwirtschaft | fr: Économie totale | it: Economia totale
  - S11: Non-financial corporations | de: Nichtfinanzielle Kapitalgesellschaften | fr: Sociétés non financières | it: Società non finanziarie
  - S12: Financial corporations | de: Finanzielle Kapitalgesellschaften | fr: Sociétés financières | it: Società finanziarie
  - S121T127: Financial institutions (other than S128 S129) | de: Finanzinstitute (ohne S128, S129) | fr: Institutions financières (hors S128, S129) | it: Istituzioni finanziarie (esclusi S128, S129)
  - S12Q: Insurance corporations and pension funds | de: Versicherungen und Pensionskassen | fr: Sociétés d'assurance et caisses de pension | it: Imprese di assicurazione e casse pensioni
  - S13: General government | de: Staat | fr: Administrations publiques | it: Amministrazioni pubbliche
  - S1314: Social security funds | de: Sozialversicherungen | fr: Assurances sociales | it: Assicurazioni sociali
  - S14: Households | de: Private Haushalte | fr: Ménages | it: Famiglie
  - S15: Non-profit institutions serving households | de: Private Organisationen ohne Erwerbszweck | fr: Institutions sans but lucratif au service des ménages | it: Istituzioni senza scopo di lucro al servizio delle famiglie
- dim: asset
  - **label**: Asset type | de: Anlagekategorie | fr: Type d'actif | it: Tipo di attivo
  - P51G: Gross fixed capital formation (total) | de: Bruttoanlageinvestitionen (Total) | fr: Formation brute de capital fixe (total) | it: Investimenti fissi lordi (totale)
  - P5111_N111_112G: Construction | de: Bau | fr: Construction | it: Costruzioni
  - 6011: Building construction | de: Hochbau | fr: Bâtiment | it: Edilizia
  - 6010: Civil engineering | de: Tiefbau | fr: Génie civil | it: Genio civile
  - P5111_N113T117G: Equipment, fixed assets and software | de: Ausrüstungen, Anlagen und Software | fr: Équipements, actifs fixes et logiciels | it: Attrezzature, impianti e software

## Display
- **split**: sector
- **single-select**:
- **default**: sector=S1, asset=P5111_N111_112G
- **transform**: level
- **seasonal adjustment**: n/a (annual)

The split is the **sector** (9 institutional-sector lines), driven by a single-select
**asset** picker. This is the clean rectangle: every sector carries the construction /
building / civil-engineering / equipment breakdown, so selecting any of those four
assets draws all 9 sector lines fully populated — no dead cells. The default opens on
the construction breakdown (`P5111_N111_112G`), populated for all 9 sectors. The only
ragged level is the grand total `P51G`, which the source publishes for the total
economy `S1` only; selecting it draws the single S1 headline line (correct for a
total-economy aggregate), and it is flagged data-bearing via S1. The earlier
split=asset / single-select=sector layout was ragged: picking any of the 8 sub-sectors
together with `P51G` produced an empty (dead) chart, since sub-sectors have no grand
total. Swapping the roles removes those 8 dead cells.

## Hierarchy
The SNA institutional sectors nest by their S-codes: `S1` total economy splits into
non-financial / financial corporations, government, households and NPISH, with the
financial and government sub-sectors one level deeper.
- S1
  - S11
  - S12
    - S121T127
    - S12Q
  - S13
    - S1314
  - S14
  - S15

## Caveats / simplifications
- **Current prices, levels only.** The source's %-change variants (`AC`, `ACPP`) are
  dropped; the app reconstructs %-change via its transform toggle, but real (volume)
  levels are not provided here.
- The grand total `P51G` exists only for the total economy `S1`; the per-sector rows
  carry the asset breakdowns (construction / building / civil engineering / equipment)
  but not a sector `P51G` total. With split=sector / single-select=asset this is not a
  dead cell: selecting `P51G` simply draws the single S1 line, the headline total.
- Asset codes mix two coding schemes (ESA `P51*` plus FSO `601x` construction
  sub-codes); EN labels are authored from the codelist appendix.

## Provenance
Script: `R/source_fso_dam_csv.R::fso_gfcf_detail` (wired in `R/pipeline.R`).
Datasheet authored 2026-06-02; verified live 2026-06-03 (S1 P51G 2024 = 225,873.1 and S1 construction 2023 = 66,634.8, exact matches to FSO).
