# Public finances: general government main aggregates

- **id**: ch_ffa_finances
- **title**: Government finances | de: Öffentliche Finanzen | fr: Finances publiques | it: Finanze pubbliche
- **concept**: National accounts / Government finance
- **canonical**: yes

- **source**: ffa
- **license**: opendata-swiss (open use, attribution required)
- **frequency**: annual
- **coverage**: 1990 .. 2029 (latest financial statement plus budget / financial-plan / forecast years)
- **series**: see provenance
- **updated**: 2025-03 (CKAN `modified`)

## What is special
Receipts, spending, deficit and debt for the Swiss Confederation, cantons, communes and social security, on both the national and Maastricht basis.

## Access
- **type**: scraped — opendata.swiss (CKAN) → data.finance.admin.ch CSV asset
- **url**: `https://opendata.swiss/en/dataset/hauptaggregate-und-prognosen-im-fs-und-gfs-modell`
- **endpoint / order number**: CKAN package `hauptaggregate-und-prognosen-im-fs-und-gfs-modell`
  - dataset page: `https://opendata.swiss/en/dataset/hauptaggregate-und-prognosen-im-fs-und-gfs-modell`
  - CKAN show: `https://opendata.swiss/api/3/action/package_show?id=hauptaggregate-und-prognosen-im-fs-und-gfs-modell` (302 → `ckan.opendata.swiss`)
  - data CSV: `https://www.data.finance.admin.ch/static/assets/datasets/fs_dashboard/main_extern.csv`
- **call**: `ffa_fetch("ch_ffa_finances", title = list(en = "Public finances: general government main aggregates"))`

## Parsing recipe
The CSV is already long: columns `hh, model, variable, jahr, value, source` (plus a
leading row-number column, dropped). One row per (government level × accounting
model × indicator × year), with a `source` flag marking actual vs. provisional /
budget / forecast.
- **dimension columns** ← `hh` (→ `level`), `model`, `variable` (→ `indicator`),
  `source` (→ `estimate`). **time** ← `jahr` (a 4-digit year → ISO first-of-year
  via `to_iso()`, R/dates.R). **value** ← `value` (numeric).
- Keep only the **curated headline indicators** (see Dimensions); drop the deep
  debt-decomposition codes (`debt_*`, `FBE_*`, `FS_SR*`, `GFS_*`, …).
- The GDP reference row (`variable == "bip"`) carries `hh = NA` / `model = NA` in the
  source; it is reassigned to `level = staat`, `model = gfs` so it sits in the tree
  as a real series rather than an orphan NA branch.
- NA values dropped; rows whose `level` or `model` is not in the published label
  maps are dropped.
- The WAF in front of `data.finance.admin.ch` rejects bare programmatic requests, so
  the fetch sends browser-like headers (User-Agent + Accept + Referer). The live CSV
  URL is resolved from CKAN first, with the static URL above as a fallback.

## Dimensions
- `level` (`hh`) — government level: `staat` General government, `bund` Confederation,
  `ktn` Cantons, `gdn` Communes, `sv` Social security funds, `bund_ktn_gdn`
  Confederation + cantons + communes (the aggregate excluding social security).
- `model` — accounting framework: `fs` FS model (Swiss financial statistics /
  administrative basis), `gfs` GFS model (Government Finance Statistics,
  Maastricht / SNA basis, internationally comparable).
- `indicator` (`variable`) — the headline aggregate. Levels in CHF million:
  `einnahmen` Receipts, `ausgaben` Expenditure, `saldo` Balance, `*_ord` the ordinary
  (non-extraordinary) variants, `ertrag` Revenue / `aufwand` Expenses (GFS accrual),
  `fiskalertrag` Fiscal revenue (taxes), `bruttoschuld_fs` / `maastricht_schuld`
  Gross debt, `nettoschulden_fs` / `nettoschuld` Net debt, `defizit_ueberschuss`
  Deficit/surplus, `aktiven` / `fremdkapital` / `eigenkapital` balance-sheet items,
  `bip` GDP. GDP **ratios** (share of GDP, 0–1 scale): `fiskalquote` Fiscal/tax ratio,
  `einnahmenquote` Receipts ratio, `staatsquote` Expenditure ratio,
  `bruttoschuldenquote` Gross-debt ratio (Maastricht), `schuldenquote` Debt ratio,
  `nettoschuldenquote` Net-debt ratio.
- `estimate` (`source`) — whether the year is a closed financial statement (actual),
  provisional financial statement, survey financial statement / budget, budget /
  financial plan, or a forecast. Lets the app separate realized from projected years.

