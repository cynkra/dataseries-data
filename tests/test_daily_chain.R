# The daily ETL chain's NON-fetch scripts must survive the current schema.
# Motivated by a real break: schema 1.1 turned catalog `source` into an object
# and `categories.name` into a label object, which crashed health.R and
# build_concepts_ledger.R and silently emptied CATALOG.md's Source column —
# silently, because rebuild_from_datasheets.R ran the doc builders with
# stdout/stderr suppressed. Every curated string must be read tolerantly
# (bare string | i18n object | {name: i18n object}), the same rule the website
# follows. See spec/multilingual/2-design.md §6.
#
# Run from repo root:  Rscript tests/test_daily_chain.R
# (Runs the real scripts; they rewrite generated files idempotently.)

scripts <- c("R/health.R", "R/uptime.R",
             "dev/build_catalog_md.R", "dev/build_concepts_ledger.R")
fails <- character(0)
for (s in scripts) {
  rc <- system2("Rscript", s, stdout = FALSE, stderr = FALSE)
  if (!identical(rc, 0L)) fails <- c(fails, sprintf("%s (exit %s)", s, rc))
}
if (length(fails))
  stop("daily-chain script(s) failed: ", paste(fails, collapse = ", "), call. = FALSE)

# CATALOG.md's generated columns must not be blank — the silent-failure mode.
cm <- readLines("CATALOG.md", warn = FALSE)
rows <- grep("^\\| `ch_", cm, value = TRUE)
if (!length(rows)) stop("CATALOG.md has no dataset rows", call. = FALSE)
blank <- grep("\\|\\s*\\|", rows, value = TRUE)
if (length(blank))
  stop(sprintf("CATALOG.md has %d row(s) with an empty column, e.g. %s",
               length(blank), substr(blank[1], 1, 90)), call. = FALSE)

cat(sprintf("test_daily_chain: %d scripts green, %d CATALOG rows fully populated\n",
            length(scripts), length(rows)))
