# The datasheet `## Labels` block: curated, human-written display text — the
# strings a human chose, in every language — declared in the datasheet instead of
# retyped as literals in the fetchers. Source-derived labels (SNB cubes, PX-Web
# valueTexts, SDMX codelists, the CPI workbook columns) do NOT belong here: those
# stay fetched, per language, and a datasheet only overrides what a human wrote.
#
# Grammar (syntax via ds_section()/ds_bullets()/ds_i18n() in R/datasheet.R):
#
#   ## Labels
#   - **units**: <i18n>                 dataset-wide units line
#   - dim: <dimension>
#     - **label**: <i18n>               the dimension's own label
#     - <code>: <i18n>                  one level label (split on the FIRST ": "
#                                       after the code token; labels may contain
#                                       colons, codes may not)
#
# Every value is "<en> | de: … | fr: …" (ds_i18n). Application is SPARSE: only
# the strings the block names are touched; everything else keeps its source-
# derived value (recursive modifyList semantics, same as the datasheet title).
# A code not present in the dimension is CREATED (label-only, no data flag) —
# that is how synthetic hierarchy group headers get their text; the pipeline's
# annotate_levels_with_data() stamps `data: false` on them at write time.
#
# Spec: dataseries.org spec/multilingual/2-design.md §3.

# Parse the ## Labels block into specs: list(dim=, label=, units=, levels=named
# list of i18n lists). The dim=NULL spec (lines before the first `dim:`) may only
# carry `units`. Returns NULL when there is no block / no directive content.
read_labels_block <- function(lines) {
  specs <- ds_bullets(ds_section(lines, "Labels"))
  if (is.null(specs)) return(NULL)
  lapply(specs, function(s) {
    out <- list(dim = s$dim, label = NULL, units = NULL, levels = list())
    for (it in s$items) {
      txt <- it$text
      fm <- regmatches(txt, regexec("^\\*\\*(label|units)\\*\\*:\\s*(.*)$", txt))[[1]]
      if (length(fm) == 3) { out[[fm[2]]] <- ds_i18n(fm[3]); next }
      # Codes are bare tokens (no spaces/colons); a code that IS a phrase — e.g. the
      # FFA estimate codes ("Financial statements") — is written backtick-quoted.
      m <- regmatches(txt, regexec("^`([^`]+)`:\\s*(.+)$", txt, perl = TRUE))[[1]]
      if (length(m) != 3)
        m <- regmatches(txt, regexec("^([^\\s:]+):\\s*(.+)$", txt, perl = TRUE))[[1]]
      if (length(m) != 3)
        stop(sprintf("labels: malformed line '%s' (want '<code>: <text>' or '**label**:/**units**:')",
                     txt), call. = FALSE)
      out$levels[[m[2]]] <- ds_i18n(m[3])
    }
    out
  })
}

# Insert/replace `label` as the FIRST key of a level/dimension entry. Keeps the
# sidecar key order identical whether the label came from the fetcher (historical
# order: label first) or from the datasheet block.
.set_label_first <- function(entry, label) {
  entry <- entry %||% list()
  c(list(label = label), entry[setdiff(names(entry), "label")])
}

# Apply the datasheet ## Labels block to one dataset (list(id=, meta=)). Runs
# after the field merge and BEFORE attach_hierarchy(), so a declared tree can
# reference block-created group codes. No block is a no-op.
attach_labels <- function(ds, datasheet_dir, lines = NULL) {
  lines <- lines %||% ds_read(ds$id, datasheet_dir)
  if (is.null(lines)) return(ds)
  specs <- read_labels_block(lines)
  if (is.null(specs)) return(ds)
  for (s in specs) {
    if (is.null(s$dim)) {                       # top scope: dataset-wide units
      if (!is.null(s$units)) ds$meta$units <- s$units
      if (!is.null(s$label) || length(s$levels))
        warning(sprintf("%s: ## Labels entries before any 'dim:' line are ignored (except units)",
                        ds$id))
      next
    }
    if (is.null(ds$meta$dimensions[[s$dim]])) {
      warning(sprintf("%s: ## Labels targets unknown dim '%s'", ds$id, s$dim))
      next
    }
    dim <- ds$meta$dimensions[[s$dim]]
    if (!is.null(s$label)) dim <- .set_label_first(dim, s$label)
    if (!is.null(s$units)) dim$units <- s$units
    for (code in names(s$levels))
      dim$levels[[code]] <- .set_label_first(dim$levels[[code]], s$levels[[code]])
    ds$meta$dimensions[[s$dim]] <- dim
  }
  ds
}

# ---- source label cleanup -----------------------------------------------------
# Some FSO codelists ship labels in print style: the code in front of the text,
# and the NOGA sections in capitals ("G WHOLESALE AND RETAIL TRADE; ..."). The
# fetcher calls tidy_level_labels() on such a dimension; the labels stay
# source-derived, only their form changes. Opt-in per fetcher: stripping a code
# prefix everywhere would also cut real words (SNB "CHF Swiss Confederation bond
# issues").
#
# Capitals are recased word by word. A word found in the level's `case_ref` (the
# same label in proper case from another source, e.g. Eurostat NACE) takes that
# casing; roman numerals stay; any other word is lowercased, or capitalised in
# German, where it is most likely a noun. The first letter is then capitalised.
# German without a reference is left in capitals: nouns vs adjectives cannot be
# told apart mechanically.

.ROMAN <- "^(I|II|III|IV|V|VI|VII|VIII|IX|X)$"

.is_caps <- function(x) {
  !grepl("[[:lower:]]", x) && nchar(gsub("[^[:alpha:]]", "", x)) >= 4L
}

.upper_first <- function(x) sub("^([^[:alpha:]]*)([[:alpha:]])", "\\1\\U\\2", x, perl = TRUE)

# A word without its trailing , ; : . (the part that gets recased).
.word_core <- function(w) sub("[,;:.]+$", "", w)

.recase <- function(x, lang, ref = NULL) {
  if (is.null(ref) && identical(lang, "de")) return(x)
  words <- strsplit(x, " ", fixed = TRUE)[[1]]
  ref_words <- if (is.null(ref)) character(0) else .word_core(strsplit(ref, " ", fixed = TRUE)[[1]])
  ref_map <- setNames(ref_words, tolower(ref_words))
  out <- vapply(words, function(w) {
    core <- .word_core(w)
    tail <- substring(w, nchar(core) + 1L)
    hit <- ref_map[tolower(core)]
    core <- if (!is.na(hit)) unname(hit)
            else if (grepl(.ROMAN, core)) core
            else if (identical(lang, "de")) .upper_first(tolower(core))
            else tolower(core)
    paste0(core, tail)
  }, "", USE.NAMES = FALSE)
  .upper_first(paste(out, collapse = " "))
}

# One label string: drop a leading "<code> ", squeeze spaces, recase capitals.
tidy_label <- function(x, code, lang, ref = NULL) {
  x <- gsub("\\s+", " ", trimws(x))
  if (startsWith(x, paste0(code, " "))) x <- substring(x, nchar(code) + 2L)
  if (.is_caps(x)) x <- .recase(x, lang, ref)
  x
}

# Every level label of one dimension. `case_ref`: optional lang -> (code -> label)
# lookup in proper case.
tidy_level_labels <- function(dim, case_ref = NULL) {
  for (code in names(dim$levels)) {
    lab <- dim$levels[[code]]$label
    for (L in names(lab))
      lab[[L]] <- tidy_label(lab[[L]], code, L, case_ref[[L]][[code]])
    dim$levels[[code]]$label <- lab
  }
  dim
}
