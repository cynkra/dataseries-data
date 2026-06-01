# SECO fetcher — SECO already PUBLISHES the swissdata format directly, so this is
# essentially a passthrough: download the long CSV (already
# `structure,type,seas_adj,date,value`) + the rich JSON meta sidecar, and remap
# the swissdata meta into our contract's `dimensions` shape.
#
# This is the rich, at-source dataset: multilingual (en/de/fr/it) labels AND a
# real production/expenditure/income hierarchy, all maintained by SECO. The
# hardest case for the UI (deep hierarchy) and the biggest dataset (~107k rows).

suppressPackageStartupMessages({
  library(dplyr)
})

# swissdata `labels` -> our `dimensions`.
#   labels$dimnames[[d]]      = {lang: dimension label}
#   labels[[d]][[code]]       = {lang: level label}
#   hierarchy[[d]]            = nested code tree
.seco_dimensions <- function(meta) {
  dim_order <- unlist(meta$dim_order)
  dimnames <- meta$labels$dimnames
  setNames(lapply(dim_order, function(d) {
    levels <- meta$labels[[d]]
    out <- list(
      label = dimnames[[d]],
      levels = setNames(lapply(names(levels), function(code) {
        list(label = levels[[code]])
      }), names(levels))
    )
    if (!is.null(meta$hierarchy[[d]])) out$hierarchy <- meta$hierarchy[[d]]
    out
  }), dim_order)
}

seco_fetch <- function(id = "ch_seco_gdp",
                       data_url = paste0(
                         "https://www.seco.admin.ch/dam/seco/en/dokumente/",
                         "Wirtschaft/Wirtschaftslage/BIP_Daten/",
                         "ch_seco_gdp_csv.csv.download.csv/ch_seco_gdp_csv.csv"),
                       meta_url = paste0(
                         "https://www.seco.admin.ch/dam/seco/en/dokumente/",
                         "Wirtschaft/Wirtschaftslage/BIP_Daten/",
                         "ch_seco_gdp_json.txt.download.txt/ch_seco_gdp_json.txt")) {

  sm <- jsonlite::fromJSON(meta_url, simplifyVector = FALSE)
  dim_order <- unlist(sm$dim_order)

  raw <- readr::read_csv(data_url, show_col_types = FALSE)
  raw_periods <- as.character(raw$date)
  data <- raw |>
    dplyr::mutate(date = as.Date(to_iso(as.character(date))),
                  value = as.numeric(value)) |>
    dplyr::select(dplyr::all_of(c(dim_order, "date", "value"))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c(dim_order, "date"))))

  meta <- list(
    title = sm$title,
    source = list(name = sm$source_name, url = sm$source_url[[1]] %||% sm$source_url),
    license = "seco",
    frequency = infer_frequency(raw_periods),
    dimensions = .seco_dimensions(sm),
    units = sm$units,
    updated = sm$updated_utc,
    notes = sm$details
  )
  # NOTE: the SECO source meta carries NO split/select UI hint (verified: its
  # keys are title/source_name/source_url/units/aggregate/dim_order/hierarchy/
  # labels/details/updated_utc — no `dataseries` block). So there is nothing to
  # pass through. The website infers the split/multi-select dimension as the one
  # that has a `hierarchy` (here: `structure`); the others are single-select.

  list(id = id, data = data, meta = meta)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
