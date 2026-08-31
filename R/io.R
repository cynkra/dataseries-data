# Write a dataset to the contract: one long CSV + one JSON meta sidecar (+ Parquet).
# Contract: spec/data-pipeline/2-format-contract.md
#
# A "dataset" here is a list(id=, data=<tibble: dim cols + date + value>, meta=<list>).
# write_dataset() emits {id}.csv, {id}.json, {id}.parquet; catalog_entry() builds
# the catalog.json row.

suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
})

dim_cols <- function(data) setdiff(names(data), c("date", "value"))

# Read the curation fields from a dataset's datasheet (datasets/<id>.md), which is
# the source of truth for curation. The catalog derives these fields from the
# markdown rather than duplicating them in code. Returns an empty list if there is
# no datasheet. Syntax (sections, fields, the i18n value grammar) lives in
# R/datasheet.R; this function is pure SEMANTICS: which field means what.
# `lines` lets a caller that already ds_read() the file avoid a second read.
read_datasheet_meta <- function(id, datasheet_dir, lines = NULL) {
  lines <- lines %||% ds_read(id, datasheet_dir)
  if (is.null(lines)) return(list())
  top  <- ds_fields(ds_top(lines))                 # identity block
  disp <- ds_fields(ds_section(lines, "Display"))  # presentation block

  out <- list()
  if (!is.null(top$concept)) {
    out$concept <- top$concept
    # The website overview groups by the concept *Group* (the segment before the
    # first "/"). `topic` is the same grouping on the detail page / in search, so
    # we derive it from the concept here rather than keep a second, drift-prone
    # source in the parser code. modifyList() lets this override the parser topic.
    out$topic <- trimws(strsplit(top$concept, "/", fixed = TRUE)[[1]][1])
  }
  if (!is.null(top$canonical))
    out$canonical <- grepl("^yes", tolower(top$canonical))  # "no (alternate ...)" -> FALSE
  if (!is.null(top$featured)) out$featured <- top$featured  # homepage example label
  # Optional curated title: overrides the raw source title (which is often a verbose
  # SNB/FSO cube name). Single source of truth, like `featured` — set it only where
  # the source title needs cleaning up. i18n: "En title | de: … | fr: …".
  if (!is.null(top$title)) out$title <- ds_i18n(top$title)

  # Display block: presentation decisions the app derives from the datasheet
  # instead of guessing with code heuristics.
  if (!is.null(disp$split)) out$split <- disp$split
  if (!is.null(disp[["single-select"]]))
    out$single_select <- trimws(strsplit(disp[["single-select"]], ",")[[1]])
  if (!is.null(disp$transform)) out$default_transform <- disp$transform
  if (!is.null(disp[["percent-levels"]]))   # levels stored as a 0-1 share -> app shows as %
    out$percent_levels <- trimws(strsplit(disp[["percent-levels"]], ",")[[1]])
  if (!is.null(disp$default)) {
    kv <- list()
    for (p in trimws(strsplit(disp$default, ",")[[1]])) {
      if (grepl("=", p)) {
        parts <- strsplit(p, "=", fixed = TRUE)[[1]]
        kv[[trimws(parts[1])]] <- trimws(parts[2])
      }
    }
    if (length(kv)) out$default <- kv
  }

  # Description: the "## What is special" prose — the ONE datasheet section that is
  # published to users (page lede, <meta description>, JSON-LD). Translations live
  # in sibling sections at the end of the same file, "## What is special (de)" etc.,
  # so an English edit and a stale translation show up in the same diff. Every other
  # prose section (Access, Parsing recipe, Dimensions, Caveats, Provenance) is
  # internal and stays English.
  desc <- ds_prose(lines, "What is special")
  if (!is.null(desc)) {
    obj <- list(en = desc)
    for (L in DS_I18N_LANGS) {
      tr <- ds_prose(lines, sprintf("What is special (%s)", L))
      if (!is.null(tr)) obj[[L]] <- tr
    }
    out$description <- obj
  }
  out
}

# ---- the parsed ## Access block ---------------------------------------------
# The access recipe is DECLARED in the datasheet (type slug + one canonical
# identifier per family); the pipeline reads it from here instead of repeating it
# in code — a wrong identifier now fails the fetch loudly instead of shipping a
# stale value (the CPI .67/.66 drift). Slug vocabulary + identifier keys:
# spec/multilingual/2-design.md §4 (dataseries.org repo).
DS_ACCESS_ID_KEYS <- list(
  "snb-cube"       = "cube",
  "fso-dam-excel"  = c("order number", "asset ids"),  # trade_partner pins asset ids
  "fso-dam-csv"    = "order number",
  "fso-dam-px"     = "table id",       # PX cube pulled from DAM, not PX-Web
  "fso-pxweb"      = "table id",
  "fso-sdmx"       = "flow",            # compact agency/dataflow/version
  "seco-swissdata" = "set",
  "kof-api"        = "key",
  "eurostat-sdmx"  = "dataflow",
  "scraped"        = "url"
)

