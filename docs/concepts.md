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

Borrowed from Macrobond, scaled to Switzerland:

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

### Prices
| Concept | Canonical | Freq | Alternates / notes | Dropped |
|---|---|---|---|---|
| Consumer prices (CPI) | `ch_fso_cpi` (FSO, 443 positions) | monthly | — | SNB `plkopr` |
| Core inflation | SNB `plkoprinfla` | monthly | analytical SNB/SFSO measure, not raw CPI — keep | — |
| Producer & import prices | `ch_fso_ppi` (FSO) | monthly | base-year variants are one series | — |
| Real estate prices | SNB `plimoinchq` | quarterly | no FSO equivalent in set | — |

### Labour
| Concept | Canonical | Freq | Alternates / notes | Dropped |
|---|---|---|---|---|
| Employment / jobs | `ch_fso_besta` (FSO, by division) | quarterly | breakdowns `ch_fso_jobs_sex`, `ch_fso_vacancies`; SNB `ambeschkla` is an SNB re-publication kept as a labelled alternate | — |
| Job vacancies | `ch_fso_vacancies` (FSO) | quarterly | leading indicator | — |
| Unemployment | two alternates kept | monthly | SNB `amarbma` (registered, SECO-origin) **and** `ch_fso_unemp_rate` (ILO) — different definitions, both labelled | — |
| Wages | `ch_fso_wage_idx` (FSO) | annual | nominal + real, by sector/sex | — |

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
| Bond yields | SNB `rendoblid` (daily) | daily | drop `rendoblim` (monthly roll-up of daily); spot curve kept |

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
| Foreign trade | SNB `ausshawarm` | — | by goods category |

### Business cycle & sentiment
| Concept | Canonical | Freq | Notes |
|---|---|---|---|
| Leading barometer | `ch_kof_barometer` (KOF) | monthly | the headline cyclical indicator |
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

## Deduplication decisions

**Dropped (pure format re-exports — canonical exists elsewhere):**
- SNB `gdppn`, SNB `gdpap` → SECO `ch_seco_gdp` is canonical GDP.
- SNB `plkopr` → FSO `ch_fso_cpi` is canonical CPI.
- FSO `ch_fso_gdp_use` (annual expenditure) → redundant with the SECO quarterly
  expenditure breakdown (canonical), at lower frequency.

**Dropped (native-frequency roll-up — higher frequency kept):**
- SNB `rendoblim` (monthly bond yields) → keep `rendoblid` (daily).
- SNB `devwkieffim` (monthly effective FX) → keep `devwkieffid` (daily).

**Kept as labelled alternates (genuinely different definition):**
- Unemployment: SNB `amarbma` (registered, SECO-origin) **and** FSO `ch_fso_unemp_rate` (ILO).
- Inflation: FSO `ch_fso_cpi` (headline) **and** SNB `plkoprinfla` (core).

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
