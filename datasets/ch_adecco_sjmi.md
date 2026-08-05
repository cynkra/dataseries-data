# Adecco Group Swiss Job Market Index

- **id**: ch_adecco_sjmi
- **title**: Adecco Group Swiss Job Market Index
- **concept**: Labour / Job market
- **canonical**: yes
- **source**: University of Zurich (Stellenmarkt-Monitor Schweiz)
- **license**: Stellenmarkt-Monitor Schweiz, UZH (free use, attribution required)
- **frequency**: quarterly
- **coverage**: 2003 .. 2026
- **series**: 5
- **updated**: 2026 Q1

## What is special
The canonical Swiss **labour-demand** index: it tracks the number of publicly
advertised job openings, base Q1 2008 = 100. A genuine leading indicator of the
labour market and one of the few **non-government providers** in the catalog —
compiled by the Stellenmarkt-Monitor Schweiz at the University of Zurich and
branded the Adecco Group Swiss Job Market Index. The headline decomposes by where
the vacancy was advertised (internet job portals, company websites, press), which
captures the long structural shift from print to online recruiting.

## Access
- **type**: scraped
- **url**: `https://www.stellenmarktmonitor.uzh.ch/de/indices/asjmi.html`
- **call**: `adecco_fetch("ch_adecco_sjmi")`

## Parsing recipe
- The landing page carries one `.xlsx` export link whose file name embeds the
  latest quarter (e.g. `data_gesamtindex_export-2026_Q1.xlsx`). We scrape the
  `href` (a `/dam/...xlsx` path) rather than hardcoding it, so a new quarter is
  picked up automatically.
- Sheet 1 is a wide table: row 1 the year (only stamped at Q1, so forward-filled),
  row 3 the quarter (`I..IV` -> month 3/6/9/12). Each value column is one quarter,
  mapped to a first-of-quarter ISO date.
- Five labelled data rows map to the `index` levels; German source labels are
  recoded to stable codes. Early years (2003-2008) carry only Q1, then the series
  becomes fully quarterly — handled transparently since each column is dated.

## Dimensions
- `index`: the headline index and its breakdown. `gesamt` Total (base Q1 2008=100),
  `gesamt_sa` the seasonally adjusted headline, and the three publication channels
  `internet` / `company` / `press` nested under Total as a hierarchy.

## Labels
- **units**: Index, Q1 2008 = 100
- dim: index
  - **label**: Index
  - gesamt: Total
  - gesamt_sa: Total, seasonally adjusted
  - internet: Internet job portals
  - company: Company websites
  - press: Press (newspapers)

## Display
- **split**: index
- **single-select**:
- **default**: index=gesamt
- **transform**: level
- **seasonal adjustment**: published as a level (`gesamt_sa`), not a toggle — the
  source provides the seasonally adjusted headline directly; the app cannot
  reconstruct it, so it is kept as its own series.

## Caveats / simplifications
- The seasonally adjusted series (`gesamt_sa`) exists only for the headline, not per
  channel, matching the source.
- The base period label (Q1 2008 = 100) follows whatever the source publishes.

## Provenance
Script: `R/source_adecco.R::adecco_fetch` (wired in `R/pipeline.R`). Datasheet
authored 2026-06-02; parser verified live 2026-06-02 (5 series, 2003-03 .. 2026-03).