## Labels
- **units**: CHF million (levels) / share of GDP, 0-1 (ratios) | de: Mio. CHF (Niveaus) / Anteil am BIP, 0-1 (Quoten) | fr: Millions de CHF (niveaux) / part du PIB, 0-1 (quotes-parts) | it: Milioni di CHF (livelli) / quota del PIL, 0-1 (quote)
- dim: level
  - **label**: Government level | de: Staatsebene | fr: Niveau de l'État | it: Livello statale
  - staat: General government | de: Staat | fr: Administrations publiques | it: Amministrazioni pubbliche
  - bund: Confederation | de: Bund | fr: Confédération | it: Confederazione
  - ktn: Cantons | de: Kantone | fr: Cantons | it: Cantoni
  - gdn: Communes | de: Gemeinden | fr: Communes | it: Comuni
  - sv: Social security funds | de: Sozialversicherungen | fr: Assurances sociales | it: Assicurazioni sociali
  - bund_ktn_gdn: Confederation, cantons and communes | de: Bund, Kantone und Gemeinden | fr: Confédération, cantons et communes | it: Confederazione, cantoni e comuni
- dim: model
  - **label**: Accounting model | de: Rechnungsmodell | fr: Modèle comptable | it: Modello contabile
  - fs: FS model (financial statistics) | de: FS-Modell (Finanzstatistik) | fr: Modèle SF (statistique financière) | it: Modello SF (statistica finanziaria)
  - gfs: GFS model (Maastricht / SNA basis) | de: GFS-Modell (Maastricht / VGR-Basis) | fr: Modèle SFP (base Maastricht / SCN) | it: Modello SFP (base Maastricht / SCN)
- dim: indicator
  - **label**: Indicator | de: Indikator | fr: Indicateur | it: Indicatore
  - einnahmen: Receipts | de: Einnahmen | fr: Recettes | it: Entrate
  - ausgaben: Expenditure | de: Ausgaben | fr: Dépenses | it: Uscite
  - saldo: Balance | de: Saldo | fr: Solde | it: Saldo
  - einnahmen_ord: Ordinary receipts | de: Ordentliche Einnahmen | fr: Recettes ordinaires | it: Entrate ordinarie
  - ausgaben_ord: Ordinary expenditure | de: Ordentliche Ausgaben | fr: Dépenses ordinaires | it: Uscite ordinarie
  - saldo_ord: Ordinary balance | de: Ordentlicher Saldo | fr: Solde ordinaire | it: Saldo ordinario
  - ertrag: Revenue | de: Ertrag | fr: Revenus | it: Ricavi
  - aufwand: Expenses | de: Aufwand | fr: Charges | it: Oneri
  - fiskalertrag: Fiscal revenue (taxes) | de: Fiskalertrag (Steuern) | fr: Recettes fiscales (impôts) | it: Gettito fiscale (imposte)
  - bruttoschuld_fs: Gross debt | de: Bruttoschulden | fr: Dette brute | it: Debito lordo
  - nettoschulden_fs: Net debt | de: Nettoschulden | fr: Dette nette | it: Debito netto
  - maastricht_schuld: Gross debt (Maastricht) | de: Bruttoschulden (Maastricht) | fr: Dette brute (Maastricht) | it: Debito lordo (Maastricht)
  - nettoschuld: Net debt | de: Nettoschulden | fr: Dette nette | it: Debito netto
  - defizit_ueberschuss: Deficit / surplus | de: Defizit / Überschuss | fr: Déficit / excédent | it: Disavanzo / avanzo
  - nettozugang_sachvermoegen: Net acquisition of non-financial assets | de: Nettozugang an Sachvermögen | fr: Acquisition nette d'actifs non financiers | it: Acquisizione netta di attività non finanziarie
  - aktiven: Assets | de: Aktiven | fr: Actifs | it: Attivi
  - fremdkapital: Liabilities | de: Fremdkapital | fr: Capitaux de tiers | it: Capitale di terzi
  - eigenkapital: Equity / net worth | de: Eigenkapital | fr: Fonds propres | it: Capitale proprio
  - bip: Gross domestic product | de: Bruttoinlandprodukt | fr: Produit intérieur brut | it: Prodotto interno lordo
  - fiskalquote: Fiscal ratio (tax-to-GDP) | de: Fiskalquote | fr: Quote-part fiscale | it: Quota fiscale
  - einnahmenquote: Receipts-to-GDP ratio | de: Einnahmenquote | fr: Quote-part des recettes | it: Quota delle entrate
  - staatsquote: Expenditure-to-GDP ratio | de: Staatsquote | fr: Quote-part de l'État | it: Quota statale
  - bruttoschuldenquote: Gross-debt-to-GDP ratio (Maastricht) | de: Bruttoschuldenquote (Maastricht) | fr: Taux d'endettement brut (Maastricht) | it: Tasso d'indebitamento lordo (Maastricht)
  - schuldenquote: Debt-to-GDP ratio | de: Schuldenquote | fr: Taux d'endettement | it: Tasso d'indebitamento
  - nettoschuldenquote: Net-debt-to-GDP ratio | de: Nettoschuldenquote | fr: Taux d'endettement net | it: Tasso d'indebitamento netto
  - grp_fs: Financing view (receipts, expenditure, balance) | de: Finanzierungssicht (Einnahmen, Ausgaben, Saldo) | fr: Optique du financement (recettes, dépenses, solde) | it: Ottica del finanziamento (entrate, uscite, saldo)
  - grp_gfs: Accrual view (revenue, expenses, balance) | de: Erfolgssicht (Ertrag, Aufwand, Saldo) | fr: Optique des résultats (revenus, charges, solde) | it: Ottica dei risultati (ricavi, oneri, saldo)
  - grp_bs: Balance sheet | de: Bilanz | fr: Bilan | it: Bilancio
  - grp_debt: Debt | de: Schulden | fr: Dette | it: Debito
  - grp_ratio: Ratios (% of GDP) | de: Quoten (% des BIP) | fr: Quotes-parts (% du PIB) | it: Quote (% del PIL)
