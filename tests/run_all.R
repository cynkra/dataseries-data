# Run every check in this directory. From the repo root:
#
#   Rscript tests/run_all.R
#
# These are plain Rscript files, not testthat: they need the repo's data/ and
# datasets/ on disk, which is the point — most of what can go wrong here is a
# datasheet and its generated output disagreeing, not a function returning the
# wrong value.
#
# NOTE: nothing runs these automatically. The ETL workflow refreshes data and
# commits it without consulting them, so a datasheet edit that breaks a guard
# stays broken until someone runs this. Worth wiring into CI on push.

files <- sort(list.files("tests", pattern = "^test_.*\\.R$", full.names = TRUE))
if (!length(files)) stop("no tests found — run me from the repo root", call. = FALSE)

fail <- character(0)
for (f in files) {
  cat(sprintf("\n=== %s ===\n", basename(f)))
  rc <- system2("Rscript", f)
  if (!identical(rc, 0L)) fail <- c(fail, basename(f))
}

cat(sprintf("\n%s\n", strrep("-", 70)))
if (length(fail)) {
  cat(sprintf("FAILED (%d/%d): %s\n", length(fail), length(files), paste(fail, collapse = ", ")))
  quit(status = 1L)
}
cat(sprintf("all %d suites green\n", length(files)))
