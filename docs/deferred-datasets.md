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

## Still deferred (verified 2026-06-02)

| Dataset | Provider | Status / how to get it | Why still deferred |
|---|---|---|---|
| Construction investment (Bauinvestitionen) | FSO | **Reachable** via DAM Excel order `je-d-09.04.01.27` (asset 35965030). A working multi-sheet stitch recipe exists (see below). | The **absolute-level series only runs 2005–2019** — the 5 newest workbook sheets publish *only* provisional YoY %-change, no levels. Shipping a series that ends 2019 is low value; revisit when FSO republishes absolute figures, or chain the published growth onto 2019. |
| Industrial **order intake** (Auftragseingang/-bestand) | FSO | **Not on SDMX.** Exhaustively searched all 182 dataflows (order/Auftrag/intake/book/eingang/commande) — absent. Turnover *is* shipped (`ch_fso_production`). | Would need the STAT-TAB (dead from our env) or DAM Excel channel, or SECO/KOF survey. Do **not** re-search SDMX. |
| Employed persons (ETS / Erwerbstätige) | FSO | **Not on SDMX.** Enumerated all 182 dataflows — the ILO employment headcount is absent. | Would need PX-Web (`source_fso.R`) or a DAM Excel asset. Do **not** re-search SDMX. |
| Purchasing Managers' Index (PMI) | procure.ch / UBS | **Genuinely closed** — no open file; headline only in press releases. | Scrape press releases or license a feed. Fragile + licensing-dubious; **not recommended.** |

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
