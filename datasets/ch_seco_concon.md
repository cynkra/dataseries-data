# Consumer sentiment index

- **id**: ch_seco_concon
- **title**: Consumer confidence | de: Konsumentenstimmung | fr: Climat de consommation | it: Clima di consumo
- **concept**: Business cycle and sentiment / Consumer confidence
- **canonical**: yes
- **featured**: Consumer confidence

- **source**: seco
- **license**: seco
- **frequency**: quarterly
- **coverage**: 1972-Q4 .. 2026-Q2
- **series**: 26
- **updated**: 2026-05-05 (source publish date)

## What is special
How Swiss households see the economy, prices, job security, their own finances and whether to make big purchases. Raw and seasonally adjusted.

## Access
- **type**: seco-swissdata — SECO swissdata
- **set**: `ks-seco` (quarterly codes `*_q` only)
- **endpoint** (2026-06: SECO retired the old `/dam/...download` URLs — they now 502 — and serves the machine-readable files via `scheduler.swissdatas.ch`, linked from the new page `seco.admin.ch/konsumentenstimmung`. 2026-11: the separate `ks-q` / `ks-m` files were replaced by one file holding the monthly (`*_m`, since 2023) and quarterly (`*_q`, since 1972) series; we keep the quarterly ones. SECO also publishes an experimental `ks-exp-seco`):
  - data: `https://scheduler.swissdatas.ch/scheduled/ks-seco.csv`
  - meta: `https://scheduler.swissdatas.ch/scheduled/ch-seco-ks.json`
- **call**: `seco_fetch("ch_seco_concon", data_url = <ks-seco.csv>, meta_url = <ch-seco-ks.json>, strip = "numbering", keep = "_q$")`

## Parsing recipe
SECO already publishes the swissdata long format, so the fetch is a passthrough
(reuses `R/source_seco.R::seco_fetch`). The CSV is `structure,type,seas_adj,date,value`
with ISO first-of-quarter dates (`1972-10-01`). The JSON sidecar carries multilingual
`title`, `source_name`, `units`, `dim_order = [type, structure, seas_adj]`, and the
`labels` block (dimnames + per-code level labels). `.seco_dimensions()` maps `labels`
into the contract `dimensions` shape; there is no `hierarchy` in this source, so the
split/single-select/default below are declared here (the website derives them from
this datasheet, not from a hierarchy heuristic).

Level labels: SECO puts its questionnaire numbering in front of each item label
("6.3 Consumer sentiment index", "3.2 Unemployment outlook") in all four languages.
The fetcher removes it (`seco_fetch(strip = "numbering")`, pattern in
`R/labels.R::LABEL_NOISE`).

## Dimensions
- `structure` — survey item. `ks_i63_index_q` is the composite **Consumer
  sentiment index** (SECO item 6.3, headline); the remaining codes are the component balances
  (`ks_i11_econ_hist_q` past economic situation, `ks_i12_econ_exp_q` economic outlook,
  `ks_i21_price_hist_q` / `ks_i22_price_exp_q` price situation/outlook,
  `ks_i31_job_secure_q` job security, `ks_i32_unemp_exp_q` unemployment outlook,
  `ks_i41_fin_pos_hist_q` / `ks_i42_fin_pos_exp_q` financial situation past/future,
  `ks_i51_save_q` saving, `ks_i52_spend_q` major-purchase timing, `ks_i53_save_exp_q`
  saving outlook). All are data leaves.
- `type` — `index` (index points) or `sd` (standard deviation).
- `seas_adj` — `na` (raw) or `csa` (seasonally + calendar adjusted).

## Labels
- dim: structure
  - grp_prices: Prices | de: Preise | fr: Prix | it: Prezzi
  - grp_jobs: Employment | de: Beschäftigung | fr: Emploi | it: Occupazione
  - grp_saving: Saving | de: Sparen | fr: Épargne | it: Risparmio

## Display
- **split**: structure
- **single-select**: type, seas_adj
- **default**: structure=ks_i63_index_q, type=index, seas_adj=csa
- **transform**: level
- **seasonal adjustment**: single-select on `seas_adj`; default to the seasonally +
  calendar adjusted series (`csa`); raw (`na`) available as a toggle.

## Hierarchy
The headline **6.3 Consumer sentiment index** is the parent of the four sub-indices it
is actually computed from — expected economic development (1.2), past and expected
financial situation (4.1, 4.2) and the right time for major purchases (5.2) — per the
SECO methodology (BFS June-2024 survey publication). The remaining survey balances are
grouped by theme.
- ks_i63_index_q
  - ks_i12_econ_exp_q
  - ks_i41_fin_pos_hist_q
  - ks_i42_fin_pos_exp_q
  - ks_i52_spend_q
- ks_i11_econ_hist_q
- @grp_prices
  - ks_i21_price_hist_q
  - ks_i22_price_exp_q
- @grp_jobs
  - ks_i31_job_secure_q
  - ks_i32_unemp_exp_q
- @grp_saving
  - ks_i51_save_q
  - ks_i53_save_exp_q

## Caveats / simplifications
- Producer attribution corrected: this is SECO's own publication, replacing the SNB
  re-export `ch_snb_concon` (retired). Same survey, fetched at source, with the SA
  track added.
- Values are survey balances / index points, not levels; the composite
  `ks_i63_index_q` is the series most users want.
- The pre-2024 history was re-based by SECO to align with the current methodology.
- SECO dropped the old 6.2 index variant (`ks_i62_index_q`) when it merged the monthly
  and quarterly files in 2026-11; it is no longer in the dataset.

## Provenance
Script: `R/source_seco.R::seco_fetch` (wired in `R/pipeline.R`). Datasheet authored
2026-06-01; parser verified 2026-06-01.

## What is special (de)
Wie Schweizer Haushalte die Wirtschaft, die Preise, die Arbeitsplatzsicherheit, ihre eigenen Finanzen und grössere Anschaffungen einschätzen. Unbereinigt und saisonbereinigt.

## What is special (fr)
Comment les ménages suisses voient l'économie, les prix, la sécurité de l'emploi, leurs propres finances et les achats importants. Brut et désaisonnalisé.

## What is special (it)
Come le economie domestiche svizzere vedono l'economia, i prezzi, la sicurezza del posto di lavoro, le proprie finanze e i grandi acquisti. Grezzo e destagionalizzato.
