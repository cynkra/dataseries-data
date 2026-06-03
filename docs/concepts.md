# The dataseries Concept Universe

This is the curation backbone of the catalog: what belongs in it, which source is
canonical for each concept, and how duplicates and frequencies are handled. The ETL
may pull more than this (we store the complete source data); this document defines
the curated **view** the website and clients present.

The companion document [`principles.md`](principles.md) states the general curation
rules; this document is the concrete taxonomy those rules produce. Each dataset's
datasheet (`datasets/<id>.md`) names its `concept` (a `Group / Leaf` from the tree
below) and its `canonical` flag, and is the source of truth for that classification.

## Model: concept-first, source-second

The organizing principle, scaled to Switzerland:

- Users browse a **concept tree** (National accounts → Prices → Consumer prices),
  not a list of provider dumps. Source, region, unit, seasonal adjustment and
  frequency are **attributes**, not the organizing axis.
- Each concept resolves to **one canonical series**, taken from the authoritative
  Swiss producer, plus labelled **alternates** only where a second series is a
  genuinely different definition (not a format re-export).
- Frequency is a property of a series, not its identity. We keep the **native
  published frequency** and do not synthesize extra frequencies; where a producer
  publishes the same series at two frequencies and one is just a roll-up of the
  other, we keep the higher one only.

The overview the website renders is exactly this tree, with one canonical entry per
leaf and alternates nested beneath it; source is a filter, not a heading.

## Concept taxonomy

One row per concept. *Canonical* is the dataset the overview shows; *alternates* are
kept and labelled; *dropped* series are removed from ingestion.

### National accounts
| Concept | Canonical | Freq | Alternates / notes | Dropped (re-export) |
|---|---|---|---|---|
| GDP (output, expenditure, income) | `ch_seco_gdp` (SECO) | quarterly | — | SNB `gdppn`, SNB `gdpap`, FSO `ch_fso_gdp_use` (redundant with SECO quarterly) |
| Regional GDP | `ch_fso_gdp_region` (FSO) | annual | nominal, by canton + greater region; complements the national SECO GDP | — |
| Investment (GFCF) detail | `ch_fso_gfcf_detail` (FSO) | annual | by institutional sector × asset type (construction/equipment); finer than the total-economy GFCF inside `ch_seco_gdp` | — |
| Labour productivity | `ch_fso_labour_productivity` (FSO) | annual | GDP / hours / productivity, chained-volume index 1991=100 | — |

### Prices
| Concept | Canonical | Freq | Alternates / notes | Dropped |
|---|---|---|---|---|
| Consumer prices (CPI) | SNB `plkopr` (headline total, since 1921) | monthly | `ch_fso_cpi` (FSO, 443 positions — detailed COICOP breakdown, since 1982) | — |
| Core inflation | SNB `plkoprinfla` | monthly | analytical SNB/SFSO measure, not raw CPI — keep | — |
| Producer & import prices | `ch_fso_ppi` (FSO) | monthly | base-year variants are one series | — |
| Real estate prices | SNB `plimoinchq` | quarterly | no FSO equivalent in set | — |
| Harmonised CPI (HICP) | `ch_fso_hicp` (Eurostat) | monthly | EU-comparable index (2015=100); excludes owner-occupied housing + health-insurance premiums, so distinct from the LIK above | — |
| Construction prices | `ch_fso_construction_prices` (FSO) | semi-annual | Baupreisindex — total / building (Hochbau) / civil engineering (Tiefbau) | — |

### Labour
| Concept | Canonical | Freq | Alternates / notes | Dropped |
|---|---|---|---|---|
| Employment / jobs | `ch_fso_besta` (FSO, by division) | quarterly | breakdowns `ch_fso_jobs_sex`, `ch_fso_vacancies`; SNB `ambeschkla` is an SNB re-publication kept as a labelled alternate | — |
| Employed persons (ETS) | `ch_fso_ets` (FSO) | quarterly | headcount on the domestic concept, by sector × sex — a distinct concept from BESTA *jobs* | — |
| Hours worked | `ch_fso_hours_worked` (FSO) | annual | actual weekly + annual hours and total working volume (AVOL), by sex × working-time | — |
| Job vacancies | `ch_fso_vacancies` (FSO) | quarterly | leading indicator | — |
| Employment outlook | `ch_fso_besta_outlook` (FSO) | quarterly | forward-looking BESTA hiring-intent index (diffusion ratio around 1.0) | — |
| Cross-border commuters | `ch_fso_cross_border_commuters` (FSO) | quarterly | foreign commuters by canton of work (model-based estimate) | — |
| Unemployment | two alternates kept | monthly | SNB `amarbma` (registered, SECO-origin) **and** `ch_fso_unemp_rate` (ILO) — different definitions, both labelled | — |
| Wages | `ch_fso_wage_idx` (FSO) | annual | nominal + real, by sector/sex | — |

### Domestic economy
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Retail trade turnover | `ch_fso_retail` (FSO) | monthly | turnover index (FSO SDMX) |
| Industry & construction turnover | `ch_fso_production` (FSO) | quarterly | secondary-sector turnover + production index |
| Services turnover | `ch_fso_services` (FSO) | quarterly | tertiary sector — completes the retail + industry + services triad |

