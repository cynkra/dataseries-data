# Money market rates

- **id**: ch_snb_zimoma
- **title**: Money market rates | de: Geldmarktsätze | fr: Taux du marché monétaire | it: Tassi del mercato monetario
- **concept**: Interest rates & yields / Money-market rates
- **canonical**: yes (the headline money-market-rate cube; `zikredlauf` and `zikrepro` are the lending/published-rate alternates under the same concept)
- **featured**: SARON
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1972-01 .. 2026-04
- **series**: 13
- **updated**: 2026-04 (latest published period)

## What is special
Money-market rates for Switzerland, the US, Japan, the UK and the euro area on one chart, spanning the switch from Libor to SARON and SOFR.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `zimoma`
- **endpoint**: `https://data.snb.ch/api/cube/zimoma/data/json/en`
- **call**: `snb_fetch("zimoma", title = "Money market rates")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en` for cube id `zimoma`.
- `metadata$key` `{...}` holds one code in `dim_order`; take it as the `D0` column.
- Per `values`: drop nulls, ISO date, numeric value. JSON+CSV only, no SA toggle.
- `D0` is a four-level country/currency/benchmark tree; keep only `data: true` leaves
  and drop the grouping nodes (`D0_0` Switzerland, `D0_0_0` CHF, `1DSARON`, ...).

## Dimensions
- `D0` (Overview): leaf benchmark series. Switzerland: `SARON` 1-day, `1TGT` call money
  (tomorrow-next), `EG3M` 3-month Confederation debt-register claims, `3M0` 3-month CHF
  LIBOR. US: `SOFR` 1-day, `3M1` 3-month USD LIBOR. Japan: `TONA` 1-day, `3M2` 3-month
  JPY LIBOR. UK: `SONIA` 1-day, `3M3` 3-month GBP LIBOR. Euro area: `ESTR` 1-day,
  `EURIBOR` 3-month, `3M4` 3-month EUR LIBOR.
- Default item: `D0=1TGT`.

## Display
- **split**: D0
- **single-select**: (none; this cube has a single dimension)
- **default**: D0=1TGT
- **transform**: level
- **seasonal adjustment**: n/a (this cube has no seasonal-adjustment dimension)

## Caveats / simplifications
- Mixed benchmark generations: overnight risk-free rates (SARON/SOFR/TONA/SONIA/ESTR)
  sit beside discontinued 3-month LIBOR panels; the LIBOR leaves stop at the cessation
  dates while the new benchmarks start later, so the series are unbalanced.
- The grouping labels (`D0_0` Switzerland, `1DSARON` SARON, etc.) are headings only and
  carry no observations.
- Only `1TGT` reaches back to 1972; foreign and modern-benchmark leaves are far shorter.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube list + title from `R/snb_cubes.tsv`).
Datasheet authored 2026-06-01; parser verified 2026-06-01 (4,741 data rows, 13 series).

## What is special (de)
Geldmarktsätze für die Schweiz, die USA, Japan, Grossbritannien und den Euroraum in einer Grafik, über den Wechsel von Libor zu SARON und SOFR hinweg.

## What is special (fr)
Taux du marché monétaire pour la Suisse, les États-Unis, le Japon, le Royaume-Uni et la zone euro sur un même graphique, à travers le passage du Libor au SARON et au SOFR.

## What is special (it)
Tassi del mercato monetario per Svizzera, Stati Uniti, Giappone, Regno Unito e area euro in un unico grafico, attraverso il passaggio da Libor a SARON e SOFR.
