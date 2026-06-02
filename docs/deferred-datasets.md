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

## ⚠️ The recurring blocker: FSO PX-Web has two backends, and only one is reachable

This is the single most re-discovered dead end. Read it before touching any FSO
`px-x-*` cube that isn't already in the catalog.

- The working JSON API is `https://www.pxweb.bfs.admin.ch/api/v1/en/{id}/{id}.px`
  (metadata) + POST for data. It serves the cubes we already ingest — **besta**
  (`px-x-0602000000_101`), **hesta** (`px-x-1003020000_103`), **jobs_sex**
  (`px-x-0602000000_102`), **vacancies**. `R/source_fso.R::fso_fetch_auto` speaks
  only to this endpoint.
- Many **current** STAT-TAB cubes we want (vehicle registrations, construction
  investment, vacant dwellings, …) live on the **new STAT-TAB** instance, reachable
  in a browser at `…/pxweb/{lang}/{db}/{level}/{table}.px` (note the nested path).
  From our environment, **every** programmatic path to these returns an error:
  `/api/v1/en/{id}/{id}.px` → **400**, `/pxweb/{…}.px` (GET) → **500**,
  `/pxweb/api/v1/…` and `/pxweb/api/v2/…` → **404**.
- The catalog nav `GET /api/v1/en/` returns ~673 `dbid`s, but **almost all of them
  404/400 when fetched** — the listing is stale and does **not** indicate
  reachability. Do not trust it as a discovery tool.
- The **old (2019) cube IDs** from `mbannert-swissdata` are all retired (400). Don't
  port them blind.

**Consequence:** these cubes cannot be added with the existing `fso_fetch_auto`.
Adding them needs a **new STAT-TAB fetcher** (PxWeb API 2.0, POST-based) *and* a
confirmed reachable host from the build environment. Until that fetcher exists,
the FSO real-economy set below stays deferred. Verified the hard way 2026-06-02.

---

## Deferred datasets

| Dataset | Provider | Old id | Why deferred | What it would take |
|---|---|---|---|---|
| Purchasing Managers' Index (PMI) | procure.ch / UBS (was Credit Suisse) | `source_PMI.R` (Gen-1) | Genuinely **closed data** — no open file; only headline numbers in press releases. The classic "Macrobond closed-data" case. | Scrape press releases or find a licensed feed. Fragile + licensing-dubious; **not recommended**. |
| Industrial production **& orders** | FSO | `ch.fso.indpau` `_101`, `ch.fso.bapau` `_102` (theme 0603010000) | Retired from PX-Web. Secondary-sector **turnover** migrated to SDMX `CH1.KEU` (already shipped as `ch_fso_production`), but **order intake** is not in that flow. | Locate the orders series (SDMX flow or DAM Excel asset) and add a slice. Orders is the valuable bit (leading indicator). |
| Employed persons (ETS / Erwerbstätige) | FSO | `ch.fso.es.noga`, `ch.fso.es.rs` | The old recipe used a non-`px-x` `bfs.admin` source; no reachable PX-Web equivalent found. | Rediscover the current ETS source (likely STAT-TAB → blocked by the backend issue above, or a DAM asset). |
| New vehicle registrations | FSO | `ch.fso.frv` (`px-x-1103020200_120`) | Cube **exists and is current** (to 2026-04) in STAT-TAB, but only on the **unreachable new backend** (see blocker above). | A working STAT-TAB fetcher. The cube ID is confirmed: `px-x-1103020200_120` (EN, by canton/vehicle group/fuel/month). |
| Construction investment | FSO | `ch.fso.cah.inv` (theme 0904010000) | Same STAT-TAB backend blocker; also ~15 live cubes under the theme need disambiguation. | STAT-TAB fetcher + pick the right cube by title. |
| Vacant dwellings (Leerwohnungen) | FSO | `ch.fso.cah.edc` (theme 0902020100) | Same STAT-TAB backend blocker; ~26 cubes under the theme. | STAT-TAB fetcher + pick the right cube (the vacancy-rate one). |

---

## Recently un-deferred (added)

- **Adecco Group Swiss Job Market Index** (`ch_adecco_sjmi`) — added 2026-06-02. The
  catalog's first **non-government provider** (University of Zurich
  Stellenmarkt-Monitor). Source is a scraped DAM `.xlsx`, fully reachable — see
  `datasets/ch_adecco_sjmi.md`. Proof that the private-provider direction works
  when the source isn't behind the STAT-TAB wall.

## Next step if you want the FSO set

Don't re-investigate the API (it won't budge from here). The one unblocking move is
a **STAT-TAB fetcher module** (`R/source_fso_stattab.R`) against PxWeb API 2.0,
tested for reachability first. If reachable, vehicle registrations
(`px-x-1103020200_120`) is the cleanest first target; construction and dwellings
follow once their exact cube IDs are confirmed.
