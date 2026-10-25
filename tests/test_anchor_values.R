# Anchor-value check: known-good data points must survive the ETL unchanged.
#
# Each anchor in tests/anchors.json is a (dataset, dims, date, value) triple
# taken from an official source. The test reads the local data/*.csv and asserts
# exact agreement within a small relative tolerance, so a parser shift, a unit
# change or a dimension rename that drops rows fails here. No network access.
#
# Run from repo root:  Rscript tests/test_anchor_values.R

suppressWarnings(suppressMessages(library(jsonlite)))

anchors <- fromJSON("tests/anchors.json", simplifyVector = FALSE)$anchors
if (!length(anchors)) stop("no anchors found in tests/anchors.json", call. = FALSE)

default_tol <- 1e-4
fail_n <- 0L
ok_n <- 0L
problem <- function(...) { cat(sprintf(...), "\n"); fail_n <<- fail_n + 1L }

for (a in anchors) {
  id <- a$dataset
  csv_path <- file.path("data", paste0(id, ".csv"))

  if (!file.exists(csv_path)) {
    problem("%s: data file missing (%s)", id, csv_path)
    next
  }

  d <- read.csv(csv_path, stringsAsFactors = FALSE)

  mask <- d$date == a$date
  if (!any(mask)) {
    problem("%s: date %s not found in data", id, a$date)
    next
  }

  dims <- a$dims
  if (length(dims)) {
    for (nm in names(dims)) {
      if (!nm %in% names(d)) {
        problem("%s: dimension column '%s' not found (have: %s)",
                id, nm, paste(setdiff(names(d), c("date", "value")), collapse = ", "))
        mask <- rep(FALSE, nrow(d))
        break
      }
      mask <- mask & d[[nm]] == dims[[nm]]
    }
  }

  rows <- d[mask, , drop = FALSE]
  if (nrow(rows) == 0L) {
    dim_str <- if (length(dims)) paste(names(dims), unlist(dims), sep = "=", collapse = ", ") else "(no dims)"
    problem("%s: no row for date=%s, %s", id, a$date, dim_str)
    next
  }
  if (nrow(rows) > 1L) {
    problem("%s: %d rows match (expected 1) for date=%s", id, nrow(rows), a$date)
    next
  }

  got <- rows$value[1]
  expected <- a$value

  if (is.na(got)) {
    problem("%s [%s]: value is NA, expected %.6g", id, a$date, expected)
    next
  }

  tol <- if (!is.null(a$tolerance)) a$tolerance else default_tol
  rel_err <- abs(got - expected) / max(abs(expected), 1e-12)
  if (rel_err > tol) {
    problem("%s [%s]: got %.10g, expected %.10g (rel err %.2e)",
            id, a$date, got, expected, rel_err)
    next
  }

  ok_n <- ok_n + 1L
}

cat(sprintf("test_anchor_values: %d/%d anchors verified\n", ok_n, ok_n + fail_n))
if (fail_n > 0L) stop(sprintf("%d anchor(s) failed", fail_n), call. = FALSE)
