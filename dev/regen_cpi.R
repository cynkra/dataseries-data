# One-off: rebuild ch_fso_cpi from source so its COICOP `Level` hierarchy lands in the
# committed files. Unlike dev/rebuild_from_datasheets.R this DOES re-fetch (the tree
# comes from the source `Level` column, which isn't in the stored data). Mirrors the
# pipeline's per-dataset steps for just CPI.
#
# Run: Rscript dev/regen_cpi.R
root <- "R"
for (f in c("dates.R", "http.R", "datasheet.R", "io.R", "labels.R", "hierarchy.R",
            "source_fso_excel.R", "source_fso_excel_sets.R")) source(file.path(root, f))

DATA_DIR <- "data"; DATASHEET_DIR <- "datasets"

# fso_excel_dataset() lives in pipeline.R; reproduce its two lines here to avoid
# sourcing the whole pipeline (which would run main()).
dl <- fso_excel_download(read_access("ch_fso_cpi", DATASHEET_DIR)$identifier)
ds <- fso_excel_ch_fso_cpi(dl$path, dl$pubdate)
ds$meta <- modifyList(ds$meta, read_datasheet_meta(ds$id, DATASHEET_DIR))
ds <- attach_labels(ds, DATASHEET_DIR)
ds <- attach_hierarchy(ds, DATASHEET_DIR)            # no-op: parser already set the tree
ds <- write_dataset(ds, DATA_DIR)
h <- ds$meta$dimensions$item$hierarchy
cat(sprintf("ch_fso_cpi: %d rows, %d levels, hierarchy nodes=%d\n",
            nrow(ds$data), length(ds$meta$dimensions$item$levels),
            if (is.null(h)) 0L else length(tree_codes(h))))