# Parse a datasheet's ## Access block: list(type = <slug>, identifier = <string>,
# fields = <raw field list>), or NULL when there is no datasheet / no block.
# The type line is "<slug> — <free prose>"; identifier values may be written as
# `code` with a parenthetical tail, both stripped here.
read_access <- function(id, datasheet_dir, lines = NULL) {
  lines <- lines %||% ds_read(id, datasheet_dir)
  if (is.null(lines)) return(NULL)
  f <- ds_fields(ds_section(lines, "Access"))
  if (is.null(f$type)) return(NULL)
  slug <- trimws(sub("—.*$", "", f$type))   # slug — prose
  keys <- DS_ACCESS_ID_KEYS[[slug]]
  if (is.null(keys))
    stop(sprintf("%s: unknown access type slug '%s'", id, slug), call. = FALSE)
  ident <- NULL
  for (k in keys) if (!is.null(f[[k]])) { ident <- f[[k]]; break }
  clean <- function(v) gsub("`", "", trimws(sub("\\s*\\(.*$", "", v)))
  list(type = slug,
       identifier = if (is.null(ident)) NULL else clean(ident),
       fields = f)
}

# The sidecar/meta schema version. 1.1 = i18n label objects allowed on every
# curated string (catalog source/categories too) + shared sources.json /
# licenses.json vocabularies. Readers were widened first (app commit e40b231);
# see spec/multilingual/2-design.md §6.
DS_SCHEMA_VERSION <- "1.1"

# Shared cross-dataset vocabularies (data/sources.json, data/licenses.json) —
# hand-maintained files, the documented exception inside the generated data/.
ds_sources <- local({
  cache <- NULL
  function(data_dir) {
    if (is.null(cache)) cache <<- jsonlite::fromJSON(
      file.path(data_dir, "sources.json"), simplifyVector = FALSE)
    cache
  }
})

# data/categories.json — the overview grouping vocabulary (hand-maintained).
ds_categories <- local({
  cache <- NULL
  function(data_dir) {
    if (is.null(cache)) cache <<- jsonlite::fromJSON(
      file.path(data_dir, "categories.json"), simplifyVector = FALSE)
    cache
  }
})

# The concept's top group -> a STABLE category key + its i18n name. The website
# used to group datasets by matching the English `topic` string against the
# category NAME; translating the names broke that join (0/12 matched in German).
# Joining on a key instead makes the grouping language-independent by
# construction — the same "never join on display text" rule as everywhere else.
ds_topic_of <- function(group_en, data_dir) {
  for (c in ds_categories(data_dir))
    if (identical(c$name$en, group_en)) return(list(key = c$key, name = c$name))
  list(key = NA_character_, name = list(en = group_en))   # uncategorised, still renders
}

# data/vocab.json — display vocabulary shared across datasets (concept leaves,
# featured chip labels). Hand-maintained, like categories.json.
ds_vocab <- local({
  cache <- NULL
  function(data_dir) {
    if (is.null(cache)) {
      f <- file.path(data_dir, "vocab.json")
      cache <<- if (file.exists(f)) jsonlite::fromJSON(f, simplifyVector = FALSE) else list()
    }
    cache
  }
})

# "Group / Leaf" -> the leaf resolved to a label object; the group segment is
# already carried (translated) by meta$topic, so only the leaf needs lookup.
ds_concept_of <- function(concept_en, data_dir) {
  parts <- trimws(strsplit(concept_en, "/", fixed = TRUE)[[1]])
  leaf  <- if (length(parts) > 1) parts[2] else NA_character_
  lv    <- if (!is.na(leaf)) ds_vocab(data_dir)$leaves[[leaf]] else NULL
  list(en = concept_en, leaf = lv %||% (if (!is.na(leaf)) list(en = leaf) else NULL))
}