### Money & banking
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Monetary aggregates | SNB `snbmonagg` (M1–M3) | monthly | + monetary base, target range, SNB balance sheet |
| Banking / credit | SNB `babilpobm`, `bakred*` | monthly | balance-sheet items, corporate/mortgage/sector loans |

### Interest rates & yields
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Policy / official rates | SNB `snboffzisa` | — | |
| Money-market rates | SNB `zimoma`, `zikredlauf`, `zikrepro` | — | |
| Bond yields | SNB `rendeiduebd` (daily spot rates) | daily | canonical = the live spot-rate cube (`CHF × 10J` = 10Y Confederation benchmark). `rendoblid` (par yields) was discontinued by the SNB (frozen 2025-07-31) and is **not** ingested — its CHF curve is covered here; `rendoblim` (monthly roll-up) also dropped |

### Exchange rates
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Bilateral FX | SNB `devkum`, `devlandm`, `devwkibiim` | monthly | |
| Effective FX index | SNB `devwkieffid` (daily) | daily | drop `devwkieffim` (monthly roll-up of daily) |

### External sector
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Balance of payments | SNB `bop*q` | quarterly | current / financial / overview / services. The overview cube `ch_snb_bopoverq` is kept because it carries the capital account + statistical difference the detail cubes lack |
| International investment position | SNB `auver*q`, `auvekomq` | quarterly | the overview cube `auvekomq` is kept for its deep IIP functional tree |
| Foreign trade | SNB `ausshawarm` (by goods) + `ch_fso_trade_partner` (by partner country) | — | goods category from the SNB cube; partner-country exports + imports (annual CHF mn) from the FSO/BAZG asset — complementary dimensions |

### Business cycle & sentiment
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Leading barometer | `ch_kof_barometer` (KOF) | monthly | the headline cyclical indicator |
| Economic sentiment | `ch_kof_esi` (KOF) | monthly | survey sentiment composite, sibling to the barometer (two methodology vintages) |
| Weekly economic activity | `ch_seco_wwa` (SECO) | weekly | high-frequency GDP-growth tracker (WEA); the catalog's only weekly series |
| Consumer confidence | SNB `concon` (SECO-origin survey) | quarterly | attributed to SECO, its true producer |
| Business cycle signals | SNB `snbkosiq` | quarterly | |

### Financial markets
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Swiss stock indices | SNB `capchstocki` | daily | |
| Securities turnover | SNB `capweums` | — | |

### SNB policy & forecasts
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Conditional inflation forecast | SNB `snbiprogq` | quarterly | future end-dates are the forecast horizon, not staleness |

### Payment systems
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Payments & cash | SNB `zave*` | — | SIC, cards, ATMs, e-money |

### Tourism
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Hotel overnight stays | `ch_fso_hesta` (FSO, by region) | monthly | |

### Population & demographics
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Resident population | `ch_fso_pop` (FSO) | annual | demographic balance back to 1861 |
| Resident population by nationality | `ch_fso_pop_detail` (FSO) | annual | nationality × sex stock (STATPOP, 2010–); detail alternate to the headline balance |

## Deduplication decisions

**Dropped (pure format re-exports — canonical exists elsewhere):**
- SNB `gdppn`, SNB `gdpap` → SECO `ch_seco_gdp` is canonical GDP.
- FSO `ch_fso_gdp_use` (annual expenditure) → redundant with the SECO quarterly
  expenditure breakdown (canonical), at lower frequency.

**Dropped (native-frequency roll-up — higher frequency kept):**
- SNB `rendoblim` (monthly bond yields) → dropped. The daily par-yield cube `rendoblid` was also dropped (the SNB discontinued it, frozen 2025-07-31); the live daily spot cube `rendeiduebd` is canonical for Bond yields.
- SNB `devwkieffim` (monthly effective FX) → keep `devwkieffid` (daily).

**Kept as labelled alternates (genuinely different definition):**
- Unemployment: SNB `amarbma` (registered, SECO-origin) **and** FSO `ch_fso_unemp_rate` (ILO).
- Inflation: SNB `plkoprinfla` (core) alongside the headline CPI.
- Consumer prices: SNB `plkopr` (canonical — headline total back to **1921**)
  **and** FSO `ch_fso_cpi` (the detailed 443-position COICOP basket, but only back
  to 1982). The long headline beats the detailed-but-short asset for the canonical
  slot; the FSO breakdown is kept as the labelled alternate. (Reversed 2026-06-02:
  `plkopr` was previously dropped as a "pure re-export" — that call missed the
  ~61 extra years of headline history the SNB chain carries.)

**Kept overview cubes (carry unique aggregates the detail cubes lack):**
- `ch_snb_bopoverq` — capital account + statistical difference.
- `ch_snb_auvekomq` — the deep IIP functional tree.

## Frequency policy

- Store the native published frequency only. No synthesized aggregation in the store.
- A future UI frequency selector (if built) would aggregate at view time. For
  correctness it needs a per-series method, recorded here so it is not forgotten:
  index series → mean, stock series → last (end of period), flow series → sum. This
  is out of scope until the selector is built.

## Catalog metadata

Each dataset's meta and `catalog.json` carry:
- `concept` — the leaf in the taxonomy above (drives the overview tree).
- `canonical` — true for the headline series of a concept, false for alternates.
- (later) `aggregation` — `mean | sum | last`, only when the frequency selector is built.
