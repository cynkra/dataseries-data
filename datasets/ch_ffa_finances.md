# Public finances: general government main aggregates

- **id**: ch_ffa_finances
- **title**: Government finances
- **concept**: National accounts / Government finance
- **canonical**: yes

- **source**: Federal Finance Administration (FFA / Eidg. Finanzverwaltung EFV)
- **license**: opendata.swiss terms of use (open use, attribution required)
- **frequency**: annual
- **coverage**: 1990 .. 2029 (latest financial statement plus budget / financial-plan / forecast years)
- **series**: see provenance
- **updated**: 2025-03 (CKAN `modified`)

## What is special
The headline read on Swiss **public finances** — the one genuine concept gap in the
catalog. The Federal Finance Administration consolidates the whole of general
government (Confederation, the 26 cantons, the communes, and the social-security
funds) into a single coherent set of fiscal aggregates, published on opendata.swiss
as *"Main aggregates and forecasts with FS- and GFS-Model"*. It is the only catalog
dataset sourced from the FFA, and the only one that carries both the Swiss
administrative **FS model** (financial statistics) and the internationally
comparable **GFS model** (Government Finance Statistics, the Maastricht / SNA basis)
side by side.

It delivers the textbook public-finance headline set — receipts, expenditure, the
budget balance, gross and net debt, and the GDP ratios (tax-to-GDP / fiscal ratio,
expenditure ratio, gross-debt ratio incl. the Maastricht debt ratio) — broken down
by **government level**, so the user can see e.g. the Confederation's deficit against
the cantons' surplus, or the general-government Maastricht debt ratio over three
decades. It also extends past the latest closed financial statement into the FFA's
official budget / financial-plan and forecast years (flagged in the `estimate`
dimension), which is unusual for the catalog: most series stop at the last actual.

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
- @grp_fs: Financing view (receipts, expenditure, balance)
  - einnahmen
  - ausgaben
  - saldo
  - einnahmen_ord
  - ausgaben_ord
  - saldo_ord
- @grp_gfs: Accrual view (revenue, expenses, balance)
  - ertrag
  - aufwand
  - fiskalertrag
  - defizit_ueberschuss
  - nettozugang_sachvermoegen
- @grp_bs: Balance sheet
  - aktiven
  - fremdkapital
  - eigenkapital
- @grp_debt: Debt
  - bruttoschuld_fs
  - nettoschulden_fs
  - maastricht_schuld
  - nettoschuld
- @grp_ratio: Ratios (% of GDP)
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
