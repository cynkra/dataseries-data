# Every level code in the data is a level key in the meta. The site draws one
# button per meta level and looks that same string up in the data, so a code
# that exists on only one side gives a greyed-out button that can never be
# selected. ch_ffa_finances shipped like that from 2026-08-27: the FFA switched
# its estimate column from English to German text, the CSV followed, and the
# meta kept the English keys.
#
# Also checks that the meta `default` names levels that exist and occur in the
# data, since the site opens every dataset on that selection.
#
# Run from repo root:  Rscript tests/test_level_codes.R

source("R/io.R")

fail_n <- 0L
problem <- function(...) { cat(sprintf(...), "\n"); fail_n <<- fail_n + 1L }
show <- function(x) paste(head(x, 5), collapse = ", ")

checked <- 0L
for (csv in list.files("data", pattern = "^ch_.*\\.csv$", full.names = TRUE)) {
  id <- sub("\\.csv$", "", basename(csv))
  jp <- sub("\\.csv$", ".json", csv)
  if (!file.exists(jp)) { problem("%s: CSV without a JSON meta", id); next }
  meta <- jsonlite::fromJSON(jp, simplifyVector = FALSE)
  data <- read_data_csv(csv)
  dc <- dim_cols(data)

  for (d in dc) {
    codes <- unique(data[[d]])
    if (anyNA(codes)) problem("%s: dim %s has missing codes in the CSV", id, d)
    keys <- names(meta$dimensions[[d]]$levels)
    if (is.null(keys)) { problem("%s: dim %s has no levels in the meta", id, d); next }
    miss <- setdiff(codes[!is.na(codes)], keys)
    if (length(miss))
      problem("%s: %d code(s) in dim %s are not meta levels: %s", id, length(miss), d, show(miss))
  }

  for (d in names(meta$default)) {
    want <- unlist(meta$default[[d]])
    if (!d %in% dc) { problem("%s: default names unknown dim %s", id, d); next }
    bad <- setdiff(want, names(meta$dimensions[[d]]$levels))
    if (length(bad)) problem("%s: default %s=%s is not a meta level", id, d, show(bad))
    nodata <- setdiff(want, c(bad, data[[d]]))
    if (length(nodata)) problem("%s: default %s=%s has no data", id, d, show(nodata))
  }
  checked <- checked + 1L
}

if (fail_n) {
  cat(sprintf("FAIL: %d problem(s) across %d datasets\n", fail_n, checked))
  quit(status = 1L)
}
cat(sprintf("ok: %d datasets, every CSV code is a meta level and every default exists\n", checked))
