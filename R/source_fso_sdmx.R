# FSO SDMX (disseminate.stats.swiss) fetcher.
#
# FSO migrated the turnover / production statistics (retail, industry,
# construction) off the dead PX-Web STAT-TAB onto an SDMX 2.1 REST endpoint at
# https://disseminate.stats.swiss/rest/ under agency CH1.KEU. This module is the
# SDMX sibling of source_fso.R (PX-Web) and source_fso_excel.R (DAM xlsx).
#
# Two halves:
#   1. data  — GET SDMX-CSV (Accept: application/vnd.sdmx.data+csv) from
#              .../rest/data/<agency>,<flow>,<version>/all?detail=dataonly.
#              The CSV has one column per DSD dimension (NOGA, ADJUSTMENT,
#              INDICATOR_KE, UNIT_MEASURE, FREQ) + TIME_PERIOD + OBS_VALUE. We map
#              TIME_PERIOD (YYYY-MM monthly / YYYY-Qn quarterly) to an ISO
#              first-of-period date via R/dates.R.
#   2. labels — GET the structure (Accept: application/vnd.sdmx.structure+json)
#              from .../rest/dataflow/<agency>/<flow>/<version>?references=all and
#              read the four enumerated codelists (CL_NOGA_KE, CL_INDICATOR_KE,
#              CL_SEASONAL_ADJUST, CL_PRICES_RESULT_TYPE) to turn dimension codes
#              into English labels, in the repo dimensions/levels meta shape so
#              write_dataset() consumes the result unchanged.
#
# get_text() in http.R sets no custom headers, so we build the httr2 requests here
# with the right Accept header, reusing .with_retry() from http.R for backoff.

suppressPackageStartupMessages({
  library(dplyr)
  library(httr2)
})

.SDMX_BASE <- "https://disseminate.stats.swiss/rest"

# The DSD dimensions we publish, in order (FREQ is dropped — constant per flow,
# already encoded as the frequency). Each maps to one enumerated codelist.
.SDMX_DIM_CODELISTS <- c(
  NOGA         = "CL_NOGA_KE",
  ADJUSTMENT   = "CL_SEASONAL_ADJUST",
  INDICATOR_KE = "CL_INDICATOR_KE",
  UNIT_MEASURE = "CL_PRICES_RESULT_TYPE"
)

# An httr2 GET with a given Accept header + the shared retry/backoff policy.
.sdmx_get <- function(url, accept) {
  request(url) |>
    req_headers(Accept = accept) |>
    req_timeout(120) |>
    .with_retry() |>
    req_perform()
}

# GET the SDMX-CSV data and return it as a tibble (dimension columns + TIME_PERIOD
# + OBS_VALUE). detail=dataonly drops attribute columns we don't need.
.sdmx_data <- function(agency, flow, version) {
  url <- sprintf("%s/data/%s,%s,%s/all?detail=dataonly", .SDMX_BASE, agency, flow, version)
  resp <- .sdmx_get(url, "application/vnd.sdmx.data+csv")
  readr::read_csv(resp_body_string(resp), show_col_types = FALSE,
                  col_types = readr::cols(.default = readr::col_character()))
}

# GET the structure and return a named list codelist_id -> (code -> english label).
# Only the four enumerated codelists we publish are read.
.sdmx_codelists <- function(agency, flow, version) {
  url <- sprintf("%s/dataflow/%s/%s/%s?references=all", .SDMX_BASE, agency, flow, version)
  resp <- .sdmx_get(url, "application/vnd.sdmx.structure+json")
  doc <- jsonlite::fromJSON(resp_body_string(resp), simplifyVector = FALSE)
  cls <- doc$data$codelists
  out <- list()
  for (cl in cls) {
    if (!cl$id %in% .SDMX_DIM_CODELISTS) next
    lbls <- list()
    for (code in cl$codes) {
      nm <- code$name %||% code$names$en %||% code$names[[1]] %||% code$id
      lbls[[code$id]] <- as.character(nm)
    }
    out[[cl$id]] <- lbls
  }
  out
}

# Build the contract `dimensions` meta for a set of dimension columns, using the
# codelist label maps. Only the codes actually present in `data` are emitted as
# levels (write_dataset() then flags `$data` per level; here every level is real).
.sdmx_dimensions <- function(data, dim_cols, codelists) {
  setNames(lapply(dim_cols, function(d) {
    clid <- .SDMX_DIM_CODELISTS[[d]]
    lbls <- codelists[[clid]]
    present <- unique(as.character(data[[d]]))
    list(
      label = list(en = d),
      levels = setNames(lapply(present, function(code) {
        list(label = list(en = unname(lbls[[code]] %||% code)))
      }), present)
    )
  }), dim_cols)
}

# Fetch one CH1.KEU SDMX flow into the dataset contract.
#
#   agency/flow/version  — e.g. "CH1.KEU", "DF_KEU_M1", "1.0.0"
#   title                — list(en=...) catalog title
#   noga_keep            — optional character vector: keep only these NOGA codes
#                          (the project stores a curated slice; the full flow spans
#                          every NOGA section). NULL keeps all.
fso_sdmx_fetch <- function(dataset_id, agency, flow, version, title = NULL,
                           noga_keep = NULL) {
  raw <- .sdmx_data(agency, flow, version)
  codelists <- .sdmx_codelists(agency, flow, version)

  dim_cols <- names(.SDMX_DIM_CODELISTS)  # NOGA, ADJUSTMENT, INDICATOR_KE, UNIT_MEASURE
  stopifnot(all(c(dim_cols, "TIME_PERIOD", "OBS_VALUE") %in% names(raw)))

  periods <- as.character(raw$TIME_PERIOD)
  data <- raw |>
    dplyr::transmute(
      NOGA = as.character(NOGA),
      ADJUSTMENT = as.character(ADJUSTMENT),
      INDICATOR_KE = as.character(INDICATOR_KE),
      UNIT_MEASURE = as.character(UNIT_MEASURE),
      date = as.Date(to_iso(as.character(TIME_PERIOD))),
      value = suppressWarnings(as.numeric(OBS_VALUE))
    ) |>
    dplyr::filter(!is.na(value))

  if (!is.null(noga_keep)) {
    data <- dplyr::filter(data, NOGA %in% noga_keep)
  }

  data <- data |>
    dplyr::select(dplyr::all_of(c(dim_cols, "date", "value"))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c(dim_cols, "date"))))

  meta <- list(
    title = title %||% setNames(list(flow), "en"),
    source = list(
      name = list(en = "Swiss Federal Statistical Office (FSO)"),
      url = sprintf("https://www.bfs.admin.ch/asset/en/%s", flow)
    ),
    license = "fso",
    frequency = infer_frequency(periods),
    dimensions = .sdmx_dimensions(data, dim_cols, codelists)
  )

  list(id = dataset_id, data = data, meta = meta)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
