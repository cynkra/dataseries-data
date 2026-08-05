# Foreign trade by partner country

- **id**: ch_fso_trade_partner
- **title**: Foreign trade by partner country | de: Aussenhandel nach Partnerland | fr: Commerce extérieur par pays partenaire | it: Commercio estero per paese partner
- **concept**: External sector / Foreign trade
- **canonical**: yes
- **source**: fso-focbs
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 1990 .. 2025
- **series**: 66
- **updated**: 2026-06-02

## What is special
Swiss exports and imports by country in CHF millions: Germany, the US, China and the rest, plus continent and economic-area totals.

## Access
- **type**: fso-dam-excel — FSO DAM Excel asset (two single-sheet workbooks, pinned by asset id)
- **asset ids**: `36664830 36664836` (exports, imports — the English masters)
- **call**: `fso_excel_ch_fso_trade_partner()` — the fetcher downloads both masters
  itself via `download_binary("https://dam-api.bfs.admin.ch/hub/api/dam/assets/{id}/master", …)`.
  We pin the asset ids (not an order number) because the order number resolves to
  the German master; pinning the id gives the English labels directly.

## Parsing recipe
- Each workbook is a single sheet (`T6.5.4_E` exports, `T 6.5.3_E` imports) with a
  year-header row (1990 … 2025 across the columns) and one data row per partner.
- **The two workbooks have different column layouts** — exports put country names in
  column 2 and the continent/Total aggregates in column 1; imports put every label
  flat in column 1. So the parser does **not** infer country-vs-group from which
  column a label sits in. It:
  1. anchors the year-header row by content — the first row with >5 cells matching
     `^(19|20)\d{2}$` — and takes those as the value columns (revision-proof, no
     hardcoded row/column numbers);
  2. reads data rows below until column 1 opens the footnote/Source band
     (`^(Source|Status|Enquiries|Information|©)`);
  3. takes the label as column 2 if non-empty, else column 1;
  4. strips trailing footnote markers — both plain digits (`Total 1 2 4` → `Total`)
     and Unicode superscripts (`Belgium ³` → `Belgium`);
  5. classifies `level` = `group` if the cleaned label is one of the fixed
     continent / economic-area names (Total, Europe, EU, Asia, North America,
     Central and South America, Africa, Oceania), else `country`;
  6. parses each year cell as a number (European thousands `'` stripped, `,`→`.`),
     dropping `....` / blank → NA. Footnote-definition rows (a bare marker in col1
     and prose in col2) carry no numeric year cells and are skipped.
- European number formatting and trailing footnote markers are stripped. The 2013
  methodology break is **not** chained (see Caveats).

## Dimensions
- `flow`: the trade direction — Exports / Imports.
- `partner`: the partner country or region (40 levels: ~32 individual countries plus
  the continent / economic-area aggregates and the grand Total). Labels are the
  workbook's English names.
- `level`: whether a `partner` is an individual `country` or a `group` (continent /
  economic area). Functionally determined by `partner`; surfaced as its own
  single-select so a user can hold the chart to either just the countries or just the
  aggregates. (It is not dropped as degenerate because it carries two genuine values.)

## Labels
- **units**: CHF millions | de: Mio. CHF | fr: Millions de CHF | it: Milioni di CHF
- dim: flow
  - **label**: Trade flow | de: Handelsrichtung | fr: Flux commercial | it: Flusso commerciale
  - export: Exports | de: Exporte | fr: Exportations | it: Esportazioni
  - import: Imports | de: Importe | fr: Importations | it: Importazioni
- dim: partner
  - **label**: Partner country / region | de: Partnerland / Region | fr: Pays partenaire / région | it: Paese partner / regione
- dim: level
  - **label**: Aggregation level | de: Aggregationsstufe | fr: Niveau d'agrégation | it: Livello di aggregazione
  - group: Continent / economic area | de: Kontinent / Wirtschaftsraum | fr: Continent / espace économique | it: Continente / area economica
  - country: Individual country | de: Einzelnes Land | fr: Pays individuel | it: Singolo paese

## Display
- **split**: partner
- **single-select**: level
- **default**: flow=export, partner=Total, level=group
- **transform**: level
- **seasonal adjustment**: n/a (annual series, no SA dimension)

## Hierarchy
`Total` is the root; the continent aggregates (already present as series) head each
branch, with the reported partner countries nested beneath and the `EU` aggregate under
Europe. Transcontinental partners follow the Swiss trade-statistics convention (Russia
and Türkiye under Europe).
- Total
  - Europe
    - EU
    - Germany
    - France
    - Italy
    - Austria
    - Belgium
    - Netherlands
    - Spain
    - Poland
    - United Kingdom
    - Ireland
    - Sweden
    - Czech Republic
    - Russia
    - Türkiye
  - Asia
    - China
    - Japan
    - India
    - Hong Kong
    - Korea (South)
    - Taiwan
    - Singapore
    - Thailand
    - Saudi Arabia
    - United Arab Emirates
    - Uzbekistan
  - North America
    - USA
    - Canada
    - Mexico
  - Central and South America
    - Brazil
    - Peru
  - Africa
    - South Africa
  - Oceania
    - Australia

## Caveats / simplifications
- **BAZG commercial-use permission**: the underlying customs data is produced by the
  Federal Office for Customs and Border Security (FOCBS / BAZG). FSO disseminates it
  under the standard FSO free-reuse-with-attribution terms, but **commercial reuse of
  the customs trade statistics requires permission from BAZG**. Treat as `fso` license
  for the catalog but flag this restriction to commercial users.
- **2013 methodology break**: a customs-statistics methodology change in 2013 (and
  smaller country-coverage changes in 2002 / 2012, noted in the workbook footnotes)
  means the series is **not chained / not made continuous** across the break. Pre- and
  post-2013 levels are not strictly comparable.
- Partner set limited to the countries / regions the workbook breaks out; the residual
  (Total minus the listed partners) is not published as its own row.
- Spot-checks match the workbook exactly: export Total 2024 = 393 833.5,
  export Germany 2024 = 45 218.3, export USA 2024 = 65 297.2,
  import Germany 2024 = 59 891.6 (all CHF mn).

## Provenance
Script: `R/source_fso_excel_sets.R::fso_excel_ch_fso_trade_partner` (+ `.trade_partner_sheet`,
`.TRADE_GROUPS`). Datasheet 2026-06-02; parser verified live 2026-06-02
(2367 rows, 66 series, 40 partners, 1990 .. 2025, 0 NA values; four value anchors pass).