# Resolve the datasheet-declared vocab keys onto one dataset meta:
#   - **source**: <key>   -> meta$source$name from sources.json (+ $key; the
#                            fetcher's url survives, vocab url is the fallback)
#   - **license**: <key>  -> meta$license normalised to the bare key
# Both lines live in the datasheet top block; prose tails are ignored.
apply_vocab <- function(meta, lines, data_dir) {
  f <- ds_fields(ds_top(lines))
  if (is.character(meta$topic) && nzchar(meta$topic))
    meta$topic <- ds_topic_of(meta$topic, data_dir)
  if (is.character(meta$concept) && nzchar(meta$concept))
    meta$concept <- ds_concept_of(meta$concept, data_dir)
  if (is.character(meta$featured) && nzchar(meta$featured))
    meta$featured <- ds_vocab(data_dir)$featured[[meta$featured]] %||% list(en = meta$featured)
  lic <- sub("\\s.*$", "", f$license %||% "")
  if (nzchar(lic)) meta$license <- lic
  key <- sub("\\s.*$", "", f$source %||% "")
  if (nzchar(key)) {
    vocab <- ds_sources(data_dir)[[key]]
    if (is.null(vocab))
      stop(sprintf("unknown source key '%s' (not in data/sources.json)", key), call. = FALSE)
    src <- meta$source %||% list()
    src$name <- vocab$name
    src$url <- src$url %||% vocab$url
    src$key <- key
    meta$source <- src[c(intersect(c("name", "url"), names(src)),
                         setdiff(names(src), c("name", "url", "key")), "key")]
  }
  meta
}

# The SNB-silent-fallback guard: a non-German language whose labels are
# byte-identical to German across an ENTIRE dimension (>= 3 distinct German
# values, so tiny dims can't trigger it) is an echo, not a translation — the
# upstream API fell back without saying so (SNB does this for Italian, HTTP 200).
# Contract rule: omit a language rather than stub it, so the echo is dropped.
drop_lang_echo <- function(dimensions) {
  for (d in names(dimensions)) {
    lv <- dimensions[[d]]$levels
    if (is.null(lv) || !length(lv)) next
    de <- vapply(lv, function(x) x$label$de %||% NA_character_, "")
    if (length(unique(de[!is.na(de)])) < 3) next
    for (L in c("fr", "it")) {
      other <- vapply(lv, function(x) x$label[[L]] %||% NA_character_, "")
      have <- !is.na(de) & !is.na(other)
      if (!any(have) || !all(other[have] == de[have])) next
      for (code in names(lv)) dimensions[[d]]$levels[[code]]$label[[L]] <- NULL
      if (!is.null(dimensions[[d]]$label[[L]])) dimensions[[d]]$label[[L]] <- NULL
      message(sprintf("    dropped '%s' labels on dim '%s': byte-identical to 'de' (upstream fallback)", L, d))
    }
  }
  dimensions
}

# Add `$data = TRUE/FALSE` to every level of every dimension, flagging whether
# that code actually appears in the data (vs being a grouping-only hierarchy
# node). Dimension-agnostic; a no-op for datasets without dimensions (e.g. KOF).
annotate_levels_with_data <- function(dimensions, data, dc) {
  for (d in dc) {
    if (is.null(dimensions[[d]]$levels)) next
    present <- unique(as.character(data[[d]]))
    for (code in names(dimensions[[d]]$levels)) {
      dimensions[[d]]$levels[[code]]$data <- code %in% present
    }
  }
  dimensions
}

# A guaranteed-valid default series: the dim-value combination with the most
# observations (usually the headline/total, spanning the full history). Hierarchy
# roots are frequently grouping-only nodes with no data, so the website can't just
# default to the first level — it would open on an empty chart. Returns a named
# list dim -> code, or NULL for a single-series (no-dimension) dataset.
default_selection <- function(data, dc) {
  if (!length(dc)) return(NULL)
  combo <- data |>
    dplyr::count(dplyr::across(dplyr::all_of(dc)), name = ".n") |>
    dplyr::slice_max(.n, n = 1, with_ties = FALSE)
  lapply(dc, function(d) as.character(combo[[d]][1]))  |> setNames(dc)
}

n_series <- function(data) {
  dc <- dim_cols(data)
  if (length(dc) == 0) return(1L)
  nrow(dplyr::distinct(dplyr::select(data, dplyr::all_of(dc))))
}

