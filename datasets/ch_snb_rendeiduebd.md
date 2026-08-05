# Spot interest rates on Confederation, euro area and CHF issuer bonds (daily)

- **id**: ch_snb_rendeiduebd
- **title**: Bond yields (spot rates) | de: Obligationenrenditen (Kassazinssätze) | fr: Rendements obligataires (taux au comptant) | it: Rendimenti obbligazionari (tassi a pronti)
- **concept**: Interest rates & yields / Bond yields
- **canonical**: yes (the live Bond yields series; the older `rendoblid` par-yield cube was discontinued by the SNB — last data 2025-07-31)
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: daily
- **coverage**: 1988-01-04 .. 2026-04-30
- **series**: 48
- **updated**: 2026-04-30

## What is special
This is the SNB spot-rate (zero-coupon yield) cube and the **canonical Bond yields
series** for the catalog. Its `CHF × 10J` cell is the live 10-year Swiss
Confederation benchmark — the most-watched Swiss long rate (the default view). It is
live and current (daily, updated within days), unlike the older par-yield cube
`rendoblid`, which the SNB **discontinued** (last observation 2025-07-31); that cube's
content is fully covered here by the CHF curve, so it is not ingested. It crosses two
dimensions: a bond category and a maturity, giving a full **term structure** rather
than a single benchmark. The maturity dimension runs 1J through 10J plus 20J and 30J,
so you can read an entire spot curve for one day.
The category dimension splits into two branches: a market branch (CHF Swiss
Confederation issues, EUR euro-area government bonds) and a Swiss issuer-rating
branch (cantons by rating tier, mortgage-bond institutions, commercial banks by
rating, manufacturing/trade by rating). That issuer-by-rating breakdown is the
distinctive part: it lets you see the credit spread of, say, AA cantons or A-rated
banks over the Confederation curve. Daily since 1988, so it carries the long
Swiss-franc rate history including the negative-rate years.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `rendeiduebd`
- **endpoint**: `https://data.snb.ch/api/cube/rendeiduebd/data/json/en`
- **call**: `snb_fetch("rendeiduebd")` (cube_id = id minus `ch_snb_` prefix)

## Parsing recipe
- Fetch two documents per cube: `/dimensions/en` (code -> label and the nested
  hierarchy) and `/data/json/en` (the observations).
- Each timeseries' `metadata.key` (e.g. `...{CHF,10J}`) carries the dimension-item
  codes in `dim_order` (D0, D1). Split the `{...}` payload on commas to recover the
  per-series codes; pair positionally with `dim_order`.
- Emit one long row per observation: `D0, D1, date, value`. `date` is ISO from the
  obs `date`; `value` numeric.
- Drop grouping nodes (`data: false`, e.g. `D0_0`, `D1_1`): they are headers in the
  hierarchy, not data-bearing leaves.
- No seasonal-adjustment toggle exists on SNB cubes. The API emits JSON+CSV only
  (no JSON-stat). The live CSV header's `PublishingDate` is the freshness signal.

## Dimensions
- `D0` (Bond categories): `CHF` Confederation, `EUR` euro-area government; then the
  CHF-issuer-by-rating tree: `KTA`/`KTB` cantons (AAA/AA+ vs AA/AA-), `PFI` mortgage
  bond institutions, `GBA`/`GBB`/`GBC` commercial banks by rating tier,
  `IHA`/`IHB` manufacturing (incl. power plants) and trade by rating tier.
- `D1` (Maturity): `1J`..`10J` (1 to 10 years), plus `20J`, `30J`. Suffix `J` =
  Jahre (years). Default view is `CHF` x `10J`.

## Display
- **split**: D0
- **default**: D0=CHF, D1=10J
- **transform**: level
- **seasonal adjustment**: n/a (SNB cube has no SA dimension)

## Caveats / simplifications
- Not every category x maturity cell is populated; the 48 stored series are the
  combinations the SNB actually publishes (e.g. issuer-rating categories cover a
  narrower maturity set than the CHF/EUR benchmarks).
- These are spot (zero-coupon) rates. The SNB's older par-yield cube `rendoblid` was
  a different yield concept but is now discontinued (frozen at 2025-07-31); we ingest
  only this live cube.

## Provenance
Script: `R/source_snb.R::snb_fetch`, cube discovered via `R/snb_cubes.tsv`
(`rendeiduebd`, topic "Interest rates"). Datasheet authored 2026-06-01; parser
verified 2026-06-01 (184,434 rows, 48 series).
