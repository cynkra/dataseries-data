# Monetary aggregates M1, M2 and M3

- **id**: ch_snb_snbmonagg
- **title**: Monetary aggregates (M1–M3) | de: Geldmengen (M1–M3) | fr: Agrégats monétaires (M1–M3) | it: Aggregati monetari (M1–M3)
- **concept**: Money & banking / Monetary aggregates
- **canonical**: yes
- **featured**: Money supply
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 1984-12 .. 2026-04
- **series**: 16
- **updated**: 2026-04 (use API PublishingDate header for exact day)

## What is special
The headline Swiss monetary aggregates, monthly from 1984. This is the canonical
money-supply series. The source cube has two dimensions — `D0` level vs year-on-year
change, `D1` the component or aggregate — but `D0` is dropped: its `VV` (year-on-year
change) level is exactly the app's YoY % transform, derived from the `B` level, so
keeping only `B` collapses `D0` away and leaves `D1` as the single dimension. The
components nest into the aggregates by construction:
currency in circulation + sight deposits + deposits in transaction accounts ->
**M1**; M1 + savings deposits -> **M2**; M2 + time deposits -> **M3**. So the cube
ships the building blocks (`B`, `S0`, `ET`, `S1`, `T`) and the three totals
(`GM1`, `GM2`, `GM3`) side by side as CHF-million levels — 8 stored series. Compared
with `snbmoba` (base money, the central bank's own liabilities), these aggregates
measure money held by the public, which is why this is the canonical aggregate and
the base is the alternate.

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `snbmonagg`
- **endpoint**: `https://data.snb.ch/api/cube/snbmonagg/data/json/en`
- **call**: `snb_fetch("snbmonagg", title = "Monetary aggregates M1, M2 and M3")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`.
- `metadata.key` is `EPB@SNB.snbmonagg{<D0>,<D1>}`; the two codes in `{...}` map to
  `D0,D1` in order. Long tibble of `D0,D1,date,value`. Dates -> first of month.
  Drop null values. Sort by `D0,D1,date`.
- `D0=B` rows are CHF-million levels; `D0=VV` rows are percentage changes vs the
  same month a year earlier. We keep only `D0=B` and drop `D0=VV` (the app's YoY %
  toggle reproduces it), then drop the now single-valued `D0` column.

## Dimensions
- `D1` (Monetary aggregates): components `B` currency in circulation, `S0` sight
  deposits, `ET` deposits in transaction accounts, `S1` savings deposits, `T` time
  deposits; aggregates `GM1` M1, `GM2` M2, `GM3` M3. (The dropped `D0` dimension
  separated level from year-on-year change; only the level is kept — see above.)

## Display
- **split**: D1
- **single-select**:
- **default**: D1=GM3
- **transform**: level
- **seasonal adjustment**: n/a (no seasonal-adjustment dimension). Opens on the
  broadest aggregate M3 (`D1=GM3`) as a CHF-million level; use the app's YoY %
  toggle for the growth-rate view.

## Hierarchy
SNB ships `D1` flat (all eight items as siblings), but the aggregates nest
cumulatively: M1 ⊂ M2 ⊂ M3. M1 (`GM1`) = currency in circulation (`B`) + sight
deposits (`S0`) + transaction-account deposits (`ET`); M2 (`GM2`) = M1 + savings
deposits (`S1`); M3 (`GM3`) = M2 + time deposits (`T`). We declare that nesting so the
picker shows each broader aggregate as the parent of the narrower one plus its
increment (every node is a published series, so all are selectable). Source: SNB
definitions of the money supply (European standard).
- GM3
  - GM2
    - GM1
      - B
      - S0
      - ET
    - S1
  - T

## Caveats / simplifications
- After dropping `D0`, the code `B` is unambiguous: it now only appears in `D1`
  ("currency in circulation"). (In the source it doubled as the `D0` "level" code.)
- Aggregates and their components are both present, so naive sums over `D1` would
  double count. The aggregation is definitional (M1 < M2 < M3), captured in the
  `D1` labels, not in a separate flag.

## Provenance
Script: `R/source_snb.R::snb_fetch` (cube `snbmonagg`, title from
`R/snb_cubes.tsv`, topic "Money and banking"). Datasheet authored 2026-06-01.

## What is special (de)
Die zentralen Schweizer Geldmengenaggregate, monatlich ab 1984. Dies ist die
kanonische Geldmengenreihe. Der Quellwürfel hat zwei Dimensionen — `D0` Niveau
gegenüber Vorjahresveränderung, `D1` die Komponente oder das Aggregat —, doch `D0`
wird weggelassen: Seine Stufe `VV` (Vorjahresveränderung) ist exakt die
YoY-%-Transformation der App, abgeleitet aus der Niveaustufe `B`. Behält man nur
`B`, fällt `D0` weg und `D1` bleibt als einzige Dimension. Die Komponenten sind
konstruktionsbedingt in den Aggregaten enthalten: Bargeldumlauf + Sichteinlagen +
Einlagen in Transaktionskonten -> **M1**; M1 + Spareinlagen -> **M2**; M2 +
Termineinlagen -> **M3**. Der Würfel liefert somit die Bausteine (`B`, `S0`, `ET`,
`S1`, `T`) und die drei Totale (`GM1`, `GM2`, `GM3`) nebeneinander als Niveaus in
Mio. CHF — 8 gespeicherte Reihen. Im Vergleich zu `snbmoba` (Notenbankgeldmenge,
den eigenen Verbindlichkeiten der Zentralbank) messen diese Aggregate das vom
Publikum gehaltene Geld; deshalb ist dies das kanonische Aggregat und die
Notenbankgeldmenge die Alternative.

## What is special (fr)
Les agrégats monétaires suisses de référence, mensuels depuis 1984. C'est la série
canonique de la masse monétaire. Le cube source a deux dimensions — `D0` niveau
contre variation sur un an, `D1` la composante ou l'agrégat — mais `D0` est écartée :
son niveau `VV` (variation sur un an) est exactement la transformation annuelle de
l'application, dérivée du niveau `B`. En ne gardant que `B`, `D0` disparaît et `D1`
reste la seule dimension. Les composantes s'emboîtent dans les agrégats par
construction : monnaie en circulation + dépôts à vue + dépôts en comptes de
transaction -> **M1** ; M1 + dépôts d'épargne -> **M2** ; M2 + dépôts à terme ->
**M3**. Le cube livre donc les briques (`B`, `S0`, `ET`, `S1`, `T`) et les trois
totaux (`GM1`, `GM2`, `GM3`) côte à côte, en niveaux de millions de CHF — 8 séries
stockées. Par rapport à `snbmoba` (monnaie centrale, les engagements propres de la
banque centrale), ces agrégats mesurent la monnaie détenue par le public : c'est
pourquoi celui-ci est l'agrégat canonique et la monnaie centrale l'alternative.

## What is special (it)
Gli aggregati monetari svizzeri di riferimento, mensili dal 1984. È la serie
canonica della massa monetaria. Il cubo di origine ha due dimensioni — `D0` livello
contro variazione annua, `D1` la componente o l'aggregato — ma `D0` viene esclusa:
il suo livello `VV` (variazione annua) è esattamente la trasformazione annua
dell'applicazione, derivata dal livello `B`. Mantenendo solo `B`, `D0` decade e `D1`
resta l'unica dimensione. Le componenti confluiscono negli aggregati per
costruzione: circolante + depositi a vista + depositi in conti di transazione ->
**M1**; M1 + depositi a risparmio -> **M2**; M2 + depositi a termine -> **M3**. Il
cubo fornisce quindi i mattoni (`B`, `S0`, `ET`, `S1`, `T`) e i tre totali (`GM1`,
`GM2`, `GM3`) affiancati come livelli in milioni di CHF — 8 serie memorizzate.
Rispetto a `snbmoba` (base monetaria, gli impegni propri della banca centrale),
questi aggregati misurano la moneta detenuta dal pubblico: per questo è l'aggregato
canonico e la base monetaria l'alternativa.