# Structural contract check run on EVERY freshly-fetched dataset (via .try_fetch).
# Fails LOUD on the signatures of a broken parse — empty data, NA/implausible
# dates (e.g. an Excel serial-origin bug), non-numeric or all-NA values, or
# duplicate (dims, date) keys (a cartesian/positional-parse explosion). A failure
# skips just that dataset (logged in skips.jsonl, flagged stale by health.R)
# instead of silently shipping wrong numbers. Dataset-specific VALUE anchors (the
# defence against a silent column/row shift that keeps the shape intact) live in
# the individual parsers; this is the source-agnostic safety net underneath them.
validate_dataset <- function(ds) {
  id  <- ds$id %||% "?"
  d   <- ds$data
  bad <- function(msg) stop(sprintf("validate_dataset(%s): %s", id, msg), call. = FALSE)
  if (is.null(d) || !nrow(d))                  bad("no data rows")
  if (!all(c("date", "value") %in% names(d)))  bad("missing date/value column")
  if (!inherits(d$date, "Date"))               bad("date column is not a Date")
  if (anyNA(d$date))                           bad("NA dates present")
  if (!is.numeric(d$value))                    bad("value column is not numeric")
  if (all(is.na(d$value)))                     bad("all values are NA")
  rng <- range(d$date)
  if (rng[1] < as.Date("1700-01-01") || rng[2] > as.Date("2100-01-01"))
    bad(sprintf("implausible date range %s .. %s (date-parse / serial-origin bug?)", rng[1], rng[2]))
  dc  <- dim_cols(d)
  key <- if (length(dc))
    do.call(paste, c(lapply(dc, function(c) as.character(d[[c]])), list(as.character(d$date)), sep = "\r"))
  else as.character(d$date)
  if (anyDuplicated(key))
    bad(sprintf("%d duplicate (dims, date) rows (cartesian / positional-parse bug?)", sum(duplicated(key))))
  invisible(ds)
}

write_dataset <- function(ds, out_dir) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  dc <- dim_cols(ds$data)
  data <- ds$data |>
    dplyr::select(dplyr::all_of(c(dc, "date", "value"))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c(dc, "date"))))

  readr::write_csv(data, file.path(out_dir, paste0(ds$id, ".csv")))
  arrow::write_parquet(data, file.path(out_dir, paste0(ds$id, ".parquet")))

  # Mark which dimension levels actually occur in the data. Hierarchical dims
  # (e.g. SECO `structure`) carry interior grouping nodes — gdp > production >
  # gva > … — and the parent category nodes (production/expenditure/income)
  # have no series of their own. The website needs this to render those nodes as
  # non-selectable headers in the drill-down tree rather than empty series.
  ds$meta$dimensions <- annotate_levels_with_data(ds$meta$dimensions, data, dc)
  # Honor a datasheet-declared opening default (from the ## Display block); fall
  # back to the most-observations heuristic only when the datasheet doesn't say.
  if (is.null(ds$meta$default)) ds$meta$default <- default_selection(data, dc)

  # When WE last wrote this dataset to disk (UTC), independent of the source's own
  # publish date (`updated`). Lets "last fetched" work for every dataset, incl. the
  # SNB cubes whose source carries no usable publish timestamp. Stamped into ds$meta
  # so catalog_entry(ds) on the same in-memory object picks it up too.
  ds$meta$fetched_utc <- format(Sys.time(), tz = "UTC", "%Y-%m-%d %H:%M:%S")

  span <- range(data$date)
  meta <- c(
    list(
      schema_version = DS_SCHEMA_VERSION,
      id = ds$id,
      dim_order = as.list(dc),
      start = as.character(span[1]),
      end = as.character(span[2])
    ),
    ds$meta
  )
  writeLines(
    jsonlite::toJSON(meta, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    file.path(out_dir, paste0(ds$id, ".json"))
  )
  invisible(ds)
}

catalog_entry <- function(ds) {
  span <- range(ds$data$date)
  m <- ds$meta
  # schema 1.1: the full i18n name object (+ vocab key); legacy bare string only
  # when no vocab key was resolved (a dataset without a datasheet).
  src <- if (!is.null(m$source$key)) list(key = m$source$key, name = m$source$name)
         else m$source$name$en %||% m$source$name %||% NA_character_
  list(
    id = ds$id,
    title = m$title,
    concept = m$concept %||% NA_character_,
    canonical = m$canonical %||% NA,
    featured = m$featured %||% NA_character_,
    topic = m$topic %||% NA_character_,
    source = src,
    license = m$license %||% NA_character_,
    frequency = m$frequency %||% NA_character_,
    start = as.character(span[1]),
    end = as.character(span[2]),
    n_series = n_series(ds$data),
    updated = m$updated %||% NA_character_,
    fetched = m$fetched_utc %||% NA_character_,
    load = m$load %||% "whole",
    data = paste0(ds$id, ".csv"),
    meta = paste0(ds$id, ".json")
  )
}

write_catalog <- function(datasets, out_dir) {
  cat_list <- lapply(datasets, catalog_entry)
  writeLines(
    jsonlite::toJSON(cat_list, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    file.path(out_dir, "catalog.json")
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a
