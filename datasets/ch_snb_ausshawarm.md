# Foreign trade by goods category

- **id**: ch_snb_ausshawarm
- **title**: Foreign trade by goods category | de: Aussenhandel nach Warengruppe | fr: Commerce extérieur par catégorie de marchandises | it: Commercio estero per categoria di merci
- **concept**: External sector / Foreign trade
- **canonical**: yes
- **featured**: Foreign trade
- **source**: snb
- **license**: snb (free reuse, attribution required)
- **frequency**: monthly
- **coverage**: 2012-01 .. 2026-03
- **series**: 175
- **updated**: 2026-03 (latest observation; PublishingDate in CSV header is the freshness signal)

## What is special
Switzerland's monthly foreign trade split by goods category, the canonical trade
series in the catalog. It is a three-way cube: trade flow (exports / imports /
balance) times a deep goods hierarchy times a value-or-change axis. The goods axis
goes two levels deep (e.g. group `CHEM` -> `C21` pharma preparations, `C20`
chemicals), which surfaces the pharma and watches drivers that dominate Swiss
exports (`C21`, `C2652`). The quirky axis is `D2` "Value/Change": the source nests a
level (`WMF` value in CHF millions) with two year-on-year %-change leaves (`N` nominal,
`R` real) under one dimension. The nominal change `N` is exactly the YoY % of `WMF`, so
it is dropped as redundant with the app's YoY toggle; the real change `R` (price-deflated,
not recomputable from the value) is kept. That leaves `D2` = {`WMF` nominal value, `R`
real change} — two genuinely different series, so the `value` column still means CHF
millions for `WMF` and a percent change for `R`. Despite a 2012 catalog start, the
CHF-million level rows begin 2012 while the %-change rows begin 2013 (a year of base
needed first).

## Access
- **type**: snb-cube — SNB cube API
- **cube**: `ausshawarm`
- **endpoint**: `GET https://data.snb.ch/api/cube/ausshawarm/data/json/en`
- **call**: `snb_fetch("ausshawarm", title = "Foreign trade by goods category")`

## Parsing recipe
- Fetch `/dimensions/en` and `/data/json/en`; map each `timeseries.metadata.key`
  `{...}` codes positionally onto dim ids `D0`,`D1`,`D2`.
- Recurse the nested `dimensionItems` to flatten code -> label and rebuild the
  goods hierarchy tree; grouping nodes (`data: false`, e.g. `CHEM`, `ME`, `MET`)
  carry no rows.
- Monthly dates are period starts; coerce to ISO `Date`.
- JSON+CSV only, no JSON-stat; no SA toggle.

## Dimensions
- `D0` (Overview): `A` exports, `E` imports, `H` trade surplus/deficit.
- `D1` (Goods category): `GT` total plus leaf goods codes nested under non-data
  groups, e.g. `C21` pharma preparations, `C20` chemicals, `C26` computer/optical,
  `C2652` watches and clocks, `C24/C25` metals, `C10..C12` food/beverages/tobacco,
  `C29/C30` vehicles, `B05/B06/C19/D35` energy, `C13..C15` textiles/apparel/leather.
