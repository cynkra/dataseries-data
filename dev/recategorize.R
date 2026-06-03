#!/usr/bin/env Rscript
# recategorize.R — apply the 2026-06 catalog re-categorisation:
#   * consolidate the concept Groups down to 12 categories (each >= 2 datasets)
#   * one curated highlight per category via `featured` (replaces the noisy ALT badge)
#   * unemployment headline flipped to the registered/SECO series
#
# It rewrites the affected datasheets (source of truth), then regenerates each
# data/<id>.json meta sidecar and data/catalog.json FROM DISK (no refetch), and
# rebuilds CATALOG.md. Idempotent: safe to re-run.
#
# Run from repo root: Rscript dev/recategorize.R

suppressWarnings(suppressMessages(library(jsonlite)))

root <- normalizePath(file.path(dirname(sub("--file=", "",
  grep("--file=", commandArgs(FALSE), value = TRUE)[1])), ".."))
DATASHEET_DIR <- file.path(root, "datasets")
DATA_DIR      <- file.path(root, "data")
source(file.path(root, "R", "io.R"))   # read_datasheet_meta(), %||%

# ---- the decisions -------------------------------------------------------

# id -> new "Group / Leaf" concept (only the moved/renamed ones)
concept_override <- list(
  ch_kof_esi              = "Business cycle & sentiment / Sentiment composite",
  ch_seco_wwa             = "Business cycle & sentiment / High-frequency activity tracker",
  ch_fso_hours_worked     = "Labour / Working time and working volume",
  ch_fso_hesta            = "Domestic economy / Hotel overnight stays",
  ch_fso_new_vehicles     = "Domestic economy / New vehicle registrations",
  ch_fso_vacant_dwellings = "Domestic economy / Vacant dwellings",
  ch_snb_snbiprogq        = "Prices / Inflation forecast",
  ch_ffa_finances         = "National accounts / Government finance",
  ch_fso_pop_detail       = "Population & demographics / Resident population by nationality"
)

# id -> new canonical field text (the headline-unemployment flip)
canonical_override <- list(
  ch_snb_amarbma   = "yes (registered/SECO definition — the headline unemployment series; the ILO `ch_fso_unemp_rate` is the labelled alternate)",
  ch_fso_unemp_rate = "no (alternate — ILO definition; the registered/SECO `ch_snb_amarbma` is canonical)"
)

# id -> short highlight chip label (one per category; Labour carries two)
featured_set <- list(
  ch_seco_gdp        = "GDP",
  ch_snb_plkopr      = "Inflation",
  ch_fso_besta       = "Employment",
  ch_snb_amarbma     = "Unemployment",
  ch_seco_concon     = "Consumer confidence",
  ch_snb_zimoma      = "SARON",
  ch_snb_devkum      = "Exchange rates",
  ch_snb_capchstocki = "Stock market",
  ch_snb_ausshawarm  = "Foreign trade",
  ch_snb_snbmonagg   = "Money supply",
  ch_fso_retail      = "Retail trade",
  ch_fso_pop         = "Population"
)
# datasets that lose their old highlight
featured_remove <- c("ch_kof_barometer", "ch_snb_snboffzisa", "ch_fso_hesta")

# ---- datasheet rewriting -------------------------------------------------

sheet_path <- function(id) file.path(DATASHEET_DIR, paste0(id, ".md"))

set_field <- function(lines, key, value) {
  pat <- sprintf("^- \\*\\*%s\\*\\*:", key)
  hit <- grep(pat, lines)
  newline <- sprintf("- **%s**: %s", key, value)
  if (length(hit)) { lines[hit[1]] <- newline; return(lines) }
  # insert after canonical, else after concept, else after the id line
  anchor <- grep("^- \\*\\*canonical\\*\\*:", lines)
  if (!length(anchor)) anchor <- grep("^- \\*\\*concept\\*\\*:", lines)
  if (!length(anchor)) anchor <- grep("^- \\*\\*id\\*\\*:", lines)
  i <- anchor[1]
  append(lines, newline, after = i)
}
drop_field <- function(lines, key) {
  pat <- sprintf("^- \\*\\*%s\\*\\*:", key)
  hit <- grep(pat, lines)
  if (length(hit)) lines[-hit[1]] else lines
}

