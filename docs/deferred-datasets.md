# Deferred datasets

A registry of datasets we **considered and deliberately did not ingest (yet)**,
with the concrete reason and what it would take to add them. The point is to stop
re-discovering the same dead ends every session: if you are about to go hunting
for one of these, read the reason here first.

This is the counterpart to the per-dataset datasheets in `datasets/`: those
document what we ship; this documents what we knowingly skipped and why. When you
defer something, add it here (and if it's a source-API gotcha, also note it in
[`source-quirks.md`](source-quirks.md)).

---

## ⚠️ "Deferred" here means NOT-YET-BUILT, not unreachable

The FSO real-economy set below is **reachable today** — just not via PX-Web. FSO
publishes the same data through four channels; the right ones (SDMX, DAM Excel) are
documented in [`source-quirks.md` → "FSO publishes the same data through FOUR
channels"](source-quirks.md). **Read that before touching these.** The short version:

- **PX-Web / STAT-TAB is a dead end from our build env** for any cube we don't already
  ship (`/pxweb/…` → 400/404/500; the `/api/v1/en/` nav lists ~673 ids that nearly all
  400 — stale). Old 2019 `mbannert` cube ids are retired. Do **not** re-investigate it.
- **SDMX (`disseminate.stats.swiss`) is the clean channel** and already powers
  retail/production. Discover with `GET /rest/dataflow/all/all/latest`. Vehicles and
  dwellings are there (flow ids below); cubes are large, so slice to the national total.
- **DAM Excel (order numbers)** powers CPI/wages/pop; construction investment is there.

History note: this SDMX-is-the-real-channel discovery has been made and **lost** more
than once. It is now written here and in `source-quirks.md` so it stops getting lost.

---

## Still deferred (verified 2026-06-02; SIX / PMI / BAZG-monthly re-verified 2026-06-03)

| Dataset | Provider | Status / how to get it | Why still deferred |
|---|---|---|---|
| Construction investment (Bauinvestitionen) national levels | FSO | **Reachable** via DAM Excel order `je-d-09.04.01.27` (asset 35965030); levels now run to ~2023 (the stale "ends 2019" note is corrected). | **Largely superseded** — `ch_fso_gfcf_detail` already ships Hochbau/Tiefbau construction GFCF by sector with full 1995–2024 levels. This is the fragile multi-layout national-total cut (13/25/5-col header detection, ~18-month lag, 2012/13 break); low marginal value. Integrate opportunistically only if the national Tiefbau/Hochbau split outside the institutional-sector frame is wanted. |
| Industrial **order intake** (Auftragseingang/-bestand) | FSO | **Not on SDMX.** Exhaustively searched all 182 dataflows (order/Auftrag/intake/book/eingang/commande) — absent. Turnover *is* shipped (`ch_fso_production`). | Would need the STAT-TAB (dead from our env) or DAM Excel channel, or SECO/KOF survey. Do **not** re-search SDMX. |
| LFS / SAKE labour-force **participation rate** (Erwerbsquote) | FSO | Open (DAM/SAKE), but a messier age-band layout. Hours/working-volume (`ch_fso_hours_worked`) is shipped; the activity-rate cut was skipped. | Low marginal value; add opportunistically. |
| Purchasing Managers' Index (PMI) | procure.ch / UBS | **Genuinely closed (re-verified 2026-06-03).** No open CSV/API/SDMX exists — procure.ch/UBS publish PDFs stamped "educational/marketing" only; Yahoo/Investing/Trading-Economics show it on-page but forbid redistribution. The OECD/FRED "Swiss manufacturing confidence" series that *look* like a PMI are the **KOF business-tendency survey**, not the procure.ch PMI (and KOF is already shipped via `ch_kof_barometer` / `ch_kof_esi`). | Only path is a **licensing / partnership** with procure.ch/UBS — a business deal, not an open-data gap. Do not scrape PDFs. |
| Swiss equity data beyond the SNB cube — **VSMI** volatility, SMIM, constituents, intraday, on-book EOD turnover | SIX | **Closed (re-verified 2026-06-03).** SIX index time series + constituents are license-gated (SIX Index Data Center / Exfeed, paid; trademark/IP controlled); every free mirror that returns machine-readable data (Yahoo `^SSMI`/`V3X.SW`, stooq, Investing) **prohibits redistribution**. The **open** equity slice — SMI, SPI total-return, SIX+ICB sector sub-indices, daily since 1989 — is **already shipped** via `ch_snb_capchstocki` (SNB open licence). | No redistributable channel for VSMI/SMIM/constituents. The open slice is already in; the rest needs a SIX licence. |
| Foreign trade — **MONTHLY by commodity × partner country** (Swiss-Impex TN8 / CPA6) | BAZG / FOCBS | **OPEN (re-verified 2026-06-03; the earlier HTTP 502 was a transient outage).** opendata.swiss `waren-aussenhandel-nach-tarifnummer-land`; direct CSV-ZIP English masters at `https://ocean.nivel.bazg.admin.ch/open-data-reports/TN8_EXP_en/TN8_EXP_en.zip` (+ `TN8_IMP_en`), HTTP 200, updated 2026-06-02. Same `terms_by_ask` licence already accepted for `ch_fso_trade_partner`. | **Deferred for INGEST SIZE, not access** — each ZIP is ~0.5–0.7 GB (full TN8 8-digit tariff × country × month). Needs a sliced/aggregated ingest (CPA6 product classes × top partners, or monthly total-by-country), like the SDMX-sliced pattern, not a whole-cube pull. **Real added value** (monthly + the commodity dimension the annual `ch_fso_trade_partner` lacks) — the strongest remaining candidate to add. |

### Construction stitch recipe (if/when wanted)
DAM Excel `je-d-09.04.01.27`, one sheet per year-pair. Year = first 4 chars of the
sheet name. Keep only sheets containing the literal `in Mio. Fr.` (the 2020-2021…
2024-2025 sheets are %-change-only → drop). Locate columns by header text, never by
index (layouts vary 13/25/5-col): `Tiefbau`/`Hochbau` group headers + the first
`in Mio. Fr.` sub-header in each group (the second is Arbeitsvorrat/backlog — skip).
National row = `col1 == "Total"`. Emit tiefbau / hochbau / total, CHF mn current
prices. Methodology break alte→neue Erhebung at 2012/2013 (smooth, +4.5%; flag, no
chaining needed). Verified extract: 2007 Total=47459.8, 2012=56268.3, 2013=58783.5,
2019=61339.7.

---

## Recently un-deferred (added)

- **New registrations of passenger cars by fuel** (`ch_fso_new_vehicles`) — added
  2026-06-02. FSO **SDMX** `CH1.MFZ_IVS/DF_IVS_0_GENERAL_M`, national-total slice,
  12 fuel series 2005–2026. See `datasets/ch_fso_new_vehicles.md`.
- **Vacant dwellings** (`ch_fso_vacant_dwellings`) — added 2026-06-02. FSO **SDMX**
  `CH1.LWZ/DF_LWZ_1`, vacancy rate + count, 1995–2025. See
  `datasets/ch_fso_vacant_dwellings.md`.
- **Adecco Group Swiss Job Market Index** (`ch_adecco_sjmi`) — added 2026-06-02. The
  catalog's first **non-government provider** (UZH Stellenmarkt-Monitor). Scraped
  DAM `.xlsx`. See `datasets/ch_adecco_sjmi.md`.

Both SDMX adds use the new sliced helper `R/source_fso_sdmx.R::sdmx_sliced` (a
national-total key pull, since the full cubes are millions of rows) — the reusable
pattern for any future large SDMX flow.

### 2026-06-02 (second batch — 14 datasets, all live-verified)

Six **integrate-now** (reuse an existing helper):
- `ch_fso_services` — tertiary turnover, FSO SDMX `CH1.KEU/DF_KEU_Q1` (tertiary NOGA slice).
- `ch_fso_cross_border_commuters` — Grenzgänger by canton, FSO SDMX `CH1.GGS/DF_GGS_1` (`sdmx_sliced`).
- `ch_fso_pop_detail` — population by nationality × sex, FSO SDMX `CH1.STATPOP/DF_STATPOP_REGLING`.
- `ch_fso_labour_productivity` — GDP-per-hour index, FSO DAM CSV `ts-x-04.07.01.01` (new `source_fso_dam_csv.R`).
- `ch_kof_esi` — KOF Economic Sentiment Index via the open KOF **`sets`** endpoint (`kof_set_fetch`).
- `ch_fso_besta_outlook` — employment-outlook index, FSO **PX-Web** `px-x-0602000000_105` (the besta theme-0602 family is reachable).

Eight **with-effort** (new bespoke parser):
- `ch_fso_ets` — employed persons (ETS, domestic concept), FSO DAM CSV `ts-x-03.02.01.08`. **Un-defers** the old "ETS not on SDMX" entry — the DAM CSV channel works.
- `ch_fso_gfcf_detail` — GFCF by institutional sector × asset, FSO DAM CSV `ts-x-04.02.05.02` (filter `UNIT_MEAS==MCHF`).
- `ch_fso_hours_worked` — actual hours / working volume (AVOL), FSO DAM CSV `ts-x-03.02.03.01.02.01`.
- `ch_fso_trade_partner` — foreign trade by partner country, FSO DAM Excel (English assets 36664830/36664836).
- `ch_fso_gdp_region` — regional GDP, FSO DAM Excel `je-e-04.02.06.01`.
- `ch_fso_construction_prices` — Baupreisindex, FSO DAM Excel `cc-t-05.05.01`.
- `ch_fso_hicp` — EU-harmonised CPI, **Eurostat** SDMX `prc_hicp_midx` (new `source_eurostat.R` — first non-Swiss-producer source).
- `ch_seco_wwa` — SECO Weekly Economic Activity index — the catalog's first **weekly** series.

Two channel discoveries to remember: the KOF **`sets`** endpoint is open (the per-key `ts` endpoint's 412 wall does not apply); the **BAZG monthly** trade-by-tariff-×-country OGD CSV (the richer upgrade path for `ch_fso_trade_partner`, since 1988) returned HTTP 502 from this build env at the time — **re-verified open 2026-06-03** (transient outage; now in the deferred table above as the strongest remaining candidate).

### 2026-06-03 — held 4 shipped + closed set re-verified
All 14 are now in the catalog (70 total): the 4 previously held for display work —
`ch_fso_ets` (split=sector tree / sex selector), `ch_fso_gdp_region` (reworked to a
hierarchical CH→greater-region→canton tree), `ch_fso_gfcf_detail` (split=sector / asset
selector), `ch_fso_hours_worked` (split=worktime / measure+sex selectors) — landed with
clean displays. The closed set (PMI, SIX/VSMI, industrial orders) was adversarially
re-verified against web sources and **holds**; only **BAZG monthly trade** flipped from
"502/closed" to "open, deferred for size" (see table).
