# KOF Time Series Database API v2 fetcher (tsdb-api.kof.ethz.ch).
#
# A KOF key (e.g. "ch.kof.barometer") is a single series -> a dataset with no
# dimension columns, just date/value. License: CC BY.
#
# v1 (datenservice.kof.ethz.ch/api/v1/...) was DISCONTINUED (301 + a JSON
# "migrate to v2" body on every path; it broke the 2026-07 runs). In v2 the
# anonymous path is the `access_type=public` query parameter -- without it the
# request is redirected to KOF's Keycloak login. Response shapes are unchanged
# from v1, so the parsers below are untouched by the migration.

suppressPackageStartupMessages(library(dplyr))

KOF_API <- "https://tsdb-api.kof.ethz.ch/v2"

# Read a KOF CSV payload. read_csv() treats a bare one-line string as a *file
# path*, so the discontinued-v1 JSON error body surfaced as the useless
# "'{\"message\":...}' does not exist in current working directory". I() forces
# literal-data parsing, and the shape check turns any future non-CSV body
# (error JSON, HTML login page) into a message that names the endpoint.
kof_read_csv <- function(url) {
  txt <- get_text(url)
  if (!grepl("^\\s*date[,;]", txt)) {
    stop("KOF API did not return CSV for ", url, ": ", substr(txt, 1, 200))
  }
  readr::read_csv(I(txt), show_col_types = FALSE)
}

kof_fetch <- function(key, title = NULL) {
  url <- sprintf("%s/ts?keys=%s&mime=csv&access_type=public", KOF_API, key)
  raw <- kof_read_csv(url)
  value_col <- setdiff(names(raw), "date")[1]
  raw_periods <- as.character(raw$date)

  data <- raw |>
    dplyr::rename(value = dplyr::all_of(value_col)) |>
    dplyr::mutate(date = as.Date(to_iso(as.character(date))), value = as.numeric(value)) |>
    dplyr::select(date, value) |>
    dplyr::arrange(date)

  meta <- list(
    title = title %||% setNames(list(key), "en"),
    source = list(
      url = "https://kof.ethz.ch/en/forecasts-and-indicators/indicators/kof-economic-barometer.html"
    ),
    license = "kof",
    frequency = infer_frequency(raw_periods),
    dimensions = setNames(list(), character(0))
  )

  list(id = gsub(".", "_", key, fixed = TRUE), data = data, meta = meta)
}

# A KOF public OGD *collection* (v1 called it a "set", e.g. "ogd_ch.kof.esi") is a
# wide table: a `date` column plus one column per KOF series key. Collections owned
# by the `public` user are open (license CC BY). We pivot to the standard long
# contract with one dimension (`indicator`) carrying the series keys. Level labels
# are authored in the datasheet (the metadata API is English-only).
kof_set_fetch <- function(set, title = NULL, dim_name = "indicator",
                          source_url = NULL) {
  url <- sprintf(
    "%s/collections/public/%s/ts?mime=csv&access_type=public", KOF_API, set
  )
  raw <- kof_read_csv(url)
  raw_periods <- as.character(raw$date)

  data <- raw |>
    tidyr::pivot_longer(cols = -date, names_to = dim_name, values_to = "value") |>
    dplyr::mutate(date = as.Date(to_iso(as.character(date))),
                  value = suppressWarnings(as.numeric(value))) |>
    dplyr::filter(!is.na(value)) |>            # sets are wide+sparse: series start at different dates
    dplyr::select(dplyr::all_of(c(dim_name, "date", "value"))) |>
    dplyr::arrange(.data[[dim_name]], date)

  keys <- sort(unique(data[[dim_name]]))
  meta <- list(
    title = title %||% setNames(list(set), "en"),
    source = list(
      url = source_url %||% "https://kof.ethz.ch/en/forecasts-and-indicators/indicators.html"
    ),
    license = "kof",
    frequency = infer_frequency(raw_periods),
    dimensions = setNames(list(list(
      label = list(en = dim_name),
      levels = setNames(lapply(keys, function(k) list(label = list(en = k))), keys)
    )), dim_name)
  )
  list(id = gsub("ogd_ch.kof.", "ch_kof_", set, fixed = TRUE),
       data = data, meta = meta)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