edit_sheet <- function(id, fn) {
  f <- sheet_path(id)
  if (!file.exists(f)) { warning("no datasheet: ", id); return(invisible()) }
  lines <- readLines(f, warn = FALSE)
  lines <- fn(lines)
  writeLines(lines, f)
}

for (id in names(concept_override))
  edit_sheet(id, function(l) set_field(l, "concept", concept_override[[id]]))
for (id in names(canonical_override))
  edit_sheet(id, function(l) set_field(l, "canonical", canonical_override[[id]]))
for (id in names(featured_set))
  edit_sheet(id, function(l) set_field(l, "featured", featured_set[[id]]))
for (id in featured_remove)
  edit_sheet(id, function(l) drop_field(l, "featured"))

cat(sprintf("datasheets: %d concept, %d canonical, %d featured set, %d featured removed\n",
            length(concept_override), length(canonical_override),
            length(featured_set), length(featured_remove)))

# ---- regenerate sidecars + catalog.json from disk (no refetch) -----------

# Overlay the datasheet-derived fields (concept, canonical, featured, topic) onto
# each existing meta sidecar and the existing catalog row. Everything else
# (n_series, start/end, source, fetched, ...) is preserved verbatim.
# concept/canonical/topic are always present in the datasheet -> fall back to the
# existing value. `featured` is removable: take the datasheet value verbatim, so a
# dropped highlight becomes null instead of keeping the stale cached label.
keep_keys <- c("concept", "canonical", "topic")

ids <- sub("\\.md$", "", list.files(DATASHEET_DIR, pattern = "^ch_.*\\.md$"))
for (id in ids) {
  dm <- read_datasheet_meta(id, DATASHEET_DIR)
  sc <- file.path(DATA_DIR, paste0(id, ".json"))
  if (file.exists(sc)) {
    meta <- fromJSON(sc, simplifyVector = FALSE)
    for (k in keep_keys) meta[[k]] <- dm[[k]] %||% meta[[k]]
    meta[["featured"]] <- dm[["featured"]]   # NULL -> field removed (= not featured)
    writeLines(toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = "null"), sc)
  }
}

cat_rows <- fromJSON(file.path(DATA_DIR, "catalog.json"), simplifyVector = FALSE)
for (i in seq_along(cat_rows)) {
  id <- cat_rows[[i]]$id
  dm <- read_datasheet_meta(id, DATASHEET_DIR)
  for (k in keep_keys) if (!is.null(dm[[k]])) cat_rows[[i]][[k]] <- dm[[k]]
  cat_rows[[i]][["featured"]] <- dm[["featured"]] %||% NA   # NA -> null in JSON
}
writeLines(toJSON(cat_rows, auto_unbox = TRUE, pretty = TRUE, null = "null"),
           file.path(DATA_DIR, "catalog.json"))
cat(sprintf("rebuilt %d sidecars + catalog.json (%d rows)\n", length(ids), length(cat_rows)))

# ---- category summary ----------------------------------------------------
grp <- vapply(cat_rows, function(r) trimws(strsplit(r$concept %||% "?/?", "/", fixed = TRUE)[[1]][1]), "")
feat <- vapply(cat_rows, function(r) (r$featured %||% "") != "", logical(1))
cat("\nCategories (n datasets, highlight count):\n")
for (g in names(sort(table(grp), decreasing = TRUE)))
  cat(sprintf("  %-28s %2d  (highlights: %d)\n", g, sum(grp == g), sum(grp == g & feat)))
cat(sprintf("\nTotal datasets: %d | highlights: %d | categories: %d\n",
            length(cat_rows), sum(feat), length(unique(grp))))
