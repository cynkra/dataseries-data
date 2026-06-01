# KOF Datenservice fetcher (datenservice.kof.ethz.ch public API).
#
# A KOF key (e.g. "ch.kof.barometer") is a single series -> a dataset with no
# dimension columns, just date/value. License: CC BY.

suppressPackageStartupMessages(library(dplyr))

kof_fetch <- function(key, title = NULL) {
  url <- sprintf(
    "https://datenservice.kof.ethz.ch/api/v1/public/ts?keys=%s&mime=csv", key
  )
  raw <- readr::read_csv(get_text(url), show_col_types = FALSE)
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
      name = list(en = "KOF Swiss Economic Institute"),
      url = "https://kof.ethz.ch/en/forecasts-and-indicators/indicators/kof-economic-barometer.html"
    ),
    license = "kof",
    frequency = infer_frequency(raw_periods),
    dimensions = setNames(list(), character(0))
  )

  list(id = gsub(".", "_", key, fixed = TRUE), data = data, meta = meta)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
