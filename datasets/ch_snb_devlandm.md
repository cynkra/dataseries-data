# Foreign exchange rates, by country – Month

- **id**: ch_snb_devlandm
- **concept**: Exchange rates / Bilateral FX
- **canonical**: yes
- **source**: Swiss National Bank (SNB)
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1973-01 .. 2018-03
- **series**: 93

## What is special
A **country-indexed, real-and-nominal** bilateral exchange-rate set: each partner is
published as both a **nominal** (N) and a **real** (R) CHF index. This is the only FX
cube in the group organised by country (with euro-area members listed individually,
e.g. Germany, France, Italy) and offering a real-terms view alongside the nominal.
The country dimension is a **deep three-level hierarchy** (Total, Total for 24
countries, then regional groups Europe -> Euro area -> member states, North America,
Central and South America, Asia, plus a flat Australia), with regional totals (T1,
T4, T5, T6) as data-bearing aggregate rows. The series is **discontinued**: it stops
in 2018-03, so it is a historical reference rather than a live feed. Note the SNB dim
codes reuse short letters (`D0` = Germany, `N` = Netherlands) that collide with the
generic `D0`/`N` dimension ids; the `metadata.key` order disambiguates them.

## Access
- **type**: SNB cube API
- **endpoint**: `https://data.snb.ch/api/cube/devlandm/data/json/en`
- **call**: `snb_fetch("devlandm", title = "Foreign exchange rates, by country – Month")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube `devlandm`.
- `metadata.key` `{...}` gives the `D0,D1` codes in order; one long row per non-null
  observation with `date` (ISO month start) and numeric `value`.
- Regional/grouping nodes that are non-data headers (`D1_2` Europe, `D1_2_1` Euro
  area, `D1_3`..`D1_5`) carry no key and appear only in `hierarchy`; data-bearing
  totals (`T0`, `T24L`, `T1`, `T4`, `T5`, `T6`) do produce rows.

## Dimensions
- `D0` Real/Nominal: `R` real, `N` nominal. Defaults to `N`.
- `D1` Country: ~46 partners plus aggregates. Codes are SNB-internal abbreviations
  (`USA`, `K` Canada, `J` Japan, `C` China, `D0` Germany, etc.); defaults to `D2`
  (Denmark).

## Display
- **split**: D1
- **single-select**: D0
- **default**: D1=T0, D0=R
- **transform**: level
- **seasonal adjustment**: n/a (SNB publishes no SA toggle for this cube)

## Caveats / simplifications
- Discontinued in 2018-03; not updated.
- SNB has no seasonal-adjustment toggle.
- Code letters overlap with dimension ids; rely on positional key parsing, not the
  raw letter.

## Provenance
Script: `R/source_snb.R::snb_fetch` (title/topic from `R/snb_cubes.tsv`). Datasheet
authored 2026-06-01.
