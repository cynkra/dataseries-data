# FFA / EFV public-finance fetcher (opendata.swiss CKAN -> data.finance.admin.ch).
#
# Source: the Federal Finance Administration (FFA / Eidg. Finanzverwaltung EFV)
# publishes the headline general-government finance statistics on opendata.swiss as
# the dataset "Main aggregates and forecasts with FS- and GFS-Model"
# (CKAN id: hauptaggregate-und-prognosen-im-fs-und-gfs-modell). Behind it is a
# single tidy CSV asset:
#   https://www.data.finance.admin.ch/static/assets/datasets/fs_dashboard/main_extern.csv
#
# The CSV is already long: one row per (hh, model, variable, jahr) with a `value`
# and a `source` flag. We map it to the repo contract (dim cols + date + value),
# building English dimension/level labels in the same dimensions/levels meta shape
# as source_fso_sdmx.R / source_seco.R so write_dataset() consumes it unchanged.
#
# Dimensions we publish (German source codes -> English labels in meta):
#   level     hh   = government level (general government / Confederation / cantons /
#                    communes / social security, plus the cantons+communes aggregate)
#   model     model= accounting framework: FS (financial-statistics / administrative)
#                    vs GFS (Government Finance Statistics, Maastricht/SNA basis)
#   indicator variable = the headline aggregate (revenue, expenditure, balance,
#                    gross / net debt, and the GDP ratios)
#   estimate  source = whether the year is an actual (financial statement),
#                    provisional, budget/financial-plan, or forecast figure
#
# The WAF in front of data.finance.admin.ch rejects bare programmatic requests, so
# we send browser-like headers (UA + Accept + Referer), reusing .with_retry().

suppressPackageStartupMessages({
  library(dplyr)
  library(httr2)
})

.FFA_CKAN <- "https://opendata.swiss/api/3/action/package_show?id=hauptaggregate-und-prognosen-im-fs-und-gfs-modell"
.FFA_CSV_FALLBACK <- "https://www.data.finance.admin.ch/static/assets/datasets/fs_dashboard/main_extern.csv"

# Government level (hh) -> English label. `bund_ktn_gdn` is the cantons+communes+
# Confederation aggregate the FFA reports alongside the consolidated general govt.
.FFA_LEVELS <- list(
  staat        = "General government",
  bund         = "Confederation",
  ktn          = "Cantons",
  gdn          = "Communes",
  sv           = "Social security funds",
  bund_ktn_gdn = "Confederation, cantons and communes"
)

# Accounting model -> English label.
.FFA_MODELS <- list(
  fs  = "FS model (financial statistics)",
  gfs = "GFS model (Maastricht / SNA basis)"
)

# variable (source German code) -> English headline-indicator label. Only the
# headline aggregates the project curates are kept; the deep debt-decomposition
# codes (debt_*, FBE_*, FS_SR*, ...) are dropped (see datasheet caveats).
.FFA_INDICATORS <- list(
  einnahmen           = "Receipts",
  ausgaben            = "Expenditure",
  saldo               = "Balance",
  einnahmen_ord       = "Ordinary receipts",
  ausgaben_ord        = "Ordinary expenditure",
  saldo_ord           = "Ordinary balance",
  ertrag              = "Revenue",
  aufwand             = "Expenses",
  fiskalertrag        = "Fiscal revenue (taxes)",
  bruttoschuld_fs     = "Gross debt",
  nettoschulden_fs    = "Net debt",
  maastricht_schuld   = "Gross debt (Maastricht)",
  nettoschuld         = "Net debt",
  defizit_ueberschuss = "Deficit / surplus",
  nettozugang_sachvermoegen = "Net acquisition of non-financial assets",
  aktiven             = "Assets",
  fremdkapital        = "Liabilities",
  eigenkapital        = "Equity / net worth",
  bip                 = "Gross domestic product",
  fiskalquote         = "Fiscal ratio (tax-to-GDP)",
  einnahmenquote      = "Receipts-to-GDP ratio",
  staatsquote         = "Expenditure-to-GDP ratio",
  bruttoschuldenquote = "Gross-debt-to-GDP ratio (Maastricht)",
  schuldenquote       = "Debt-to-GDP ratio",
  nettoschuldenquote  = "Net-debt-to-GDP ratio"
)

# source flag (German) -> English estimate-type label.
.FFA_ESTIMATE <- list(
  "Financial statements"             = "Financial statements (actual)",
  "Provisional financial statements" = "Provisional financial statements",
  "Survey financial statements"      = "Survey financial statements",
  "Survey budget"                    = "Survey budget",
  "Budget/financial plans"           = "Budget / financial plans",
  "Forecasts"                        = "Forecasts",
  "Data available"                   = "Data available"
)

# A browser-like GET (the WAF rejects bare clients) with the shared retry policy.
.ffa_get <- function(url) {
  request(url) |>
    req_headers(
      `User-Agent` = paste0("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 ",
                            "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"),
      Accept = "text/csv,text/plain,*/*",
      `Accept-Language` = "en-US,en;q=0.9",
      Referer = "https://opendata.swiss/"
    ) |>
    req_timeout(120) |>
    .with_retry() |>
    req_perform()
}

