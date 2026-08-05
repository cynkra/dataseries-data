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
# `lang` sets Accept-Language: disseminate.stats.swiss serves its structure
# (codelist names) localized per header — verified de/fr/it on CL_NOGA_KE.
.sdmx_get <- function(url, accept, lang = NULL) {
  req <- request(url) |> req_headers(Accept = accept)
  if (!is.null(lang)) req <- req |> req_headers(`Accept-Language` = lang)
  req |>
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

# GET the structure once per language and return a named list
# codelist_id -> (code -> i18n label object). Only the four enumerated codelists
# we publish are read; a failed non-en language skips that language.
.sdmx_codelists <- function(agency, flow, version) {
  url <- sprintf("%s/dataflow/%s/%s/%s?references=all", .SDMX_BASE, agency, flow, version)
  read_one <- function(lang) {
    resp <- .sdmx_get(url, "application/vnd.sdmx.structure+json",
                      lang = if (lang == "en") NULL else lang)
    doc <- jsonlite::fromJSON(resp_body_string(resp), simplifyVector = FALSE)
    out <- list()
    for (cl in doc$data$codelists) {
      if (!cl$id %in% .SDMX_DIM_CODELISTS) next
      lbls <- list()
      for (code in cl$codes) {
        nm <- code$name %||% code$names[[lang]] %||% code$names[[1]] %||% code$id
        lbls[[code$id]] <- as.character(nm)
      }
      out[[cl$id]] <- lbls
    }
    out
  }
  base <- read_one("en")
  out <- lapply(base, function(lbls) lapply(lbls, function(l) list(en = l)))
  for (L in c("de", "fr", "it")) {
    loc <- tryCatch(read_one(L), error = function(e) NULL)
    if (is.null(loc)) next
    for (clid in names(out)) for (code in names(out[[clid]])) {
      v <- loc[[clid]][[code]]
      if (!is.null(v) && nzchar(v)) out[[clid]][[code]][[L]] <- v
    }
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
        list(label = lbls[[code]] %||% list(en = code))
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
    title = title %||% list(en = flow),   # curated title = the datasheet's
    source = list(
      url = sprintf("https://www.bfs.admin.ch/asset/en/%s", flow)
    ),
    license = "fso",
    frequency = infer_frequency(periods),
    dimensions = .sdmx_dimensions(data, dim_cols, codelists)
  )

  list(id = dataset_id, data = data, meta = meta)
}

# ---- sliced SDMX (for cubes too big to pull whole) ---------------------------
# fso_sdmx_fetch() above pulls an entire flow (fine for CH1.KEU). Other flows —
# vehicle registrations, vacant dwellings — are millions of rows at canton/
# municipality granularity, so we pull a single pre-sliced KEY pinned to the
# national total instead. Returns a tidy data.frame of the requested dim columns
# + date + value; the per-dataset wrapper selects the meaningful dim and attaches
# meta. `key` is the dot-separated SDMX key in DSD dimension order ("" segment =
# all of that dim).
sdmx_sliced <- function(agency, flow, version, key, dim_cols) {
  url  <- sprintf("%s/data/%s,%s,%s/%s?detail=dataonly", .SDMX_BASE, agency, flow, version, key)
  resp <- .sdmx_get(url, "application/vnd.sdmx.data+csv")
  raw  <- as.data.frame(readr::read_csv(resp_body_string(resp), show_col_types = FALSE,
            col_types = readr::cols(.default = readr::col_character())))
  stopifnot(all(c(dim_cols, "TIME_PERIOD", "OBS_VALUE") %in% names(raw)))
  out <- raw[, dim_cols, drop = FALSE]
  out$date  <- as.Date(to_iso(as.character(raw$TIME_PERIOD)))
  out$value <- suppressWarnings(as.numeric(raw$OBS_VALUE))
  out <- out[!is.na(out$value) & !is.na(out$date), , drop = FALSE]
  out[order(out$date), , drop = FALSE]
}

# New registrations of passenger cars, national monthly, split by fuel (the
# EV-transition overlay). Pinned: Switzerland total, owner total, NEW vehicles,
# passenger cars. SDMX CH1.MFZ_IVS / DF_IVS_0_GENERAL_M.
fso_sdmx_new_vehicles <- function(dataset_id = "ch_fso_new_vehicles") {
  d <- sdmx_sliced("CH1.MFZ_IVS", "DF_IVS_0_GENERAL_M", "1.0.0", "_T._T.N.100..M",
    c("UV_HGDE_KT", "UV_RV_OWNER_TYPE", "UV_RV_REGISTRATION_TYPE",
      "UV_RV_VEHICLE_GROUP_AND_TYPE", "UV_RV_FUEL", "FREQ"))
  data <- data.frame(fuel = d$UV_RV_FUEL, date = d$date, value = d$value, stringsAsFactors = FALSE)
  data <- data[order(data$fuel, data$date), ]

  # Curated fuel codes + display order; the labels live in the datasheet
  # ## Labels block (attach_labels), not here.
  fuel_codes <- c("_T", "PC", "PH", "DC", "DH", "HP", "HD", "EL", "FC", "GA", "_O", "NM")
  fuel_codes <- fuel_codes[fuel_codes %in% unique(data$fuel)]
  levels <- setNames(lapply(fuel_codes, function(x) list()), fuel_codes)
  kids   <- setNames(lapply(setdiff(fuel_codes, "_T"), function(x) list()),
                     setdiff(fuel_codes, "_T"))

  meta <- list(
    source = list(url = "https://www.bfs.admin.ch/asset/en/px-x-1103020200_120"),
    license = "fso", frequency = "monthly", topic = "Mobility",
    dimensions = list(fuel = list(
      levels = levels,
      hierarchy = list("_T" = kids)   # Total decomposes into the fuel types
    ))
  )
  list(id = dataset_id, data = data, meta = meta)
}

# Vacant dwellings, national annual: count + the official vacancy rate
# (Leerwohnungsziffer). SDMX CH1.LWZ / DF_LWZ_1, sliced to Switzerland total.
fso_sdmx_vacant_dwellings <- function(dataset_id = "ch_fso_vacant_dwellings") {
  d <- sdmx_sliced("CH1.LWZ", "DF_LWZ_1", "1.0.0", "8100._T._T.V+PC.A",
    c("GR_KT_GDE", "WOHN_ANZAHL", "LEERWOHN_TYP", "MEASURE_DIMENSION", "FREQ"))
  data <- data.frame(measure = d$MEASURE_DIMENSION, date = d$date, value = d$value,
                     stringsAsFactors = FALSE)
  data <- data[order(data$measure, data$date), ]

  meta <- list(
    source = list(url = "https://www.bfs.admin.ch/asset/en/px-x-0902020100_104"),
    license = "fso", frequency = "annual", topic = "Construction and housing",
    dimensions = list(measure = list(
      levels = list(
        PC = list(),
        V  = list()
      )
    ))
  )
  list(id = dataset_id, data = data, meta = meta)
}

# Foreign cross-border commuters (Grenzgaenger), quarterly, by canton of work.
# SDMX CH1.GGS / DF_GGS_1, DSD order NOGA.CNTRY.FREQ.SEX.WORK_CANTON; sliced to the
# national total over NOGA/country/sex, leaving the 26-canton breakdown (+ _T total).
# Model-based estimate, so values are NON-integer; do not round.
fso_sdmx_cross_border_commuters <- function(dataset_id = "ch_fso_cross_border_commuters") {
  d <- sdmx_sliced("CH1.GGS", "DF_GGS_1", "1.0.0", "_T._T.Q._T.",
                   c("NOGA", "CNTRY", "FREQ", "SEX", "WORK_CANTON"))
  data <- data.frame(canton = d$WORK_CANTON, date = d$date, value = d$value,
                     stringsAsFactors = FALSE)
  data <- data[order(data$canton, data$date), , drop = FALSE]

  # Standard BFS canton numbering (1=ZH .. 26=JU); _T = Switzerland total.
  # Canton display labels live in the datasheet ## Labels block.
  present <- unique(as.character(data$canton))
  levels <- setNames(lapply(present, function(x) list()), present)
  kids <- setdiff(present, "_T")

  meta <- list(
    source = list(url = "https://www.bfs.admin.ch/asset/en/px-x-0302010000_101"),
    license = "fso", frequency = "quarterly", topic = "Labour",
    dimensions = list(canton = list(
      levels = levels,
      hierarchy = if (length(kids)) list("_T" = setNames(lapply(kids, function(x) list()), kids))
    ))
  )
  list(id = dataset_id, data = data, meta = meta)
}

# Detailed permanent resident population by nationality x sex, annual (STATPOP).
# SDMX CH1.STATPOP / DF_STATPOP_REGLING, DSD order
# POPULATION_TYPE.REG_LING.NATIONALITY_CATEGORY.SEX.AGE.FREQ; sliced to permanent
# residents, all language regions, age total, annual. Concept-distinct from
# ch_fso_pop (the 1861- demographic balance) — this is the recent nationality/sex
# stock. Value = year-end stock.
fso_sdmx_pop_detail <- function(dataset_id = "ch_fso_pop_detail") {
  d <- sdmx_sliced("CH1.STATPOP", "DF_STATPOP_REGLING", "1.0.0", "1._T..._T.A",
                   c("POPULATION_TYPE", "REG_LING", "NATIONALITY_CATEGORY", "SEX", "AGE", "FREQ"))
  data <- data.frame(nationality = d$NATIONALITY_CATEGORY, sex = d$SEX,
                     date = d$date, value = d$value, stringsAsFactors = FALSE)
  data <- data[order(data$nationality, data$sex, data$date), , drop = FALSE]

  # Total-first level order; the labels live in the datasheet ## Labels block.
  mk <- function(present, total = "_T") {
    keys <- intersect(c(total, setdiff(present, total)), present)
    levels <- setNames(lapply(keys, function(x) list()), keys)
    kids <- setdiff(keys, total)
    list(levels = levels,
         hierarchy = if (length(kids)) setNames(list(setNames(lapply(kids, function(x) list()), kids)), total))
  }

  meta <- list(
    source = list(url = "https://www.bfs.admin.ch/asset/en/px-x-0102010000_101"),
    license = "fso", frequency = "annual", topic = "Population",
    dimensions = list(
      nationality = mk(unique(as.character(data$nationality))),
      sex         = mk(unique(as.character(data$sex)))
    )
  )
  list(id = dataset_id, data = data, meta = meta)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
