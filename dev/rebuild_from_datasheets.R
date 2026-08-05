#!/usr/bin/env Rscript
# rebuild_from_datasheets.R — re-derive every datasheet-controlled field onto the
# meta sidecars (data/<id>.json) and data/catalog.json FROM DISK, no refetch. Run
# this after editing datasheets (title, concept, canonical, featured, default,
# split, transform, a `## Hierarchy` tree, …) to propagate the change to what the
# API serves.
#
# Datasheets are the source of truth; this just refreshes the generated caches.
# Idempotent. Run from repo root: Rscript dev/rebuild_from_datasheets.R

suppressWarnings(suppressMessages(library(jsonlite)))
root <- normalizePath(file.path(dirname(sub("--file=", "",
  grep("--file=", commandArgs(FALSE), value = TRUE)[1])), ".."))
DATASHEET_DIR <- file.path(root, "datasets")
DATA_DIR      <- file.path(root, "data")
source(file.path(root, "R", "datasheet.R"))   # ds_read(), ds_i18n(), %||%
source(file.path(root, "R", "io.R"))          # read_datasheet_meta()
source(file.path(root, "R", "labels.R"))      # attach_labels()
source(file.path(root, "R", "hierarchy.R"))   # attach_hierarchy()

# Fields the catalog row carries (the rest of the datasheet meta lives only in the
# per-dataset sidecar, which the detail view reads). `featured`/`title` are
# overridable -> taken verbatim (NULL clears the cached value).
cat_keys <- c("concept", "canonical", "featured", "topic", "title")

ids <- sub("\\.md$", "", list.files(DATASHEET_DIR, pattern = "^ch_.*\\.md$"))
for (id in ids) {
  sheet <- ds_read(id, DATASHEET_DIR)     # one read; shared by fields + hierarchy
  dm <- read_datasheet_meta(id, DATASHEET_DIR, lines = sheet)
  sc <- file.path(DATA_DIR, paste0(id, ".json"))
  if (!file.exists(sc)) next
  meta <- fromJSON(sc, simplifyVector = FALSE)
  meta <- modifyList(meta, dm)            # datasheet fields win (recursive: a
                                          # multilingual title keeps de/fr/it, only
                                          # the curated `en` is overridden)
  meta[["featured"]] <- dm[["featured"]]  # NULL -> drop (= not featured)
  # The datasheet `split` / `single-select` lines are sometimes prose ("n/a (single
  # series)", "(none; D0 is the only dimension)"), not real dimensions. Keep only
  # entries that are actual dimensions, so the output matches the pipeline: no
  # `split` field and `single_select` [] for a single-series cube.
  valid_dims <- names(meta[["dimensions"]])
  if (!is.null(dm[["single_select"]]))
    meta[["single_select"]] <- intersect(unlist(dm[["single_select"]]), valid_dims)
  if (!is.null(dm[["split"]]) && !(unlist(dm[["split"]])[1] %in% valid_dims))
    meta[["split"]] <- NULL
  # Re-apply the datasheet `## Hierarchy` block (declared trees + derive methods
  # rebuild deterministically from the sidecar's level codes; prose-only blocks and
  # source-built trees — e.g. CPI's — are no-ops). Historically this needed the
  # separate, undocumented dev/regen_hierarchy.R; now the one documented rebuild
  # covers every datasheet-controlled field.
  meta <- attach_labels(list(id = id, meta = meta), DATASHEET_DIR, lines = sheet)$meta
  meta <- attach_hierarchy(list(id = id, meta = meta), DATASHEET_DIR, lines = sheet)$meta
  writeLines(toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = "null"), sc)
}

cat_rows <- fromJSON(file.path(DATA_DIR, "catalog.json"), simplifyVector = FALSE)
for (i in seq_along(cat_rows)) {
  dm <- read_datasheet_meta(cat_rows[[i]]$id, DATASHEET_DIR)
  for (k in setdiff(cat_keys, "featured")) {
    if (is.null(dm[[k]])) next
    # The datasheet title is en-only; the catalog title is multilingual (from the
    # source meta). Merge so the curated `en` overrides but de/fr/it survive.
    if (k == "title" && is.list(cat_rows[[i]][[k]]) && is.list(dm[[k]]))
      cat_rows[[i]][[k]] <- modifyList(cat_rows[[i]][[k]], dm[[k]])
    else
      cat_rows[[i]][[k]] <- dm[[k]]
  }
  cat_rows[[i]][["featured"]] <- dm[["featured"]] %||% NA
}
writeLines(toJSON(cat_rows, auto_unbox = TRUE, pretty = TRUE, null = "null"),
           file.path(DATA_DIR, "catalog.json"))

cat(sprintf("refreshed %d sidecars + catalog.json (%d rows)\n", length(ids), length(cat_rows)))

# keep the generated docs in lockstep (run as clean subprocesses so each resolves
# its own root from --file)
for (s in c("build_catalog_md.R", "build_concepts_ledger.R"))
  system2("Rscript", file.path(root, "dev", s), stdout = FALSE, stderr = FALSE)
