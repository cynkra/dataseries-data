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
