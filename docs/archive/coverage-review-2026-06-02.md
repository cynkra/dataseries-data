> **SUPERSEDED (2026-06-03).** This is the point-in-time review that drove the
> 56 → 70 expansion; kept as an audit trail. The **live** "what's in / what's still
> open and why" status now lives in [`deferred-datasets.md`](../deferred-datasets.md)
> (registry) and [`concepts.md`](../concepts.md) (taxonomy). Headline outcome: catalog
> complete at 70 for the open Swiss macro universe; only PMI and SIX VSMI/constituents
> are genuinely closed (licensed), industrial orders has no open channel, and BAZG
> *monthly* trade is open-but-deferred-for-size. Read those two docs, not this one,
> for current state.

# dataseries.org — Comprehensive Coverage Review

*Mission: all Swiss economic data, especially the hard-to-get, in one place. Date: 2026-06-02. Method: 21-agent workflow — inventory (current catalog + the previous swissdata catalog + old alt.dataseries.ch site) → research the canonical Swiss macro universe (SNB/FSO/SECO/KOF + Datastream/OECD/Trading-Economics key-indicator lists) → synthesize a gap matrix → adversarially verify the top headline gaps → report.*

## 0. Update — gaps actioned (2026-06-02)

After this review the catalog was expanded from **56 → 70 datasets** (full pipeline build,
0 skips, every new series live-verified against source values). What landed:

- **National accounts:** regional GDP by canton/region (`ch_fso_gdp_region`), GFCF by
  institutional sector × asset (`ch_fso_gfcf_detail`), labour productivity (`ch_fso_labour_productivity`).
- **Prices:** EU-harmonised HICP via Eurostat (`ch_fso_hicp`), construction price index (`ch_fso_construction_prices`).
- **Labour:** employed persons / ETS (`ch_fso_ets`), hours worked / AVOL (`ch_fso_hours_worked`),
  employment-outlook index (`ch_fso_besta_outlook`), cross-border commuters (`ch_fso_cross_border_commuters`).
- **External sector:** foreign trade **by partner country** (`ch_fso_trade_partner`) — the
  flagship gap from §4(b).
- **Domestic economy:** services-sector turnover (`ch_fso_services`), completing the triad.
- **Business cycle:** KOF Economic Sentiment Index (`ch_kof_esi`) + the SECO **Weekly**
  Economic Activity index (`ch_seco_wwa`) — the catalog's first weekly series.
- **Demographics:** population by nationality × sex (`ch_fso_pop_detail`).
- **Bond yields curation fix:** `rendoblid` found discontinued → `ch_snb_rendeiduebd` promoted to canonical.

Still out (unchanged): **PMI** (closed), **industrial orders** (no open channel), VSMI/SIX
constituents (licensed). Construction-investment *levels* stay deferred — superseded by the
GFCF-detail Hochbau/Tiefbau series. New-channel notes (Eurostat, KOF `sets`, BAZG-monthly 502)
are in `source-quirks.md`.

## 1. Verdict

**dataseries.org covers ~85–90% of the open headline Swiss-macro indicator set** — revised up from the synthesis's 80–85% because adversarial verification refuted four of the eleven "headline/important" gaps as already-covered (GDP components, government debt-to-GDP, federal budget balance, industrial production index). The real remaining open headline gap is narrow: **foreign trade by partner country**. The daily **10Y Confederation yield** is *not* a gap after all — `concepts.md` named `rendoblid` canonical, but live testing (2026-06-02) showed the SNB **discontinued** `rendoblid` (frozen 2025-07-31); the live series is `ch_snb_rendeiduebd` (already shipped), whose `CHF × 10J` cell is the 10Y benchmark — so it was promoted to canonical and `rendoblid` left out. **FX reserves** and an **explicit SARON tile** are likewise *not* missing data — both are already in the catalog (reserves as the default view of the SNB balance-sheet cube `ch_snb_snbbipo`; SARON as a dimension of the money-market cube `ch_snb_zimoma`) and only need surfacing as named tiles. With trade-by-partner plus the deferred secondary items, ~95% of the open set is realistically reachable.

