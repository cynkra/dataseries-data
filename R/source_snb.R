# SNB data portal fetcher (data.snb.ch cube API).
#
# One SNB cube -> one dataset. /data/json gives series whose metadata.key
# (e.g. "EPB@SNB.gdppn{WMF,AG}") carries the dimension-item codes in order;
# /dimensions maps codes -> human labels and carries the hierarchy (nested
# dimensionItems). We build a tidy long tibble keyed by SNB dim ids (D0,D1,..).

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

# code -> label, recursing into nested dimensionItems
.snb_flatten <- function(items) {
  out <- list()
  for (it in items) {
    out[[it$id]] <- it$name
    if (!is.null(it$dimensionItems)) {
      out <- c(out, .snb_flatten(it$dimensionItems))
    }
  }
  out
}

# nested code-tree mirroring SNB's dimensionItems nesting. Leaves map to an
# empty list (NOT NULL: `tree[[id]] <- NULL` deletes the key in R, which would
# drop every data-bearing leaf and leave only grouping nodes in the tree).
.snb_hierarchy <- function(items) {
  tree <- list()
  for (it in items) {
    tree[[it$id]] <- if (!is.null(it$dimensionItems)) {
      .snb_hierarchy(it$dimensionItems)
    } else {
      list()
    }
  }
  tree
}

.snb_key_codes <- function(key) {
  m <- regmatches(key, regexpr("\\{[^}]*\\}", key))
  if (length(m) == 0) return(character(0))
  inner <- gsub("[{}]", "", m)
  if (inner == "") character(0) else strsplit(inner, ",", fixed = TRUE)[[1]]
}

# Cheap freshness probe. SNB documents a `lastUpdate` method exactly for "find out if
# there are new data" (https://data.snb.ch/en/help_api): a ~65-byte JSON
#   {"editionDate":"20260521_0900","publicSinceDate":"20260521_0900"}
# vs the 0.2-1.1 MB data cube. `editionDate` (the edition's creation stamp; a revision
# bumps it) is the change signal; fall back to publicSinceDate. Returns a tidy
# "YYYY-MM-DD HH:MM" string -- which doubles as the meta `updated` field health.R reads
# (it parses `as.Date(substr(updated, 1, 10))`) -- or NA_character_ if unreadable, so a
# caller degrades to an unconditional fetch. Used as the conditional-fetch token AND to
# populate meta$updated (SNB carries no publish date in the data payload itself).
snb_last_update <- function(cube_id) {
  doc <- tryCatch(
    get_json(sprintf("https://data.snb.ch/api/cube/%s/lastUpdate", cube_id)),
    error = function(e) NULL
  )
  ed <- doc$editionDate %||% doc$publicSinceDate
  if (is.null(ed)) return(NA_character_)
  m <- regmatches(ed, regexec("^([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})$", ed))[[1]]
  if (length(m) == 6L) sprintf("%s-%s-%s %s:%s", m[2], m[3], m[4], m[5], m[6]) else ed
}

snb_fetch <- function(cube_id, title = NULL, langs = c("en", "de", "fr")) {
  base <- "https://data.snb.ch/api/cube"
  dims_doc <- get_json(sprintf("%s/%s/dimensions/%s", base, cube_id, "en"))
  data_doc <- get_json(sprintf("%s/%s/data/json/%s", base, cube_id, "en"))

  dims <- dims_doc$dimensions
  dim_ids <- vapply(dims, function(d) d$id, "")
  dim_names <- setNames(vapply(dims, function(d) d$name, ""), dim_ids)
  dim_labels <- setNames(
    lapply(dims, function(d) .snb_flatten(d$dimensionItems %||% list())), dim_ids
  )
  dim_trees <- setNames(
    lapply(dims, function(d) .snb_hierarchy(d$dimensionItems %||% list())), dim_ids
  )

  # Label translations: one extra ~50 KB /dimensions/{lang} doc per language (the
  # data cube itself is fetched once, in en). SNB has NO Italian — /dimensions/it
  # returns byte-identical German with HTTP 200 (verified 2026-08-05, see
  # spec/multilingual/1-feasibility-review.md §2) — so `it` is deliberately not in
  # the default. A failed language doc skips that language, never the dataset.
  xdims <- list()
  for (L in setdiff(langs, "en")) {
    doc <- tryCatch(get_json(sprintf("%s/%s/dimensions/%s", base, cube_id, L)),
                    error = function(e) NULL)
    if (is.null(doc)) next
    dl <- doc$dimensions
    ids <- vapply(dl, function(d) d$id, "")
    xdims[[L]] <- list(
      names = setNames(vapply(dl, function(d) d$name, ""), ids),
      labels = setNames(lapply(dl, function(d) .snb_flatten(d$dimensionItems %||% list())), ids)
    )
  }
  lab_of <- function(id, code = NULL) {
    per <- lapply(xdims, function(x)
      if (is.null(code)) x$names[[id]] else x$labels[[id]][[code]])
    ds_label_obj(if (is.null(code)) dim_names[[id]] else dim_labels[[id]][[code]],
                 de = per$de, fr = per$fr, it = per$it)
  }

  rows <- list()
  raw_periods <- character(0)
  for (ts in data_doc$timeseries) {
    codes <- .snb_key_codes(ts$metadata$key)
    base_row <- setNames(as.list(codes), dim_ids[seq_along(codes)])
    for (obs in ts$values) {
      if (is.null(obs$value)) next
      raw_periods <- c(raw_periods, obs$date)
      rows[[length(rows) + 1L]] <- c(
        base_row, list(date = obs$date, value = obs$value)
      )
    }
  }

  data <- dplyr::bind_rows(lapply(rows, as.data.frame, stringsAsFactors = FALSE)) |>
    dplyr::mutate(date = as.Date(to_iso(date)), value = as.numeric(value)) |>
    dplyr::select(dplyr::all_of(c(dim_ids, "date", "value"))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c(dim_ids, "date"))))

  dimensions <- setNames(lapply(dim_ids, function(id) {
    levels <- setNames(
      lapply(names(dim_labels[[id]]), function(code) list(label = lab_of(id, code))),
      names(dim_labels[[id]])
    )
    d <- list(label = lab_of(id), levels = levels)
    if (length(dim_trees[[id]]) > 0) d$hierarchy <- dim_trees[[id]]
    d
  }), dim_ids)

  meta <- list(
    # The curated title lives in the datasheet (all 38 SNB datasheets carry one);
    # the cube id is only the no-datasheet fallback. source$name resolves from the
    # sources.json vocabulary (apply_vocab), the url stays cube-specific.
    title = title %||% list(en = cube_id),
    source = list(
      url = sprintf("https://data.snb.ch/en/topics/snb/cube/%s", cube_id)
    ),
    license = "snb",
    frequency = infer_frequency(raw_periods),
    dimensions = dimensions
  )

  # Source publish date (SNB's `lastUpdate`). Stored so (a) the health board's
  # "recently republished => fresh" fallback works for SNB, and (b) the next run can
  # compare it to skip an unchanged cube. Omit the key entirely when unreadable (NULL
  # list elements drop from toJSON), matching the pre-existing no-`updated` shape.
  pub <- snb_last_update(cube_id)
  if (!is.na(pub)) meta$updated <- pub

  list(id = paste0("ch_snb_", cube_id), data = data, meta = meta)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
