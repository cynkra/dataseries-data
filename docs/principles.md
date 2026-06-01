# Curation principles

These are the general principles behind the dataseries catalog. The concrete
taxonomy they produce — every concept, its canonical dataset, and its alternates —
lives in [`concepts.md`](concepts.md). The per-dataset reality lives in each
datasheet (`datasets/<id>.md`). This document explains the *why*.

## Datasheets are the source of truth; scripts are derived

The markdown datasheet for a dataset (`datasets/<id>.md`) is authoritative. It
records, in human- and AI-readable prose, everything needed to understand and
re-fetch the dataset: where it comes from, the exact access recipe, what each
dimension means, the parsing quirks, and the presentation decisions.

The fetch/parse scripts in `R/` are a **derivative** of the datasheets. Given a
datasheet, the corresponding fetcher can be regenerated. The institutional knowledge
lives in the prose so it survives even if the code rots or the source changes. When a
source changes, update the datasheet first, then regenerate the script from it.

Any **special treatment** must be documented in the datasheet — never left implicit
in the script. This includes: dropping a series, reattributing a source,
reformatting or reshaping, a non-obvious parse, a row or column that must be skipped,
a date encoding that needs decoding, a single dimension chunked across several API
calls. If a maintainer would be surprised by it, it belongs in the datasheet.

## Headline-first

A dataset opens on its **main series** — the root of its hierarchy — and the user
drills down from there. The opening view (the `## Display` block's `default`) is the
intuitive headline: the total, not an arbitrary sub-component. The detail is one
click away, not the landing state.

## No redundant overview datasets

Do **not** create a separate "summary" or "overview" dataset when its headline is
already the root of a detailed dataset — the detailed dataset's headline-first view
already serves as the overview.

The exception: keep an overview cube when it carries **unique aggregates the detail
cubes lack**. For example `ch_snb_bopoverq` is kept because it holds the capital
account and the statistical difference that the balance-of-payments detail cubes do
not, and `ch_snb_auvekomq` is kept for its deep international-investment-position
functional tree. An overview cube earns its place only by adding data, not by
re-presenting data already available in detail elsewhere.

## Attribute to the true producer

A dataset is attributed to the institution that **produces** it, not the channel that
**redistributes** it. Consumer confidence is SECO's even when we fetch it through the
SNB cube API; we relabel it to SECO. Where two offices both publish a concept, prefer
the **primary statistical office** as canonical (GDP → SECO; CPI / prices / wages /
labour / tourism / population → FSO; money / rates / FX / balance of payments /
banking / payments → SNB; the leading barometer → KOF).

## One canonical dataset per concept

Each concept resolves to exactly one canonical dataset (`canonical: true`). Genuine
alternates — a different *definition* of the concept, not a format re-export — are
kept and marked `canonical: false`, with the difference stated in the title (e.g.
registered vs ILO unemployment, headline vs core inflation). Pure format
re-exports and native-frequency roll-ups are dropped, not kept as alternates. See
[`concepts.md`](concepts.md) for the full canonical/alternate/dropped ledger.

## Storage formats

The data product ships in three artifact types per dataset, but only two of them are
the source of truth:

- **CSV (`<id>.csv`) — source of truth, committed.** The readable product. It is
  committed to git, so every revision is diffable and the change history is free.
  This is the canonical data.
- **JSON meta (`<id>.json`) — source of truth, committed.** The metadata sidecar
  (multilingual title/source, units, dimension labels, hierarchy, license, coverage,
  the `## Display` decisions). Committed alongside the CSV.
- **Parquet (`<id>.parquet`) — derived query cache, NOT committed.** A query-engine
  cache built from the CSV at deploy / sync time and consumed by the DuckDB serving
  layer. It is a derivative, never the source of truth, and is not committed to git.

The contract in [`format-contract.md`](format-contract.md) describes the file shapes;
this rule says which of them is authoritative.
