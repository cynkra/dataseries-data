# Switzerland's international investment position by sector (quarterly)

- **id**: ch_snb_auversecq
- **title**: Investment position by sector
- **concept**: External sector / International investment position
- **canonical**: yes
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: quarterly
- **coverage**: 1985-01 .. 2025-10
- **series**: 71
- **updated**: 2025 Q4 release (PublishingDate in CSV header)

## What is special
The stock counterpart to the balance-of-payments flows: Switzerland's foreign
assets and liabilities, and the resulting net international investment position
(NIIP), back to 1985. The distinctive cut here is the **sector breakdown**:
assets and liabilities are split across SNB, banks, public sector and other
sectors, so you can see who holds the foreign claims. Crossed with the IIP
component grid (direct, portfolio, derivatives, other investment, reserve
assets), this exposes Switzerland's large net creditor position and where it
sits. The reserve-assets component only carries on the assets side and only for
the SNB, so many sector/component cells are empty; the stored 71 series are the
populated combinations, not the full 3x5x6 grid.

## Access
- **type**: SNB cube API
- **endpoint**: `https://data.snb.ch/api/cube/auversecq/data/json/en`
- **call**: `snb_fetch("auversecq", title = "Switzerland's international investment position - Breakdown by sector - Quarter")`

## Parsing recipe
- Two calls per cube: `/dimensions/en` for the code->label map and the nested
  `dimensionItems` hierarchy, `/data/json/en` for the observations.
- Each timeseries `metadata.key` (e.g. `...{A,B,D1}`) carries the dimension-item
  codes in `dim_order`; `.snb_key_codes` splits the brace contents on commas and
  binds them to D0/D1/D2.
- Observations: keep non-null `value`, parse `date` to ISO (period start), cast
  `value` to numeric. Values are in CHF millions.
- `PublishingDate` in the JSON+CSV header is the freshness signal. SNB emits
  JSON and CSV only (no JSON-stat) and has no seasonal-adjustment toggle.

## Dimensions
- `D0` Accounting entry: `A` Assets, `P` Liabilities, `N` Net international
  investment position.
- `D1` Sector: `T` Total, `N` Swiss National Bank, `B` Banks, `OH` Public
  sector, `US` Other sectors.
- `D2` Component: `T` Total, `D1` Direct investment, `P` Portfolio investment,
  `D0` Derivatives, `UI` Other investment, `W` Reserve assets.

## Display
- **split**: D1
- **single-select**: D0
- **default**: D0=N, D1=T, D2=T
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube has no seasonal-adjustment dimension)

## Caveats / simplifications
- Flat hierarchy: every level is a leaf, so no parent grouping nodes are dropped.
- Not all dimension cross-products exist (reserve assets only for SNB assets);
  empty combinations simply have no rows. Series count (71) reflects this.
- Stock series (positions at quarter end), not flows; for the matching flows see
  `ch_snb_bopcapbalq`.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `auversecq`, title/topic from
`R/snb_cubes.tsv`). Datasheet authored 2026-06-01.
