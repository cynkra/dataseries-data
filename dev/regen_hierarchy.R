# One-off: rebuild the `hierarchy` of the affected datasets' JSON meta in place,
# WITHOUT re-fetching their data. The hierarchy depends only on the existing level
# codes (+ the datasheet `## Hierarchy` block), so we read data/<id>.json, run the
# same attach_hierarchy() the pipeline now uses, and write the JSON back. The CSV and
# Parquet are untouched (data is unchanged). CPI is the one exception — its tree comes
# from the source `Level` column, so it is rebuilt by a normal fetch via the pipeline,
# not here.
#
# Run: Rscript dev/regen_hierarchy.R
suppressPackageStartupMessages({ library(jsonlite) })
root <- "R"
source(file.path(root, "io.R"))
source(file.path(root, "hierarchy.R"))

DATA_DIR <- "data"
DATASHEET_DIR <- "datasets"

IDS <- c(
  "ch_seco_concon",
  "ch_fso_retail", "ch_fso_production", "ch_fso_services",
  "ch_fso_besta", "ch_fso_besta_outlook", "ch_fso_vacancies",
  "ch_fso_gfcf_detail", "ch_fso_hours_worked",
  "ch_ffa_finances", "ch_fso_trade_partner",
  "ch_snb_ausshawarm",  # reparent the SNB goods tree under GT Total (derive: under-root)
  "ch_snb_snbmonagg"    # override the flat SNB tree with the M1 ⊂ M2 ⊂ M3 nesting
)

# Re-emit JSON with the same key order / formatting write_dataset() uses.
write_meta_json <- function(meta, path) {
  writeLines(jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = "null"), path)
}

for (id in IDS) {
  f <- file.path(DATA_DIR, paste0(id, ".json"))
  meta <- jsonlite::fromJSON(f, simplifyVector = FALSE)
  ds <- list(id = id, meta = meta)
  ds <- attach_hierarchy(ds, DATASHEET_DIR)
  dim <- ds$meta$split
  h <- ds$meta$dimensions[[dim]]$hierarchy
  if (is.null(h)) { cat(sprintf("  %-24s NO hierarchy produced (check datasheet)\n", id)); next }
  n_tree <- length(tree_codes(h)); n_lvl <- length(ds$meta$dimensions[[dim]]$levels)
  write_meta_json(ds$meta, f)
  cat(sprintf("  %-24s dim=%-20s tree_nodes=%3d levels=%3d\n", id, dim, n_tree, n_lvl))
}
cat("done.\n")
