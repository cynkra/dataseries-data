# Consumer sentiment index

- **id**: ch_seco_concon
- **concept**: Business cycle & sentiment / Consumer confidence
- **canonical**: yes
- **featured**: Consumer confidence

- **source**: State Secretariat for Economic Affairs (SECO)
- **license**: seco
- **frequency**: quarterly
- **coverage**: 1972-Q4 .. 2026-Q2
- **series**: 26
- **updated**: 2026-05-05 (source publish date)

## What is special
The Swiss consumer sentiment survey, the canonical sentiment series, back to 1972 —
one of the longest survey histories in the catalog. SECO (the State Secretariat for
Economic Affairs) **runs** the survey and **publishes** the data directly in the
swissdata format, so this dataset is fetched at source and attributed to the true
producer. It **replaces** the earlier SNB re-export `ch_snb_concon`, which carried
the same numbers second-hand through the SNB cube API: the move corrects the
attribution and adds the seasonally-adjusted track that SECO publishes alongside the
raw balances.

The dataset exposes the headline **consumer sentiment index** (`ks_i63_index_q`) plus
the underlying balance components: past/expected economic situation, past/expected
prices, job security and unemployment outlook, past/future personal finances,
savings situation and outlook, and major-purchase timing. Each series is published
both raw (`na`) and seasonally + calendar adjusted (`csa`). The historical level
(1972–2023) has been re-aligned with the current methodology in use since 2024.

## Access
- **type**: SECO swissdata
- **endpoint / order number**:
  - data: `https://www.seco.admin.ch/dam/seco/en/dokumente/Wirtschaft/Wirtschaftslage/Konsumentenstimmung/ks_q.csv.download.csv/ks_q.csv`
  - meta: `https://www.seco.admin.ch/dam/seco/en/dokumente/Wirtschaft/Wirtschaftslage/Konsumentenstimmung/ks_q_json.txt.download.txt/ks_q_json.txt`
- **call**: `seco_fetch("ch_seco_concon", data_url = <ks_q.csv>, meta_url = <ks_q_json.txt>)`

## Parsing recipe
SECO already publishes the swissdata long format, so the fetch is a passthrough
(reuses `R/source_seco.R::seco_fetch`). The CSV is `structure,type,seas_adj,date,value`
with ISO first-of-quarter dates (`1972-10-01`). The JSON sidecar carries multilingual
`title`, `source_name`, `units`, `dim_order = [type, structure, seas_adj]`, and the
`labels` block (dimnames + per-code level labels). `.seco_dimensions()` maps `labels`
into the contract `dimensions` shape; there is no `hierarchy` in this source, so the
split/single-select/default below are declared here (the website derives them from
this datasheet, not from a hierarchy heuristic).

## Dimensions
- `structure` — survey item. `ks_i63_index_q` is the composite **6.3 Consumer
  sentiment index** (headline); the remaining codes are the component balances
  (`ks_i11_econ_hist_q` past economic situation, `ks_i12_econ_exp_q` economic outlook,
  `ks_i21_price_hist_q` / `ks_i22_price_exp_q` price situation/outlook,
  `ks_i31_job_secure_q` job security, `ks_i32_unemp_exp_q` unemployment outlook,
  `ks_i41_fin_pos_hist_q` / `ks_i42_fin_pos_exp_q` financial situation past/future,
  `ks_i51_save_q` saving, `ks_i52_spend_q` major-purchase timing, `ks_i53_save_exp_q`
  saving outlook, `ks_i62_index_q` the prior 6.2 index variant). All are data leaves.
- `type` — `index` (index points) or `sd` (standard deviation).
- `seas_adj` — `na` (raw) or `csa` (seasonally + calendar adjusted).

## Display
- **split**: structure
- **single-select**: type, seas_adj
- **default**: structure=ks_i63_index_q, type=index, seas_adj=csa
- **transform**: level
- **seasonal adjustment**: single-select on `seas_adj`; default to the seasonally +
  calendar adjusted series (`csa`); raw (`na`) available as a toggle.

## Caveats / simplifications
- Producer attribution corrected: this is SECO's own publication, replacing the SNB
  re-export `ch_snb_concon` (retired). Same survey, fetched at source, with the SA
  track added.
- Values are survey balances / index points, not levels; the composite
  `ks_i63_index_q` is the series most users want.
- The pre-2024 history was re-based by SECO to align with the current methodology.

## Provenance
Script: `R/source_seco.R::seco_fetch` (wired in `R/pipeline.R`). Datasheet authored
2026-06-01; parser verified 2026-06-01.
