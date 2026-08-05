# Swiss stock indices

- **id**: ch_snb_capchstocki
- **title**: Swiss stock indices | de: Schweizer Aktienindizes | fr: Indices boursiers suisses | it: Indici azionari svizzeri
- **concept**: Financial markets / Swiss stock indices
- **canonical**: yes
- **featured**: Stock market
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: daily
- **coverage**: 1989-01-03 .. 2026-05-15
- **series**: 14
- **updated**: 2026-05-15 (latest observation)

## What is special
Daily levels of the Swiss equity market, the canonical stock-index series. It pairs
the two headline indices, the **SPI Swiss Performance Index** (total return, with
dividend reinvestment, code `GDR`) and the **SMI Swiss Market Index** (price index,
excluding dividend reinvestment, code `SMISMIDR`), with SPI sub-indices split two ways:
by **SIX** sector classification (`BA/FD/VS/NGT/GW`) and by **ICB** classification
(`B/F/V/NG/G`), so banks, financial services, insurance, food/beverages and health care
each appear under both schemes. Also `N` registered shares and `IPS` bearer
shares/participation certificates. Daily frequency back to 1989 for the headline SPI;
the sector sub-indices begin later (the CSV sample for SIX banks `B` starts 2000),
because SIX/ICB sector breakdowns were backfilled only from their introduction.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `capchstocki`
- **endpoint**: cube id `capchstocki`
- **call**: `snb_fetch("capchstocki", title = "Swiss stock indices")`, hitting
  `https://data.snb.ch/api/cube/capchstocki/dimensions/en` and `.../data/json/en`

## Parsing recipe
- Single dimension `D0`. One code per `timeseries` key; null observations skipped;
  dates already ISO and at daily granularity (trading days only, so gaps over weekends
  and holidays are expected, not missing data).
- Flatten labels and hierarchy. Long table keyed by `D0`, `date`, `value`. No SA toggle.

## Dimensions
- `D0` Overview: index level. Headline `GDR` (SPI total return) and `SMISMIDR` (SMI
  price). SIX sectors `BA` banks, `FD` financial services, `VS` insurance, `NGT`
  food/beverages/tobacco, `GW` health care. ICB sectors `B` banks, `F` financial
  services, `V` insurance, `NG` food and beverages, `G` health care. `N` registered
  shares, `IPS` bearer shares and participation certificates. Default `GDR`.
  Grouping nodes `D0_0` (SPI), `SIX`, `ICB` (`data:false`) carry no observations.

## Display
- **split**: D0
- **single-select**: (none; single dimension)
- **default**: D0=GDR
- **transform**: level
- **seasonal adjustment**: n/a (SNB daily index, no SA dimension)

## Caveats / simplifications
- The SIX and ICB sector breakdowns describe the same five economic sectors under two
  different classification standards; they are distinct series, kept under distinct
  codes, not deduplicated.
- Daily series, so absent dates are non-trading days, not data gaps.

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube `capchstocki`, topic
"Financial markets"). Datasheet authored 2026-06-01; parser verified 2026-06-01
(70,324 rows, 14 series).
