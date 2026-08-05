# Unit tests for the datasheet SYNTAX layer (R/datasheet.R).
# Plain-script style to match the repo (no DESCRIPTION, no testthat dependency).
# Run from repo root:  Rscript tests/test_datasheet.R
# Exits non-zero on the first failure.

source("R/datasheet.R")

fail <- function(...) stop(sprintf(...), call. = FALSE)
ok <- 0L
check <- function(cond, what) {
  if (!isTRUE(cond)) fail("FAIL: %s", what)
  ok <<- ok + 1L
}

# ---- ds_top / ds_section ----------------------------------------------------
lines <- c(
  "# Title line",
  "",
  "- **id**: ch_test",
  "- **title**: A test set",
  "",
  "## What is special",
  "Some *prose*, with `code` and",
  "a second line.",
  "",
  "## Display",
  "- **split**: item",
  "- **default**: item=tot, type=a",
  "",
  "## Hierarchy",
  "- tot",
  "  - @grp: A group",
  "    - a",
  "    - b",
  "  - c"
)

check(identical(ds_top(lines), lines[1:5]), "ds_top stops at the first heading")
check(identical(ds_section(lines, "Display"), lines[11:13]), "ds_section body")
check(is.null(ds_section(lines, "Nope")), "ds_section NULL when absent")
check(identical(ds_section(c("## A", "## B", "x"), "A"), character(0)),
      "ds_section empty body")

# ---- ds_fields ----------------------------------------------------------------
f <- ds_fields(ds_top(lines))
check(identical(f$id, "ch_test"), "ds_fields reads a field")
check(identical(f$title, "A test set"), "ds_fields trims")
check(is.null(f$split), "ds_fields is scoped: Display keys invisible from top")
check(identical(ds_fields(ds_section(lines, "Display"))$split, "item"),
      "ds_fields reads the Display scope")
check(identical(ds_fields(c("- **k**: a", "- **k**: b"))$k, "a"),
      "first occurrence wins within a scope")
check(identical(ds_fields(c("- **k**:"))$k, ""), "empty value is kept, not dropped")
check(length(ds_fields(NULL)) == 0L, "NULL lines -> empty")

# ---- ds_prose -----------------------------------------------------------------
check(identical(ds_prose(lines, "What is special"),
                "Some prose, with code and a second line."),
      "ds_prose flattens + strips markers")
check(is.null(ds_prose(lines, "Nope")), "ds_prose NULL when absent")

# ---- ds_i18n ------------------------------------------------------------------
check(identical(ds_i18n("Men"), list(en = "Men")),
      "no separator -> en only (pre-i18n datasheets parse unchanged)")
check(identical(ds_i18n("Men | de: Männer | fr: Hommes"),
                list(en = "Men", de = "Männer", fr = "Hommes")),
      "full grammar")
check(identical(ds_i18n("Sector 1: Agriculture | de: Sektor 1: Landwirtschaft"),
                list(en = "Sector 1: Agriculture", de = "Sektor 1: Landwirtschaft")),
      "colons inside label text survive")
check(is.null(ds_i18n("")), "empty -> NULL")
check(is.null(ds_i18n(NULL)), "NULL -> NULL")
r <- tryCatch(ds_i18n("X | ff: nope"), error = function(e) "err")
check(identical(r, "err"), "unknown language tag is an error, not a silent skip")
r <- tryCatch(ds_i18n("X | just text"), error = function(e) "err")
check(identical(r, "err"), "untagged segment is an error")

# ---- ds_bullets / ds_tree -------------------------------------------------------
specs <- ds_bullets(ds_section(lines, "Hierarchy"))
check(length(specs) == 1L && is.null(specs[[1]]$dim), "one spec, split-scoped")
it <- specs[[1]]$items
check(length(it) == 5L && it[[1]]$depth == 0L && it[[2]]$depth == 1L &&
        it[[3]]$depth == 2L && it[[5]]$depth == 1L &&
        identical(it[[2]]$text, "@grp: A group"),
      "bullets carry depth + raw text")
tree <- ds_tree(list(list(depth = 0L, code = "tot"),
                     list(depth = 1L, code = "a"),
                     list(depth = 1L, code = "b"),
                     list(depth = 0L, code = "x")))
check(identical(names(tree), c("tot", "x")) &&
        identical(names(tree$tot), c("a", "b")) && length(tree$x) == 0L,
      "ds_tree folds depths into nesting")

multi <- ds_bullets(c("- dim: alpha", "- derive: under-root T",
                      "- dim: beta", "- x", "  - y"))
check(length(multi) == 2L && identical(multi[[1]]$dim, "alpha") &&
        identical(multi[[1]]$derive, "under-root T") &&
        identical(multi[[2]]$dim, "beta") && length(multi[[2]]$items) == 2L,
      "dim: opens a new directive; derive and tree coexist across directives")
check(is.null(ds_bullets(c("just prose", "over two lines"))),
      "prose-only block -> NULL")
check(is.null(ds_bullets(NULL)), "NULL section -> NULL")

cat(sprintf("test_datasheet: %d checks passed\n", ok))
