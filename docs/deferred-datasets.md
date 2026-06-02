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

## Deferred datasets (reachable — pending a fetcher/slice, except PMI)

| Dataset | Provider | How to actually get it (verified 2026-06-02) | Remaining work |
|---|---|---|---|
| New vehicle registrations | FSO | **SDMX** agency `CH1.MFZ_IVS`, flow `DF_IVS_0_GENERAL_M` (monthly) / `DF_IVS_0_GENERAL` (annual). Live, current. | Generic SDMX fetcher (the existing one is hardcoded to the `CH1.KEU` dim set) + slice to Switzerland-total (full key is ~50MB). |
| Vacant dwellings (Leerwohnungsziffer) | FSO | **SDMX** agency `CH1.LWZ`, flow `DF_LWZ_1`. Live. | Same generic SDMX fetcher; cube is ~2.5M rows at municipality level — slice to national total + total rooms/type. |
| Construction investment (Bauinvestitionen) | FSO | **DAM Excel** order `je-d-09.04.01.27` (asset 35965030), via `fso_excel_download`. Live. | Bespoke parser: multi-sheet snapshot (one sheet/year, methodology break 2012-2013) — stitch the "Total" row across sheets. |
| Industrial production **& orders** | FSO | Turnover already shipped (`ch_fso_production`, SDMX `CH1.KEU`). **Orders** not yet located — likely another SDMX flow under the production/`KEU` agency or a DAM asset. | Find the orders flow in the SDMX dataflow list (search "order"/"Auftrag"); orders is the valuable leading indicator. |
| Employed persons (ETS / Erwerbstätige) | FSO | Not yet pinned. Check the SDMX dataflow list (likely a `DF_…` employment flow) before anything else. | Identify the flow, then slice. |
| Purchasing Managers' Index (PMI) | procure.ch / UBS (was Credit Suisse) | **Genuinely closed** — no open file; headline only in press releases. The classic "Macrobond closed-data" case. | Scrape press releases or license a feed. Fragile + licensing-dubious; **not recommended.** This is the only truly-blocked one. |

---

## Recently un-deferred (added)

- **Adecco Group Swiss Job Market Index** (`ch_adecco_sjmi`) — added 2026-06-02. The
  catalog's first **non-government provider** (University of Zurich
  Stellenmarkt-Monitor). Scraped DAM `.xlsx`, fully reachable — see
  `datasets/ch_adecco_sjmi.md`.

## Next step to clear the FSO set

The single highest-leverage move is a **generic SDMX fetcher** (generalize
`R/source_fso_sdmx.R` beyond the `CH1.KEU` dimension set, parameterized by agency +
flow + a national-total key filter). That unblocks vehicles and dwellings at once,
and any future SDMX flow. Construction needs a separate bespoke Excel parser. Only
PMI stays deferred for real.
