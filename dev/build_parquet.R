# Build the Parquet cache from the committed CSVs. Parquet is a derived,
# columnar cache for fast API reads (DuckDB/arrow) and is NOT committed to git;
# it is rebuilt at deploy/sync time from the CSV source of truth. Run from repo
# root (optional data-dir arg, default "data"):
#   Rscript dev/build_parquet.R [data]
args <- commandArgs(trailingOnly = TRUE)
DATA_DIR <- if (length(args) >= 1) args[[1]] else "data"

csvs <- list.files(DATA_DIR, pattern = "\\.csv$", full.names = TRUE)
n <- 0L
for (csv in csvs) {
  # readr parses `date` -> Date and `value` -> double, matching write_dataset()
  data <- readr::read_csv(csv, show_col_types = FALSE)
  pq <- sub("\\.csv$", ".parquet", csv)
  arrow::write_parquet(data, pq)
  n <- n + 1L
}
cat(sprintf("parquet cache built: %d files in %s\n", n, DATA_DIR))
