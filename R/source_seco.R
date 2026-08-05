# SECO fetcher — SECO already PUBLISHES the swissdata format directly, so this is
# essentially a passthrough: download the long CSV (already
# `structure,type,seas_adj,date,value`) + the rich JSON meta sidecar, and remap
# the swissdata meta into our contract's `dimensions` shape.
#
# 2026-06: SECO migrated its website and RETIRED the old
# www.seco.admin.ch/dam/...download URLs (they now 502). The machine-readable
# files are delivered via scheduler.swissdatas.ch, linked from the new short
# pages seco.admin.ch/{gross-domestic-product,consumer-sentiment,wea}.
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
                       data_url = "https://scheduler.swissdatas.ch/scheduled/ch-seco-gdp.csv",
                       meta_url = "https://scheduler.swissdatas.ch/scheduled/ch-seco-gdp.json") {

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
    # Canonical units shape (contract §2): keyed by the unit-bearing dimension's
    # LEVELS directly. SECO's native sidecar nests one dimension layer above that
    # ({type: {nom: …}}); lift it off when present (schema 1.1 normalisation).
    units = if (length(sm$units) == 1 && !is.null(names(sm$units)) &&
                names(sm$units) %in% (sm$dim_order %||% character(0)))
              sm$units[[1]] else sm$units,
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


# SECO Weekly Economic Activity (WEA / WWA), weekly. Like seco_fetch this reads
# the SECO swissdata long CSV directly. SECO now also publishes a JSON meta
# sidecar (scheduler.swissdatas.ch/scheduled/ch-seco-wwa.json), but the two
# series + units are stable, so we keep building the contract's `dimensions` by
# hand. The `structure` dimension carries two series: the headline WEA index
# (`seco_wwa`, 2005->) and a discontinued pre-crisis-level variant
# (`seco_wwa_pre_covid`, 2019-2022). `type` (index) and `seas_adj` (csa) are
# constant in the CSV, so we keep only `structure`; (structure, date) is already
# unique. Values are scaled YoY GDP growth rates (a level, not a rate to be
# re-differenced) -> transform=level.
seco_wwa_fetch <- function(id = "ch_seco_wwa",
                           data_url = "https://scheduler.swissdatas.ch/scheduled/wwa.csv") {

  raw <- readr::read_csv(data_url, show_col_types = FALSE)
  raw_periods <- as.character(raw$date)
  data <- raw |>
    dplyr::mutate(date = as.Date(to_iso(as.character(date))),
                  value = as.numeric(value)) |>
    dplyr::filter(!is.na(value)) |>
    dplyr::select(dplyr::all_of(c("structure", "date", "value"))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c("structure", "date"))))

  meta <- list(
    source = list(url = "https://www.seco.admin.ch/wea"),
    license = "seco",
    frequency = infer_frequency(raw_periods),
    # labels + units: datasheet ## Labels block
    dimensions = list(
      structure = list(
        levels = list(seco_wwa = list(), seco_wwa_pre_covid = list())
      )
    ),
    notes = paste0("Weekly indicator published by SECO. The headline series ",
                   "(seco_wwa) runs from 2005; seco_wwa_pre_covid is a ",
                   "discontinued variant (2019-2022) measuring activity relative ",
                   "to the Q4 2019 level.")
  )

  list(id = id, data = data, meta = meta)
}