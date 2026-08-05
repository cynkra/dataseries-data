# One-off: refresh ch_fso_cpi from the current FSO asset and rebuild catalog.json
# from on-disk state (no re-fetch of the other datasets). Run from repo root:
#   Rscript dev/refresh_cpi.R
suppressPackageStartupMessages({ library(dplyr) })
root <- "R"
for (f in c("dates.R", "http.R", "datasheet.R", "io.R", "source_snb.R", "source_kof.R",
            "source_fso.R", "source_fso_excel.R", "source_fso_excel_sets.R",
            "source_seco.R")) source(file.path(root, f))
DATA_DIR <- "data"; DATASHEET_DIR <- "datasets"

fso_excel_dataset <- function(id, order_nr = NULL, topic = NULL) {
  order_nr <- order_nr %||% read_access(id, DATASHEET_DIR)$identifier
  dl <- fso_excel_download(order_nr)
  ds <- get(paste0("fso_excel_", id), mode = "function")(dl$path, dl$pubdate)
  if (!is.null(topic)) ds$meta$topic <- topic
  ds
}

# 1) refresh CPI from the asset declared in the datasheet ## Access block
cpi <- fso_excel_dataset("ch_fso_cpi")
cpi$meta <- modifyList(cpi$meta, read_datasheet_meta("ch_fso_cpi", DATASHEET_DIR))
write_dataset(cpi, DATA_DIR)
cat(sprintf("CPI refreshed: %d rows, %d series, span %s .. %s\n",
            nrow(cpi$data), n_series(cpi$data),
            as.character(min(cpi$data$date)), as.character(max(cpi$data$date))))

# 2) rebuild catalog from on-disk state, preserving the existing dataset order
existing <- jsonlite::fromJSON(file.path(DATA_DIR, "catalog.json"), simplifyVector = FALSE)
order_ids <- vapply(existing, function(e) e$id, character(1))
datasets <- lapply(order_ids, function(id) {
  list(id = id,
       meta = jsonlite::fromJSON(file.path(DATA_DIR, paste0(id, ".json")), simplifyVector = FALSE),
       data = as.data.frame(arrow::read_parquet(file.path(DATA_DIR, paste0(id, ".parquet")))))
})
write_catalog(datasets, DATA_DIR)
cat(sprintf("catalog rebuilt: %d datasets\n", length(datasets)))
