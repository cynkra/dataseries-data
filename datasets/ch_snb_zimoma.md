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
The core money-market reference rates, monthly back to 1972. The distinctive feature is
the country grouping (`D0`): Switzerland alongside the US, Japan, the UK and the euro
area, so the same cube lets you compare CHF rates against the major currencies on one
axis. It also spans the reference-rate transition end to end: the modern overnight
benchmarks SARON, SOFR, TONA, SONIA and ESTR sit next to the legacy 3-month LIBOR
series and EURIBOR. The Swiss block additionally carries the call money rate
(tomorrow-next) and the 3-month money-market debt-register claims of the Confederation.
With only 13 leaf series it is small but conceptually wide, and the Swiss `1TGT` series
gives the longest continuous CHF money-market history in the cube (from 1972).

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
Die zentralen Referenzzinssätze des Geldmarkts, monatlich zurück bis 1972. Das
prägende Merkmal ist die Ländergruppierung (`D0`): die Schweiz neben den USA,
Japan, dem Vereinigten Königreich und dem Euroraum, sodass sich Frankensätze im
selben Würfel auf einer Achse mit den grossen Währungen vergleichen lassen. Der
Würfel deckt zudem den Übergang der Referenzzinssätze lückenlos ab: Die modernen
Tagesgeld-Benchmarks SARON, SOFR, TONA, SONIA und ESTR stehen neben den früheren
3-Monats-LIBOR-Reihen und dem EURIBOR. Der Schweizer Block enthält zusätzlich den
Tagesgeldsatz (Tom-Next) und die 3-monatigen Geldmarktbuchforderungen des Bundes.
Mit nur 13 Blattreihen ist er klein, aber konzeptionell breit; die Schweizer Reihe
`1TGT` liefert die längste durchgehende Frankengeldmarkt-Historie im Würfel (ab
1972).

## What is special (fr)
Les taux de référence du marché monétaire, mensuels depuis 1972. Sa
caractéristique distinctive est le regroupement par pays (`D0`) : la Suisse aux
côtés des États-Unis, du Japon, du Royaume-Uni et de la zone euro, de sorte qu'un
même cube permet de comparer les taux du franc aux grandes devises sur un seul axe.
Il couvre aussi la transition des taux de référence de bout en bout : les
références au jour le jour modernes SARON, SOFR, TONA, SONIA et ESTR côtoient les
anciennes séries LIBOR à 3 mois et l'EURIBOR. Le bloc suisse porte en outre le taux
de l'argent au jour le jour (tom-next) et les créances comptables à 3 mois de la
Confédération sur le marché monétaire. Avec seulement 13 séries terminales, il est
petit mais conceptuellement large, et la série suisse `1TGT` offre le plus long
historique continu du marché monétaire en francs du cube (depuis 1972).

## What is special (it)
I tassi di riferimento del mercato monetario, mensili a partire dal 1972. Il
tratto distintivo è il raggruppamento per paese (`D0`): la Svizzera accanto a Stati
Uniti, Giappone, Regno Unito e area euro, così che lo stesso cubo consente di
confrontare i tassi del franco con le principali valute su un unico asse. Copre
inoltre per intero la transizione dei tassi di riferimento: i moderni benchmark
overnight SARON, SOFR, TONA, SONIA ed ESTR affiancano le precedenti serie LIBOR a
3 mesi e l'EURIBOR. Il blocco svizzero riporta anche il tasso del denaro a un
giorno (tom-next) e i crediti contabili a 3 mesi della Confederazione sul mercato
monetario. Con sole 13 serie terminali è piccolo ma concettualmente ampio, e la
serie svizzera `1TGT` offre la più lunga storia continua del mercato monetario in
franchi presente nel cubo (dal 1972).
