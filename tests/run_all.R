# Run every check in this directory. From the repo root:
#
#   Rscript tests/run_all.R
#
# These are plain Rscript files, not testthat: they need the repo's data/ and
# datasets/ on disk, which is the point — most of what can go wrong here is a
# datasheet and its generated output disagreeing, not a function returning the
# wrong value.
#
# The daily ETL runs these too, via .github/scripts/test_issues.sh — but it
# REPORTS rather than gates: a failing guard opens an issue labelled `data-guard`
# and the data still publishes. So a red guard will not stop the pipeline, and
# equally will not block you here. Run this before pushing a datasheet edit.

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