# Resolve the live CSV resource URL from CKAN (so a moved asset still fetches);
# fall back to the known static URL if CKAN is unreachable or shape-shifts.
.ffa_resolve_csv <- function() {
  url <- tryCatch({
    resp <- .ffa_get(.FFA_CKAN)
    doc <- jsonlite::fromJSON(resp_body_string(resp), simplifyVector = FALSE)
    res <- doc$result$resources
    # the data resource (not the country-code codelist): a CSV whose URL points at
    # the fs_dashboard main file.
    hit <- Filter(function(r) {
      fmt <- toupper(r$format %||% "")
      grepl("main_extern", r$url %||% "", fixed = TRUE) ||
        (identical(fmt, "CSV") && grepl("fs_dashboard", r$url %||% "", fixed = TRUE))
    }, res)
    if (length(hit)) hit[[1]]$url else .FFA_CSV_FALLBACK
  }, error = function(e) .FFA_CSV_FALLBACK)
  url %||% .FFA_CSV_FALLBACK
}

# Read CKAN's `modified` date for the publish stamp (best-effort).
.ffa_updated <- function() {
  tryCatch({
    resp <- .ffa_get(.FFA_CKAN)
    doc <- jsonlite::fromJSON(resp_body_string(resp), simplifyVector = FALSE)
    m <- doc$result$modified %||% doc$result$issued
    if (is.null(m)) return(NA_character_)
    substr(as.character(m), 1, 10)
  }, error = function(e) NA_character_)
}

# Build the contract `dimensions` meta for one dim column from a code->label map,
# keeping only codes actually present in the data, in the map's declared order.
.ffa_dim <- function(data, col, label_map, dim_label) {
  present <- unique(as.character(data[[col]]))
  codes <- intersect(names(label_map), present)
  list(
    label = list(en = dim_label),
    levels = setNames(lapply(codes, function(code) {
      list(label = list(en = unname(label_map[[code]] %||% code)))
    }), codes)
  )
}

ffa_fetch <- function(dataset_id = "ch_ffa_finances",
                      title = list(en = "Public finances: general government main aggregates")) {
  csv_url <- .ffa_resolve_csv()
  resp <- .ffa_get(csv_url)
  raw <- readr::read_csv(I(resp_body_string(resp)), show_col_types = FALSE,
                         col_types = readr::cols(.default = readr::col_character()))

  stopifnot(all(c("hh", "model", "variable", "jahr", "value", "source") %in% names(raw)))

  data <- raw |>
    dplyr::transmute(
      level     = as.character(hh),
      model     = as.character(model),
      indicator = as.character(variable),
      estimate  = as.character(source),
      jahr      = as.character(jahr),
      value     = suppressWarnings(as.numeric(value))
    ) |>
    # Keep only the curated headline indicators. The GDP reference row carries
    # hh=NA / model=NA in the source; place it under General government / GFS so it
    # sits in the tree as a real series rather than an orphan NA branch.
    dplyr::filter(indicator %in% names(.FFA_INDICATORS), !is.na(value)) |>
    dplyr::mutate(
      level = dplyr::if_else(indicator == "bip" & (is.na(level) | level == "NA"),
                             "staat", level),
      model = dplyr::if_else(indicator == "bip" & (is.na(model) | model == "NA"),
                             "gfs", model),
      estimate = dplyr::if_else(is.na(estimate) | estimate == "NA",
                                "Financial statements", estimate)
    ) |>
    dplyr::filter(level %in% names(.FFA_LEVELS), model %in% names(.FFA_MODELS)) |>
    dplyr::mutate(date = as.Date(to_iso(jahr))) |>
    dplyr::select(level, model, indicator, estimate, date, value) |>
    dplyr::arrange(level, model, indicator, estimate, date)

  meta <- list(
    title = title,
    source = list(
      name = list(en = "Federal Finance Administration (FFA)"),
      url = "https://opendata.swiss/en/dataset/hauptaggregate-und-prognosen-im-fs-und-gfs-modell"
    ),
    license = "opendata.swiss terms of use (open use, attribution required: Federal Finance Administration FFA)",
    frequency = "annual",
    dimensions = list(
      level     = .ffa_dim(data, "level",     .FFA_LEVELS,     "Government level"),
      model     = .ffa_dim(data, "model",     .FFA_MODELS,     "Accounting model"),
      indicator = .ffa_dim(data, "indicator", .FFA_INDICATORS, "Indicator"),
      estimate  = .ffa_dim(data, "estimate",  .FFA_ESTIMATE,   "Estimate type")
    ),
    units = list(en = "CHF million (levels) / share of GDP, 0-1 (ratios)"),
    updated = .ffa_updated(),
    notes = list(en = paste(
      "Headline general-government finance aggregates from the FFA FS- and GFS-model",
      "dashboard. Level figures are in CHF million; the *quote (ratio) indicators are",
      "expressed as a share of GDP on a 0-1 scale. Years beyond the latest financial",
      "statement are budget / financial-plan or forecast figures (see the estimate",
      "dimension)."))
  )

  list(id = dataset_id, data = data, meta = meta)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
