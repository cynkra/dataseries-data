# Permanent resident population (demographic balance)

- **id**: ch_fso_pop
- **title**: Resident population
- **concept**: Population & demographics / Resident population
- **canonical**: yes
- **featured**: Population
- **source**: Swiss Federal Statistical Office (FSO)
- **license**: fso (free reuse, attribution required)
- **frequency**: annual
- **coverage**: 1861 .. 2024
- **series**: 11
- **updated**: 2025-08-27

## What is special
The annual demographic balance of the permanent resident population, **back to
1861** (the longest series in the catalog). Broader than the old parser, which
kept only the 1 January population stock; this captures the full demographic
balance the workbook provides (stocks, births, deaths, birth surplus, migration,
naturalisations, absolute change).

## Access
- **type**: fso-dam-excel — FSO DAM Excel asset
- **order number**: su-d-01.02.04.05
- **call**: `fso_excel_download("su-d-01.02.04.05")`

## Parsing recipe
- Sheet `su-d-01.02.04.05`. Year in column 1; demographic components across the
  remaining columns, modelled as one dimension `item` with 11 levels.
- Older years record unavailable components as `...`; those cells are dropped, so
  coverage varies by component (population stocks / births / deaths / birth surplus
  / absolute change run the full 1861-2024 = 163 obs; immigration/emigration only
  43; adjustments 33; naturalisation 135).
- Column 13 (percentage change) is excluded as a ratio, not a person count.
- European number parsing wired in (all values here are plain integers).

## Dimensions
- `item`: demographic component (population stock, live births, deaths, birth
  surplus, immigration, emigration, migration balance, naturalisations,
  adjustments, ...). The source's `change_abs` ("absolute change") row is dropped —
  it is the first difference of the population stock, a trivial and rarely-used
  derivative the user can read straight off the stock series.

## Labels
- dim: item
  - **label**: Demographic component
  - pop_stock_jan: Population on 1 January
  - live_births: Live births
  - deaths: Deaths
  - birth_surplus: Excess of births over deaths
  - immigration: Immigration
  - emigration: Emigration
  - migration_bal: Net migration
  - naturalisation: Acquisition of Swiss citizenship
  - adjustments: Adjustments
  - pop_stock_dec: Population on 31 December

## Display
- **split**: item
- **single-select**: 
- **default**: item=pop_stock_jan
- **transform**: level
- **seasonal adjustment**: n/a

The single `item` dimension is the breakdown a user compares as lines. The headline
default opens on the population stock on 1 January (`pop_stock_jan`), which spans the
full 1861-2024 history and is the natural headline for a resident-population series,
rather than the most-observations guess (`birth_surplus`). The flow components (births,
deaths, migration, naturalisations) are picked from the same list.

## Caveats / simplifications
- Per-cell drop of `...` means series have different start years; this is faithful
  to the source rather than padded.

## Provenance
Script: `R/source_fso_excel_sets.R::fso_excel_ch_fso_pop`. Datasheet 2026-06-01;
parser verified 2026-06-01 (1,395 rows, 11 series, 0 NA values).
