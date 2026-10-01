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
  # Dimension columns as text, the same spec as read_data_csv() in R/io.R.
  # Guessed, an all-digit code column became a double, the API sent 8100
  # where the site selects "8100", and those datasets opened empty. No na
  # strings for the codes: "NA" is a real SNB code and became a null.
  data <- readr::read_csv(csv, show_col_types = FALSE, progress = FALSE, na = character(),
                          col_types = readr::cols(.default = readr::col_character()))
  if ("date" %in% names(data)) data$date <- readr::parse_date(data$date)
  if ("value" %in% names(data)) data$value <- readr::parse_double(data$value, na = c("", "NA"))
  pq <- sub("\\.csv$", ".parquet", csv)
  arrow::write_parquet(data, pq)
  n <- n + 1L
}
cat(sprintf("parquet cache built: %d files in %s\n", n, DATA_DIR))