It is the best concept-organized open Swiss macro catalog available, and genuinely strong as an "all Swiss economic data in one place" product.

**Shape of the catalog (56 datasets):**

| | Domains |
|---|---|
| **Deep** | External sector (9: BoP 4, IIP 4, trade 1) — the deepest, matches/exceeds canonical BoP/IIP. Money & banking (7). Labour (8 across leaves). Interest rates & yields (5). Payment systems (5 zave* cubes — exceeds any aggregator). Prices (5). |
| **Moderate** | Exchange rates (3). Business cycle & sentiment (3). Financial markets (2). Domestic economy (2). |
| **Thin (single-leaf)** | National accounts (GDP only — but that one dataset is richly dimensioned, see §3). Tourism, Population, Public finances, Mobility, Construction & housing, SNB policy/forecasts. |

The catalog is **SNB-heavy by construction**: 38 SNB datasets (incl. SECO/SECO-origin re-publications routed through SNB cubes), 13 FSO, 2 SECO, 1 KOF, 1 FFA/EFV, 1 UZH. This is appropriate — SNB's open cube API is the richest single open channel for Switzerland — but it means the FSO/SECO real-economy long tail (national-accounts detail, construction investment, employed-persons) is where the genuine thinness sits.

## 2. What we cover well

| Domain | Depth | Source mix | Notes |
|---|---|---|---|
| **External sector** | Deepest | SNB ×9 | Full BoP (current, financial, overview, services) + complete IIP tree (overview, by-currency, external-debt, by-sector) + trade by goods category. Matches/exceeds canonical BoP/IIP. |
| **Money & banking** | Essentially complete | SNB ×7 | M1–M3, monetary base, SNB balance sheet (snbbipo), four-way bank/credit breakdown. Every SNB banken/aggregates headline. |
| **Interest rates & yields** | Strong on headlines | SNB ×5 | Policy rate (snboffzisa), money-market cube (zimoma, carries SARON), two deeper rate cubes, daily bond yields (spot curve). |
| **Exchange rates** | Complete for open universe | SNB ×3 | Bilateral nominal (devkum + companion) + effective NEER/REER (devwkieffid, daily). |
| **Prices** | Well covered | SNB ×4, FSO ×1 | CPI two ways (SNB headline to 1921 + FSO 443-position COICOP), core inflation, producer/import prices, real-estate price index. |
| **Business cycle & sentiment** | Open must-haves covered | KOF, SECO, SNB | KOF Barometer, SECO consumer confidence, SNB business-cycle signals. PMI is the only genuinely closed miss. |
| **Payment systems** | Unusually deep | SNB ×5 | SIC, e-money, cards/ATM stock + flow, credit-transfer/direct-debit. Exceeds any aggregator. |
| **Labour** | Good breadth | FSO ×5, SNB ×1, SECO ×1, UZH ×1 | Jobs (besta + sex breakdown), unemployment two definitions (registered SECO + ILO/SAKE), vacancies, wage index, plus first non-government provider (UZH Stellenmarkt-Monitor). |
| **National accounts** | Thin count, deep content | SECO ×1 | One dataset (ch_seco_gdp) but it carries all three accounting views — see §3. |
| **Public finances** | Adequate | FFA/EFV ×1 | Gross/net debt, Maastricht debt-to-GDP, federal balance — more than the synthesis credited. |

## 3. Comparison to the legacy swissdata universe + old website

The previous swissdata catalog (~105 series ids) and the old 23-dataset public site carried materially more national-accounts depth and customs trade. Verification shows most of those drops were **justified** (subsumed into richer single datasets, or deliberate roll-up dedup); a few are **real regressions**.

