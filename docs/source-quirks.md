# Source quirks

Per-source data quirks worth knowing when writing or refining the fetchers.
Several were learned the hard way by the **old swissdata repo**; read that code
only for these factual quirks, not as a design or code-quality reference. Our
pipeline (Python/Polars → tidy long CSV + JSON meta + `catalog.json`) is the
canonical approach.

## SNB (cube API)
- **Redundant TOTAL rows.** Cubes carry hierarchy-parent / total rows (e.g.
  `D1 == "T0"`, and `TMA`/`TTR`/`TFIIN` parents). If kept, they inflate
  `n_series` and double-count. Filter total/parent codes out of the data (or
  flag them explicitly).
- **Labels can be weak — keep an override hook.** The old swissdata repo had to
  hand-override `D0` labels for flagship series. In the 2026 pull the API
  returns usable `D0` labels, but keep an override hook in case it regresses.
- **Rename opaque dim columns.** Cubes arrive with opaque `D0`/`D1` headers. The
  JSON meta carries the dimension label so the website can resolve it, but a
  downloaded CSV has meaningless headers — rename to semantic names from the
  dimension `name`.
- **Shape matches the swissdata format**, so the SNB approach is sound.

## FSO
- We read FSO via the **JSON-stat2 API** (clean, no extra dependency) rather than
  the old swissdata repo's binary `.px` + R `pxR` route. JSON-stat2 parses
  cleanly and year+month recombine into one ISO first-of-period date.
- **Drop single-value dimension columns.** A dimension filtered to one value
  (e.g. `Indikator`) adds a constant, noise-only column.
- **German dimension codes as headers** (e.g. `Tourismusregion`): decide whether
  to keep the code or map to a semantic english slug. Labels are already in the
  meta either way.

## Meta gaps to fill where the source allows
- **`updated`** — capture the source publish date (SNB `PublishingDate` in the
  CSV header; KOF and FSO carry their own).
- **`units`** — missing for SNB (packed oddly) and FSO; extract where available.
- **`topic`** — populate from a controlled per-dataset vocabulary.

## Cross-source
- Date normalization spans dialects: SNB `1990-Q1` → `1990-04-01`, monthly
  `1991-01` → `1991-01-01`, all ISO first-of-period.
- A single-series source (e.g. KOF) yields zero dimension columns — just
  `date,value`. That is correct, not a bug.
