# The invariant behind the datasheet source-of-truth model: ZERO human-written
# user-facing strings in the fetch code. Every curated display string (titles,
# dimension/level labels, units, source names, license names) lives in a
# datasheet ## Labels block / title line or in the shared data/*.json
# vocabularies. What legitimately remains in R/ is algorithms and source-derived
# text (sheet parsing, code sets, format strings around source data).
#
# Run from repo root:  Rscript tests/test_no_literals.R

files <- c(list.files("R", pattern = "^(source_.*|pipeline)\\.R$", full.names = TRUE))
bad <- list()
for (f in files) {
  lines <- readLines(f, warn = FALSE)
  hits <- grep('\\ben = "', lines, perl = TRUE)
  for (h in hits) bad[[length(bad) + 1L]] <- sprintf("%s:%d: %s", f, h, trimws(lines[h]))
}
if (length(bad)) {
  cat("hand-written label literals found (move them to the datasheet ## Labels block):\n")
  cat(paste0("  ", unlist(bad), collapse = "\n"), "\n")
  stop(sprintf("test_no_literals: %d literal(s)", length(bad)))
}

# snb_cubes.tsv is a pure fetch manifest again: no curated title column.
stopifnot(identical(strsplit(readLines("R/snb_cubes.tsv", n = 1), "\t")[[1]],
                    c("cube_id", "topic")))

cat("test_no_literals: clean — no curated strings in the fetch code\n")
