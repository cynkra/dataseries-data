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

# Read concept + canonical from a dataset's datasheet (datasets/<id>.md), which is
# the source of truth for curation. The catalog derives these fields from the
# markdown rather than duplicating them in code. Returns list(concept=, canonical=)
# or an empty list if there is no datasheet.
read_datasheet_meta <- function(id, datasheet_dir) {
  f <- file.path(datasheet_dir, paste0(id, ".md"))
  if (!file.exists(f)) return(list())
  lines <- readLines(f, warn = FALSE)
  pick <- function(key) {
    pat <- sprintf("^- \\*\\*%s\\*\\*:", key)
    hit <- grep(pat, lines, value = TRUE)
    if (!length(hit)) return(NULL)
    trimws(sub(sprintf("^- \\*\\*%s\\*\\*:\\s*", key), "", hit[1]))
  }
  out <- list()
  concept <- pick("concept")
  if (!is.null(concept)) out$concept <- concept
  canon <- pick("canonical")
  if (!is.null(canon)) out$canonical <- grepl("^yes", tolower(canon))  # "no (alternate ...)" -> FALSE
  feat <- pick("featured")
  if (!is.null(feat)) out$featured <- feat  # homepage example label, e.g. "Inflation"

  # Display block: presentation decisions the app derives from the datasheet
  # instead of guessing with code heuristics.
  split <- pick("split")
  if (!is.null(split)) out$split <- split
  ss <- pick("single-select")
  if (!is.null(ss)) out$single_select <- trimws(strsplit(ss, ",")[[1]])
  tr <- pick("transform")
  if (!is.null(tr)) out$default_transform <- tr
  def <- pick("default")
  if (!is.null(def)) {
    kv <- list()
    for (p in trimws(strsplit(def, ",")[[1]])) {
      if (grepl("=", p)) {
        parts <- strsplit(p, "=", fixed = TRUE)[[1]]
        kv[[trimws(parts[1])]] <- trimws(parts[2])
      }
    }
    if (length(kv)) out$default <- kv
  }
  out
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
      schema_version = "1.0",
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
  src <- m$source$name$en %||% m$source$name %||% NA_character_
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
