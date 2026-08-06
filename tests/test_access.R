# Access-drift check: every datasheet's ## Access block must parse to a known
# type slug + a canonical identifier, and that identifier must agree with what
# the fetch code actually uses. This is the guard that would have caught the
# CPI datasheet declaring the frozen su-d-05.02.67 while the pipeline fetched
# su-d-05.02.66 — an unparsed access recipe is a comment, and comments rot.
#
# Two verification modes per family:
#   - datasheet-authoritative (fso-dam-excel): the pipeline reads the identifier
#     FROM the datasheet, so we only validate shape/presence here.
#   - code-carries-the-literal (everything else, for now): the declared
#     identifier must appear verbatim in the R sources, so datasheet and code
#     cannot drift apart silently.
#
# Run from repo root:  Rscript tests/test_access.R

source("R/datasheet.R")
source("R/io.R")

fail_n <- 0L
problem <- function(...) { cat(sprintf(...), "\n"); fail_n <<- fail_n + 1L }

# All fetch-side sources an identifier may legitimately live in.
src_files <- c(list.files("R", pattern = "\\.R$", full.names = TRUE), "R/snb_cubes.tsv")
src_txt <- paste(unlist(lapply(src_files, readLines, warn = FALSE)), collapse = "\n")

ids <- sub("\\.md$", "", list.files("datasets", pattern = "^ch_.*\\.md$"))
checked <- 0L
for (id in ids) {
  acc <- read_access(id, "datasets")
  if (is.null(acc)) { problem("%s: no parseable ## Access block", id); next }
  if (is.null(acc$identifier)) { problem("%s: no canonical identifier line (type %s)", id, acc$type); next }

  if (acc$type == "snb-cube") {
    # cube ids double as the dataset id suffix AND must be listed in snb_cubes.tsv
    if (!identical(paste0("ch_snb_", acc$identifier), id))
      problem("%s: cube '%s' does not match the dataset id", id, acc$identifier)
    if (!grepl(paste0("(^|\n)", acc$identifier, "\t"), src_txt))
      problem("%s: cube '%s' not in R/snb_cubes.tsv", id, acc$identifier)
  } else if (acc$type == "fso-dam-excel") {
    if (grepl("^[0-9 ]+$", acc$identifier)) {
      # pinned raw asset ids (trade_partner): the fetcher carries them — verify each
      for (aid in strsplit(acc$identifier, " ", fixed = TRUE)[[1]])
        if (!grepl(aid, src_txt, fixed = TRUE))
          problem("%s: pinned asset id '%s' not found in R sources", id, aid)
    } else if (!grepl("^[a-z]{2}-[a-z]-[0-9a-z._-]+$", acc$identifier)) {
      # datasheet-authoritative order number: shape only (the pipeline READS this)
      problem("%s: order number '%s' has unexpected shape", id, acc$identifier)
    }
  } else if (acc$type == "fso-sdmx") {
    parts <- strsplit(acc$identifier, "/", fixed = TRUE)[[1]]
    if (length(parts) != 3) { problem("%s: flow '%s' not agency/dataflow/version", id, acc$identifier); next }
    for (p in parts[1:2]) if (!grepl(p, src_txt, fixed = TRUE))
      problem("%s: flow part '%s' not found in R sources", id, p)
  } else {
    # seco set / kof key / pxweb table / eurostat dataflow / scraped url:
    # the code still carries the literal — declared and used must agree.
    if (!grepl(acc$identifier, src_txt, fixed = TRUE))
      problem("%s: identifier '%s' (%s) not found in R sources", id, acc$identifier, acc$type)
  }
  checked <- checked + 1L
}

if (fail_n > 0L) stop(sprintf("test_access: %d problem(s) across %d datasheets", fail_n, length(ids)))
cat(sprintf("test_access: %d datasheets verified drift-free\n", checked))
