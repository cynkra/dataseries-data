# Level codes stay text from CSV to Parquet. The API serves the Parquet cache
# that dev/build_parquet.R builds at deploy time, and the site selects codes as
# strings. When that script let readr guess types, the all-digit code columns
# (ch_fso_hesta, ch_fso_ppi, ch_fso_jobs_sex, ch_fso_vacancies) became doubles,
# the API sent 8100 where the site selected "8100", and those datasets opened on
# "No data for this selection".
#
# Builds the cache the way the deploy does, from a synthetic CSV plus every
# data/*.csv, and checks each dim column comes back as the CSV's text.
#
# Run from repo root:  Rscript tests/test_parquet_codes.R

source("R/io.R")

fail_n <- 0L
problem <- function(...) { cat(sprintf(...), "\n"); fail_n <<- fail_n + 1L }

tmp <- tempfile("parquet-codes-"); dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
writeLines(c("region,date,value", "01,2020-01-01,1", "8100,2020-01-01,2", "100000,2020-01-01,3"),
           file.path(tmp, "synthetic.csv"))
csvs <- list.files("data", pattern = "^ch_.*\\.csv$", full.names = TRUE)
invisible(file.copy(csvs, tmp))

rc <- system2("Rscript", c("dev/build_parquet.R", tmp), stdout = FALSE)
if (!identical(rc, 0L)) problem("dev/build_parquet.R exited with %s", rc)

checked <- 0L
for (csv in list.files(tmp, pattern = "\\.csv$", full.names = TRUE)) {
  id   <- sub("\\.csv$", "", basename(csv))
  text <- readr::read_csv(csv, col_types = readr::cols(.default = "c"), progress = FALSE)
  pq   <- arrow::read_parquet(sub("\\.csv$", ".parquet", csv))
  for (d in dim_cols(text)) {
    if (!is.character(pq[[d]])) {
      problem("%s: parquet column %s is %s, not character", id, d, class(pq[[d]])[1])
      next
    }
    if (!identical(pq[[d]], text[[d]]))
      problem("%s: parquet codes in %s differ from the CSV text (e.g. %s)", id, d,
              paste(head(setdiff(text[[d]], pq[[d]]), 3), collapse = ", "))
  }
  checked <- checked + 1L
}

# read_data_csv() is what the pipeline reloads an unchanged dataset with.
syn <- read_data_csv(file.path(tmp, "synthetic.csv"))
if (!identical(syn$region, c("01", "8100", "100000")))
  problem("read_data_csv: region read as %s", paste(syn$region, collapse = ", "))
if (!inherits(syn$date, "Date") || !is.double(syn$value))
  problem("read_data_csv: date/value not Date/double")

if (fail_n) {
  cat(sprintf("FAIL: %d problem(s) across %d CSVs\n", fail_n, checked))
  quit(status = 1L)
}
cat(sprintf("ok: %d CSVs, dim codes stay text in the parquet\n", checked))
