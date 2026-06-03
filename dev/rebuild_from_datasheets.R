#!/usr/bin/env Rscript
# rebuild_from_datasheets.R — re-derive every datasheet-controlled field onto the
# meta sidecars (data/<id>.json) and data/catalog.json FROM DISK, no refetch. Run
# this after editing datasheets (title, concept, canonical, featured, default,
# split, transform, …) to propagate the change to what the API serves.
#
# Datasheets are the source of truth; this just refreshes the generated caches.
# Idempotent. Run from repo root: Rscript dev/rebuild_from_datasheets.R

suppressWarnings(suppressMessages(library(jsonlite)))
root <- normalizePath(file.path(dirname(sub("--file=", "",
  grep("--file=", commandArgs(FALSE), value = TRUE)[1])), ".."))
DATASHEET_DIR <- file.path(root, "datasets")
DATA_DIR      <- file.path(root, "data")
source(file.path(root, "R", "io.R"))   # read_datasheet_meta(), %||%

# Fields the catalog row carries (the rest of the datasheet meta lives only in the
# per-dataset sidecar, which the detail view reads). `featured`/`title` are
# overridable -> taken verbatim (NULL clears the cached value).
cat_keys <- c("concept", "canonical", "featured", "topic", "title")

ids <- sub("\\.md$", "", list.files(DATASHEET_DIR, pattern = "^ch_.*\\.md$"))
for (id in ids) {
  dm <- read_datasheet_meta(id, DATASHEET_DIR)
  sc <- file.path(DATA_DIR, paste0(id, ".json"))
  if (!file.exists(sc)) next
  meta <- fromJSON(sc, simplifyVector = FALSE)
  meta <- modifyList(meta, dm)            # datasheet fields win
  meta[["featured"]] <- dm[["featured"]]  # NULL -> drop (= not featured)
  writeLines(toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = "null"), sc)
}

cat_rows <- fromJSON(file.path(DATA_DIR, "catalog.json"), simplifyVector = FALSE)
for (i in seq_along(cat_rows)) {
  dm <- read_datasheet_meta(cat_rows[[i]]$id, DATASHEET_DIR)
  for (k in setdiff(cat_keys, "featured"))
    if (!is.null(dm[[k]])) cat_rows[[i]][[k]] <- dm[[k]]
  cat_rows[[i]][["featured"]] <- dm[["featured"]] %||% NA
}
writeLines(toJSON(cat_rows, auto_unbox = TRUE, pretty = TRUE, null = "null"),
           file.path(DATA_DIR, "catalog.json"))

cat(sprintf("refreshed %d sidecars + catalog.json (%d rows)\n", length(ids), length(cat_rows)))

# keep the generated docs in lockstep (run as clean subprocesses so each resolves
# its own root from --file)
for (s in c("build_catalog_md.R", "build_concepts_ledger.R"))
  system2("Rscript", file.path(root, "dev", s), stdout = FALSE, stderr = FALSE)