- `D2` (Value/Change): `WMF` value in CHF millions (level) and `R` real YoY %-change,
  the latter under the non-data group `D2_1`. The nominal YoY %-change `N` is dropped
  (it equals the YoY of `WMF`, reproduced by the app's YoY toggle).

## Display
- **split**: D1
- **single-select**: D2
- **default**: D0=A, D1=GT, D2=WMF
- **transform**: level
- **seasonal adjustment**: n/a (no SA dimension or SA codes). D2 mixes a level
  (WMF, CHF millions) with the real YoY %-change leaf (R); the level WMF is the
  headline, so transform stays level rather than yoy. Pick R on D2 for the real
  change, or the YoY toggle on WMF for the nominal change.

## Hierarchy
SNB lists `GT Total` as a sibling of the goods groups; nest the groups (and the
ungrouped goods C2652/C22/C17) under Total so the picker reads Total → category →
product. The category nodes (CHEM, ME, MET, NFG, FZ, EN, TB) carry no series of their
own in the SNB cube — only `GT` and the individual goods are published — so they stay
non-selectable grouping headers, now correctly placed under Total.
- derive: under-root GT

## Caveats / simplifications
- Mixed semantics on `D2`: `WMF` is a CHF-million level, `R` is a real % change;
  do not aggregate across them. The redundant nominal change (`N`) is dropped — use
  the app's YoY toggle on `WMF` for it.
- Default preview series is `D0 = A`, `D1 = A01`, `D2 = WMF`.

## Provenance
Script: `R/source_snb.R::snb_fetch` via `R/snb_cubes.tsv` (cube_id `ausshawarm`).
Datasheet 2026-06-01; parser verified 2026-06-01 (28,285 rows, 175 series).

## What is special (de)
Der monatliche Schweizer Aussenhandel nach Warengruppe, die kanonische
Handelsreihe im Katalog. Es ist ein dreifach gegliederter Würfel: Handelsrichtung
(Export / Import / Saldo) mal einer tiefen Warenhierarchie mal einer
Wert-oder-Veränderungs-Achse. Die Warenachse geht zwei Stufen tief (z. B. Gruppe
`CHEM` -> `C21` pharmazeutische Erzeugnisse, `C20` Chemikalien) und macht damit die
Pharma- und Uhrentreiber sichtbar, die den Schweizer Export dominieren (`C21`,
`C2652`). Die eigenwillige Achse ist `D2` «Wert/Veränderung»: Die Quelle stellt
eine Niveaustufe (`WMF` Wert in Mio. CHF) mit zwei Vorjahresveränderungs-Blättern
(`N` nominal, `R` real) unter eine Dimension. Die nominale Veränderung `N` ist
exakt die Vorjahresveränderung von `WMF` und wird daher als redundant zum
YoY-Umschalter der App weggelassen; die reale Veränderung `R` (preisbereinigt,
nicht aus dem Wert rekonstruierbar) bleibt erhalten. Damit gilt `D2` = {`WMF`
Nominalwert, `R` reale Veränderung} — zwei tatsächlich verschiedene Reihen, sodass
die Spalte `value` für `WMF` weiterhin Mio. CHF und für `R` eine prozentuale
Veränderung bedeutet. Trotz Katalogbeginn 2012 setzen die Mio.-CHF-Niveauzeilen
2012 ein, die Veränderungszeilen erst 2013 (ein Basisjahr wird zuerst benötigt).

## What is special (fr)
Le commerce extérieur mensuel de la Suisse par catégorie de marchandises, la
série commerciale de référence du catalogue. C'est un cube à trois entrées : le
flux commercial (exportations / importations / solde) croisé avec une hiérarchie
détaillée de marchandises et avec un axe valeur-ou-variation. L'axe des
marchandises descend de deux niveaux (p. ex. groupe `CHEM` -> `C21` préparations
pharmaceutiques, `C20` produits chimiques), ce qui fait apparaître les moteurs
pharma et horlogers qui dominent les exportations suisses (`C21`, `C2652`). L'axe
particulier est `D2` « Valeur/Variation » : la source place un niveau (`WMF`
valeur en millions de CHF) et deux feuilles de variation sur un an (`N` nominale,
`R` réelle) sous une même dimension. La variation nominale `N` est exactement la
variation sur un an de `WMF` ; elle est donc écartée comme redondante avec le
bouton de variation annuelle de l'application, tandis que la variation réelle `R`
(déflatée, non recalculable à partir de la valeur) est conservée. Il reste donc
`D2` = {`WMF` valeur nominale, `R` variation réelle} — deux séries réellement
différentes, si bien que la colonne `value` signifie encore des millions de CHF
pour `WMF` et une variation en pour-cent pour `R`. Malgré un début de catalogue en
2012, les lignes de niveau en millions de CHF commencent en 2012 et les lignes de
variation seulement en 2013 (il faut d'abord une année de base).

## What is special (it)
Il commercio estero mensile della Svizzera per categoria di merci, la serie
commerciale di riferimento del catalogo. È un cubo a tre entrate: il flusso
commerciale (esportazioni / importazioni / saldo) incrociato con una gerarchia
dettagliata di merci e con un asse valore-o-variazione. L'asse delle merci scende
di due livelli (p. es. gruppo `CHEM` -> `C21` preparati farmaceutici, `C20`
prodotti chimici), facendo emergere i motori farmaceutico e orologiero che
dominano le esportazioni svizzere (`C21`, `C2652`). L'asse particolare è `D2`
«Valore/Variazione»: la fonte colloca un livello (`WMF` valore in milioni di CHF)
e due foglie di variazione annua (`N` nominale, `R` reale) sotto un'unica
dimensione. La variazione nominale `N` è esattamente la variazione annua di
`WMF`, quindi viene esclusa perché ridondante con il pulsante di variazione annua
dell'applicazione; la variazione reale `R` (deflazionata, non ricalcolabile dal
valore) è mantenuta. Resta quindi `D2` = {`WMF` valore nominale, `R` variazione
reale} — due serie realmente diverse, per cui la colonna `value` significa ancora
milioni di CHF per `WMF` e una variazione percentuale per `R`. Nonostante l'inizio
del catalogo nel 2012, le righe di livello in milioni di CHF partono dal 2012 e
quelle di variazione solo dal 2013 (serve prima un anno di base).