| Legacy id(s) | What it was | Status now | Verdict |
|---|---|---|---|
| ch.fso.na.gdp.use, ch.fso.na.gdp.iagni, ch.fso.gdp.pa, ch.snb.gdpap | GDP expenditure / income+GNI / production / nominal | **Subsumed** into ch_seco_gdp's 68-code `structure` tree (production + expenditure + income views, 660 series, quarterly 1980–2025) | **Justified** — one richly-dimensioned dataset replaces four; SECO publishes it in swissdata CSV+JSON natively (open-easy passthrough). The synthesis was wrong that this is "a single GDP series." |
| ch.snb.gdppn, ch.snb.gdpap, ch_fso_gdp_use | SNB/FSO GDP re-exports | Dropped (no datasheet) | **Justified** — redundant re-exports / lower-frequency variants; documented curation decision. |
| TRD (~358 customs/EZV series by partner) | Foreign trade by trading partner | **Not replaced**; ch_snb_ausshawarm covers balance + product, not partner country | **Real regression** (partner dimension only) — see gap matrix. |
| ch.fso.indpau | Monthly industry production/orders/turnover | Production + turnover index now in ch_fso_production (SDMX); **orders not replaced** | **Mostly justified** — production index is the default in the current dataset; only the orders slice is lost (and orders aren't on SDMX). |
| ch.fso.bapau, ch.fso.cah.inv | Construction activity / investment | Only ch_fso_vacant_dwellings present | **Real regression** — construction investment levels genuinely missing (legacy CNS ~41 series). |
| ch.fso.es.noga, ch.fso.es.rs, ch.fso.emp | Employed persons (ETS, Inlandkonzept) | Only besta (jobs) present | **Real regression** — ETS is a distinct concept from BESTA jobs; not on SDMX. |
| ch.fso.prdctvty(.idx1991), ch.fso.na.gfcf.is, ch.fso.copri.idx2010, ch.fso.ggs, ch.fso.popdet, ch.fso.besta.outlook | Productivity, GFCF detail, construction-price index, cross-border commuters, detailed population, employment-outlook | Not present | **Tolerable drops** — secondary; defer (see §5). |
| STK (~7298 SIX series), ch.six.vsmi | Constituent-level equities + VSMI | SMI/SPI **levels** present via ch_snb_capchstocki (incl. SPI total-return + SIX/ICB sector sub-indices); constituents + VSMI absent | **Justified** — index levels covered openly; constituents/VSMI are SIX-licensed (closed). |
| rendoblim (monthly), rendoblid (daily par yields) | Bond-yield cubes | Both dropped | **Justified.** rendoblim was a monthly roll-up; the SNB then **discontinued `rendoblid`** itself (frozen 2025-07-31, verified live 2026-06-02). The live daily spot cube `ch_snb_rendeiduebd` (shipped) is canonical — its `CHF × 10J` cell covers the 10Y Confederation benchmark. No regression. |

**Net:** the move to the 56-dataset curated catalog dropped three genuine concepts (trade-by-partner, construction investment, employed-persons) and a tail of secondary series. Everything else was either subsumed into a richer dataset, correctly dedup'd, or (in the case of `rendoblid`) discontinued at source.

## 4. Gap matrix

Verification corrections applied. **Four synthesis gaps were refuted as already covered** — listed in group (d) so they are not mistakenly actioned.

### (a) Headline items — one real add (done), two surfacing fixes

All three turned out **not** to be missing data once live-tested — one was a discontinued series we already cover, two just need a named tile (no new fetch).

| Concept | Domain | Importance | Have it? | Open? | Concrete channel | Status / recommendation |
|---|---|---|---|---|---|---|
| Daily 10Y Confederation yield | Rates & yields | headline | **Already covered** — live in `ch_snb_rendeiduebd` (`CHF × 10J`, current to 2026-05-29). `rendoblid` was found **discontinued** (frozen 2025-07-31) on live test 2026-06-02. | n/a | Promoted `ch_snb_rendeiduebd` to canonical for Bond yields; `rendoblid` not ingested (dead duplicate). | **Done (curation fix).** `concepts.md` + datasheet updated. |
| SNB foreign currency reserves | Money & banking | important | **Already present** — `ch_snb_snbbipo` carries foreign-currency investments (`D`, the default view), gold (`GFG`) and IMF reserve position (`RIWF`) | n/a (surfacing) | Expose the reserve lines of the existing `ch_snb_snbbipo` cube as a named concept | **Surface, don't fetch.** The earlier draft's separate `snbimfra` cube id is unverified and unnecessary. |
| Explicit SARON tile | Rates & yields | headline | **Already present** — `ch_snb_zimoma` carries the SARON dimension, just not surfaced as a named tile | n/a (surfacing) | Expose the SARON dimension of existing `ch_snb_zimoma` | **Surface, don't fetch.** Zero new data. |

### (b) Addable with effort — open but a new source script / multi-sheet stitch

| Concept | Domain | Importance | Have it? | Open? | Concrete channel | Recommendation |
|---|---|---|---|---|---|---|
| Foreign trade **by trading partner** | External sector | headline | No (ausshawarm covers balance + product, not partner) | open-effort | **BAZG/FOCBS Swiss-Impex open data** (free since 2025-12-18) on opendata.swiss ("Waren: Aussenhandel nach CPA6 / Land"; seasonally-adj by country) + I14Y; CSV, data from 1988. New source script, CPA6×country×flow cube. License: attribution; commercial use needs permission. | **Add with effort.** Highest-value real gap. Balance/product splits already exist, so scope is strictly the partner dimension. |
| Employed persons (ETS / Erwerbstätige, Inlandkonzept) | Labour | important | No (besta = jobs, a different concept) | open-effort | **FSO DAM Excel** order `ts-x-03.02.01.08` (quarterly by sector 1991Q2–2025Q2), via R/source_fso_excel.R. **Not** PX-Web (dead end from this env). Already in deferred-datasets.md. | **Add with effort** — same DAM Excel recipe as CPI/wages. |
| Construction investment (Bauinvestitionen) | Construction & housing | important | No (only vacancy) | open-effort (caveat) | **FSO DAM Excel** order `je-d-09.04.01.27` (asset 35965030), multi-sheet stitch. **Not** PX-Web BAPAU (that's the construction *price* index). | **Add with effort, with honest caveat:** absolute levels only run ~2005–2019; 2020+ sheets give provisional YoY % only, so a current level series requires chaining growth onto a frozen 2019 level. Decide if that's acceptable before building. |

### (c) Genuinely closed — cannot add

| Concept | Domain | Importance | Why closed | Recommendation |
|---|---|---|---|---|
| Manufacturing & Services PMI (procure.ch / UBS) | Business cycle | headline | Private survey; headline only in free monthly PDF; full back-series only on licensed terminals (Bloomberg/Refinitiv/Trading Economics). No open CSV/API/SDMX, nothing on opendata.swiss. Already in deferred-datasets.md. | **Declare out of scope.** Don't scrape fragile PDFs or license a feed. The one unavoidable headline miss. |
| Industrial **orders** (Auftragseingang) slice | Domestic economy | secondary | Not on FSO SDMX; PX-Web px-x-0603010000_101 is a documented dead end from this env; no verified open DAM/SECO/KOF channel. Already deferred. | **Out of scope (from this env).** Production + turnover index are already shipped in ch_fso_production. |
| VSMI volatility + SIX constituent/total-return families | Financial markets | important | SIX-licensed. SMI/SPI *levels* (incl. SPI total-return + sector sub-indices) already covered via ch_snb_capchstocki. | **Out of scope.** Open levels are done; the rest is closed. |

### (d) False alarms — refuted by verification, already covered (do NOT action)

| Synthesis-claimed gap | Reality | Where it lives |
|---|---|---|
| Quarterly GDP expenditure/production/income components, GFCF, GNI | **Already covered.** ch_seco_gdp has a 68-code `structure` tree spanning all three accounting views (production by NOGA, expenditure incl. cons_priv/cons_gov/inv_gfcf/exp/imp, income incl. compensation/operating-surplus/GNI/disposable income). 660 series, quarterly 1980–2025, open-easy swissdata CSV+JSON. | datasets/ch_seco_gdp.md |
| Government debt-to-GDP / general-government debt (Maastricht + net/gross) | **Already covered.** ch_ffa_finances carries gross/net debt + ratios under both FS and GFS/Maastricht models; **default landing view is the Maastricht debt-to-GDP ratio.** Synthesis's "annual receipts/expenditure only" is factually wrong. | datasets/ch_ffa_finances.md, R/source_ffa.R |
| Federal budget balance / debt brake | **Mostly covered.** ch_ffa_finances carries the federal (bund) balance: saldo, *_ord, deficit/surplus. Only the debt-brake *structural* (cyclically-adjusted) balance is incremental — a sub-facet of an already-covered concept, available open-easy from sibling EFV product `federal-finances-overall-budget` if wanted. | datasets/ch_ffa_finances.md |
| Industrial production index (INDPAU) | **Already covered.** ch_fso_production carries the real production volume index (INDICATOR_KE=PTOT) **and defaults to it** ("the headline read for industry"), plus turnover. Synthesis's "turnover only" is wrong. Only the orders slice is genuinely missing → group (c). | datasets/ch_fso_production.md |

## 5. Recommendations

### Do now (open-easy, channels already wired)
1. **Bond yields canonical — DONE (2026-06-02).** Live test showed `rendoblid` is discontinued (frozen 2025-07-31), so `ch_snb_rendeiduebd` (live to 2026-05-29, `CHF × 10J` = 10Y benchmark) was promoted to canonical; `rendoblid` not ingested. `concepts.md` + datasheet updated. No new fetch.
2. **SARON — surfacing only.** Expose the existing SARON dimension of `ch_snb_zimoma` as a named headline tile. No new fetch.
3. **FX reserves — surfacing only.** Expose the reserve lines already in `ch_snb_snbbipo` (foreign-currency investments / gold / IMF reserve position) as a named concept. No new fetch; the earlier `snbimfra` cube idea is unverified and unnecessary.

Item 1 restores the last genuinely-missing headline SNB series; items 2–3 are catalog-legibility work, not data gaps — they lift the *visible* headline coverage with no new source-script machinery.

### Do with effort (new/heavier source scripts, prioritized by value)
4. **Foreign trade by partner country (BAZG Swiss-Impex)** — the single highest-value real gap. New opendata.swiss/BAZG source script (CPA6×country×flow). Note the attribution + commercial-use license clause.
5. **Employed persons / ETS** — FSO DAM Excel `ts-x-03.02.01.08`, reuse the existing DAM recipe.
6. **Construction investment** — FSO DAM Excel `je-d-09.04.01.27`. **Decide first** whether the 2019-frozen-level + chained-growth limitation is acceptable; if not, defer.

### Defer (secondary, open but low marginal value)
GDP by canton/regional GDP; GFCF/investment component detail; labour productivity; construction price index (Baupreisindex); tertiary-sector turnover; SAKE/LFS participation & hours; cross-border commuters; HICP; SECO WEA weekly index; KOF weekly WBI + sentiment composites (free via kofdata API); detailed/long population (popdet, BEVNAT); BESTA employment-outlook index. All open via STAT-TAB/SDMX/opendata.swiss/Excel; add opportunistically.

### Declare explicitly out of scope
- **PMI (procure.ch/UBS)** — genuinely closed; document the decision so it stops resurfacing as a "gap."
- **Industrial orders** — not on SDMX, PX-Web dead from this env; revisit only if a new open channel appears.
- **VSMI + SIX constituent/total-return families** — SIX-licensed; open index *levels* are already covered.

### Catalog-hygiene note
The synthesis over-counted gaps because it inferred dataset contents from titles rather than datasheets — four "headline gaps" were already shipped (GDP components, debt-to-GDP, federal balance, production index). Worth a short pass to make the richly-dimensioned single datasets (ch_seco_gdp's structure tree, ch_ffa_finances' model/indicator tree, ch_fso_production's PTOT default) more legible in the concept tree, so this confusion — and any duplicate-add effort — is avoided going forward.
