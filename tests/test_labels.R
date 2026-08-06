# Unit + corpus tests for the ## Labels block (R/labels.R).
# Run from repo root:  Rscript tests/test_labels.R

suppressWarnings(suppressMessages(library(jsonlite)))
source("R/datasheet.R")
source("R/labels.R")

fail <- function(...) stop(sprintf(...), call. = FALSE)
ok <- 0L
check <- function(cond, what) { if (!isTRUE(cond)) fail("FAIL: %s", what); ok <<- ok + 1L }

# ---- parser -------------------------------------------------------------------
lines <- c(
  "## Labels",
  "- **units**: Index (1993 = 100) | de: Index (1993 = 100)",
  "- dim: breakdown",
  "  - **label**: Breakdown | de: Gliederung",
  "  - tot: Total",
  "  - m: Men | de: Männer | fr: Hommes",
  "  - `Budget/financial plans`: Budget / financial plans",
  "## Next section"
)
specs <- read_labels_block(lines)
check(length(specs) == 2L, "two specs: top scope + one dim")
check(identical(specs[[1]]$units, list(en = "Index (1993 = 100)", de = "Index (1993 = 100)")),
      "top-scope units parses i18n")
s <- specs[[2]]
check(identical(s$dim, "breakdown"), "dim scope")
check(identical(s$label, list(en = "Breakdown", de = "Gliederung")), "dim label")
check(identical(s$levels$m, list(en = "Men", de = "Männer", fr = "Hommes")), "level i18n")
check(identical(s$levels$tot, list(en = "Total")), "bare en level")
check(identical(s$levels[["Budget/financial plans"]], list(en = "Budget / financial plans")),
      "backtick-quoted phrase code")
r <- tryCatch(read_labels_block(c("## Labels", "- dim: d", "  - just prose no colon")),
              error = function(e) "err")
check(identical(r, "err"), "malformed level line is an error")
check(is.null(read_labels_block(c("## Other", "- x: y"))), "no block -> NULL")

# ---- application ----------------------------------------------------------------
ds <- list(id = "t", meta = list(dimensions = list(
  breakdown = list(levels = list(
    tot = list(label = list(en = "OLD"), data = TRUE),
    m   = list(data = TRUE))))))
tmp <- tempfile(); dir.create(tmp)
writeLines(lines[1:7], file.path(tmp, "t.md"))
out <- attach_labels(ds, tmp)
lv <- out$meta$dimensions$breakdown$levels
check(identical(lv$tot$label$en, "Total"), "override wins")
check(identical(names(lv$tot), c("label", "data")), "label stays the FIRST key on override")
check(identical(names(lv$m), c("label", "data")), "label inserted FIRST on a bare level")
check(identical(out$meta$dimensions$breakdown$label$en, "Breakdown"), "dim label set")
check(identical(out$meta$units$en, "Index (1993 = 100)"), "dataset units set")
check(!is.null(lv[["Budget/financial plans"]]), "unknown code is created (group headers)")

# ---- corpus: every ## Labels block agrees with its sidecar ----------------------
# The block is the source of truth; the sidecar is its generated cache. Until a
# rebuild runs, the two must already agree on every en string — this catches a
# block edit committed without `Rscript dev/rebuild_from_datasheets.R`.
ids <- sub("\\.md$", "", list.files("datasets", pattern = "^ch_.*\\.md$"))
n_blocks <- 0L
for (id in ids) {
  lines <- ds_read(id, "datasets")
  specs <- read_labels_block(lines)
  if (is.null(specs)) next
  n_blocks <- n_blocks + 1L
  meta <- fromJSON(file.path("data", paste0(id, ".json")), simplifyVector = FALSE)
  for (s in specs) {
    if (is.null(s$dim)) {
      if (!is.null(s$units))
        check(identical(meta$units$en, s$units$en), sprintf("%s: units en in sync", id))
      next
    }
    dim <- meta$dimensions[[s$dim]]
    check(!is.null(dim), sprintf("%s: dim '%s' exists", id, s$dim))
    if (!is.null(s$label))
      check(identical(dim$label$en, s$label$en), sprintf("%s/%s: dim label en in sync", id, s$dim))
    for (code in names(s$levels))
      check(identical(dim$levels[[code]]$label$en, s$levels[[code]]$en),
            sprintf("%s/%s/%s: level label en in sync", id, s$dim, code))
  }
}
check(n_blocks >= 21L, "all migrated datasheets carry a ## Labels block")

cat(sprintf("test_labels: %d checks passed (%d datasheets with blocks)\n", ok, n_blocks))
