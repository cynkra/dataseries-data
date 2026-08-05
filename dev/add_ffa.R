# One-off: fetch the new ch_ffa_finances dataset, write it (write_dataset() stamps
# fetched_utc), and rebuild catalog.json from on-disk state WITHOUT re-fetching the
# other 51 datasets (the dev/refresh_cpi.R rebuild pattern). The new dataset is
# appended to the existing catalog order.
#
# Run from repo root:  Rscript dev/add_ffa.R
suppressPackageStartupMessages({ library(dplyr); library(jsonlite) })
root <- "R"
for (f in c("dates.R", "http.R", "datasheet.R", "io.R", "source_ffa.R")) source(file.path(root, f))
DATA_DIR <- "data"; DATASHEET_DIR <- "datasets"

# 1) fetch + write the new dataset (merging its datasheet curation)
ffa <- ffa_fetch("ch_ffa_finances",
                 title = list(en = "Public finances: general government main aggregates"))
ffa$meta$topic <- "Public finances"
ffa$meta <- modifyList(ffa$meta, read_datasheet_meta("ch_ffa_finances", DATASHEET_DIR))
write_dataset(ffa, DATA_DIR)
cat(sprintf("FFA written: %d rows, %d series, span %s .. %s\n",
            nrow(ffa$data), n_series(ffa$data),
            as.character(min(ffa$data$date)), as.character(max(ffa$data$date))))

# 2) rebuild catalog from on-disk state. Preserve existing order; append the new id
#    if it isn't already in the catalog.
existing <- jsonlite::fromJSON(file.path(DATA_DIR, "catalog.json"), simplifyVector = FALSE)
order_ids <- vapply(existing, function(e) e$id, character(1))
if (!("ch_ffa_finances" %in% order_ids)) order_ids <- c(order_ids, "ch_ffa_finances")

datasets <- lapply(order_ids, function(id) {
  list(id = id,
       meta = jsonlite::fromJSON(file.path(DATA_DIR, paste0(id, ".json")), simplifyVector = FALSE),
       data = as.data.frame(arrow::read_parquet(file.path(DATA_DIR, paste0(id, ".parquet")))))
})
write_catalog(datasets, DATA_DIR)
cat(sprintf("catalog rebuilt: %d datasets\n", length(datasets)))
