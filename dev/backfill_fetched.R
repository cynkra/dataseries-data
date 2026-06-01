# One-off: backfill the `fetched_utc` meta field onto existing datasets WITHOUT
# re-fetching them. Re-fetching would falsely stamp every dataset "now"; instead we
# take a faithful "when we last wrote it" from the <id>.csv file mtime. Then rebuild
# catalog.json from on-disk state so every catalog entry carries the new "fetched"
# field (the dev/refresh_cpi.R rebuild pattern).
#
# Run from repo root:  Rscript dev/backfill_fetched.R
suppressPackageStartupMessages({ library(dplyr); library(jsonlite) })
root <- "R"
for (f in c("io.R")) source(file.path(root, f))
DATA_DIR <- "data"

# 1) Backfill fetched_utc into each <id>.json that lacks it, from the CSV mtime.
existing <- jsonlite::fromJSON(file.path(DATA_DIR, "catalog.json"), simplifyVector = FALSE)
order_ids <- vapply(existing, function(e) e$id, character(1))

n_backfilled <- 0L
for (id in order_ids) {
  jf <- file.path(DATA_DIR, paste0(id, ".json"))
  cf <- file.path(DATA_DIR, paste0(id, ".csv"))
  meta <- jsonlite::fromJSON(jf, simplifyVector = FALSE)
  if (is.null(meta$fetched_utc) || is.na(meta$fetched_utc) || !nzchar(meta$fetched_utc)) {
    mtime <- file.info(cf)$mtime
    meta$fetched_utc <- format(as.POSIXct(mtime), tz = "UTC", "%Y-%m-%d %H:%M:%S")
    writeLines(
      jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = "null"), jf
    )
    n_backfilled <- n_backfilled + 1L
    cat(sprintf("backfilled %-26s fetched_utc=%s\n", id, meta$fetched_utc))
  }
}
cat(sprintf("backfilled %d of %d datasets\n", n_backfilled, length(order_ids)))

# 2) Rebuild catalog.json from on-disk state, preserving the existing order. The
#    json now carries fetched_utc, so catalog_entry() emits a non-null "fetched".
datasets <- lapply(order_ids, function(id) {
  list(id = id,
       meta = jsonlite::fromJSON(file.path(DATA_DIR, paste0(id, ".json")), simplifyVector = FALSE),
       data = as.data.frame(arrow::read_parquet(file.path(DATA_DIR, paste0(id, ".parquet")))))
})
write_catalog(datasets, DATA_DIR)
cat(sprintf("catalog rebuilt: %d datasets\n", length(datasets)))

# 3) Verify: every catalog entry now has a non-null "fetched".
cat_check <- jsonlite::fromJSON(file.path(DATA_DIR, "catalog.json"), simplifyVector = FALSE)
missing <- Filter(function(e) is.null(e$fetched) || is.na(e$fetched) || !nzchar(e$fetched), cat_check)
if (length(missing)) {
  stop(sprintf("%d catalog entries still missing 'fetched': %s",
               length(missing),
               paste(vapply(missing, function(e) e$id, character(1)), collapse = ", ")))
}
cat(sprintf("OK: all %d catalog entries have a non-null 'fetched'\n", length(cat_check)))