- dim: estimate
  - **label**: Estimate type | de: Erhebungsart | fr: Type d'estimation | it: Tipo di stima
  - `Financial statements`: Financial statements (actual) | de: Rechnung (Ist) | fr: Comptes (effectif) | it: Conti (effettivo)
  - `Provisional financial statements`: Provisional financial statements | de: Provisorische Rechnung | fr: Comptes provisoires | it: Conti provvisori
  - `Survey financial statements`: Survey financial statements | de: Erhebung Rechnung | fr: Enquête comptes | it: Rilevazione conti
  - `Survey budget`: Survey budget | de: Erhebung Budget | fr: Enquête budget | it: Rilevazione preventivo
  - `Budget/financial plans`: Budget / financial plans | de: Budget / Finanzpläne | fr: Budget / plans financiers | it: Preventivo / piani finanziari
  - Forecasts: Forecasts | de: Prognosen | fr: Prévisions | it: Previsioni
  - `Data available`: Data available | de: Daten verfügbar | fr: Données disponibles | it: Dati disponibili

## Display
- **split**: indicator
- **single-select**: level, model, estimate
- **default**: level=staat, model=gfs, indicator=bruttoschuldenquote
- **transform**: level
- **percent-levels**: fiskalquote, einnahmenquote, staatsquote, bruttoschuldenquote, schuldenquote, nettoschuldenquote
  <these indicator levels are a share of GDP on a 0–1 scale; the app renders them
  as a percentage (× 100, % axis) when they alone are plotted in the level view>
- **seasonal adjustment**: n/a (annual data).

## Hierarchy
The indicators have no single total; they are grouped by accounting view — the FS
financing view (receipts / expenditure / balance), the GFS accrual view (revenue /
expenses / balance), the balance sheet, the debt measures and the GDP-ratio block —
with GDP itself on its own.
- @grp_fs
  - einnahmen
  - ausgaben
  - saldo
  - einnahmen_ord
  - ausgaben_ord
  - saldo_ord
- @grp_gfs
  - ertrag
  - aufwand
  - fiskalertrag
  - defizit_ueberschuss
  - nettozugang_sachvermoegen
- @grp_bs
  - aktiven
  - fremdkapital
  - eigenkapital
- @grp_debt
  - bruttoschuld_fs
  - nettoschulden_fs
  - maastricht_schuld
  - nettoschuld
- @grp_ratio
  - fiskalquote
  - einnahmenquote
  - staatsquote
  - bruttoschuldenquote
  - schuldenquote
  - nettoschuldenquote
- bip

## Caveats / simplifications
- **Units are mixed by indicator**: level aggregates are in CHF million; the `*quote`
  ratio indicators are a share of GDP on a 0–1 scale (e.g. 0.30 = 30 % of GDP). They
  are kept in one dataset because they share every other dimension; the app should
  format ratios as percentages.
- The same economic concept appears under both models with slightly different code
  names (FS `saldo` vs GFS `saldo`/`defizit_ueberschuss`; FS `bruttoschuld_fs` vs GFS
  `maastricht_schuld`). Both are kept; the `model` dimension disambiguates.
- Coverage by indicator is uneven: the FS model carries `einnahmen`/`bruttoschuld_fs`,
  the GFS model carries the ratios and the Maastricht debt; not every (level × model ×
  indicator) cell exists. `write_dataset()` flags which level codes actually occur.
- Forecast / budget years (post the latest financial statement, ~2024+) are official
  FFA projections, not observations — flagged in `estimate`, not dropped.
- Deep sub-aggregates (debt decomposition, special-financing positions, COFOG
  function split) are **dropped**; they live in the FFA's "Detailed data" datasets and
  could seed further datasets later.

## Provenance
Script: `R/source_ffa.R::ffa_fetch` (wired in `R/pipeline.R`). Datasheet authored
2026-06-01; parser verified 2026-06-01.
