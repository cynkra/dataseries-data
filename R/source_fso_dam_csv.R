# FSO DAM assets whose master file is a tidy long CSV (not an xlsx).
#
# A subset of FSO DAM "cube" assets ship their master as an already-long,
# SDMX-style CSV (one row per observation, dimension columns + VALUE) rather than
# the row/column spreadsheets that source_fso_excel_sets.R has to reshape. For
# those there is no bespoke sheet parsing — just resolve the order number, download
# the CSV, map its columns onto the standard contract. This module is the CSV
# sibling of source_fso_excel.R; it reuses fso_asset_master() for resolution.
#
# Quirks: the masters carry a UTF-8 BOM (read with fileEncoding="UTF-8-BOM" so the
# first header is not mangled into "i..PERIOD"), and the human labels are only in
# FR/DE in the file — English/multilingual level labels are authored in the
# datasheet, mirroring the rest of the catalog.

# Resolve an order number to its CSV master and download it.
fso_dam_csv_download <- function(order_nr) {
  m <- fso_asset_master(order_nr)
  path <- tempfile(fileext = ".csv")
  download_binary(m$url, path)
  list(path = path, pubdate = m$pubdate)
}

# Build the standard one-dimension `dimensions` meta from an ordered code vector.
# Labels (dim + levels) live in the datasheet ## Labels block (attach_labels).
.dam_csv_dim <- function(codes) {
  list(levels = setNames(lapply(codes, function(x) list()), codes))
}

# Labour productivity: GDP, actual hours worked, and productivity, all as a chained
# volume index (previous year's prices), base 1991 = 100, annual. The three series
# share UNIT_MEA = "Index" (the legacy "duplicate idx" trap), so the dimension is
# keyed on INDICATOR, never on the unit. Order ts-x-04.07.01.01.
fso_labour_productivity <- function(dataset_id = "ch_fso_labour_productivity") {
  dl <- fso_dam_csv_download("ts-x-04.07.01.01")
  raw <- read.csv(dl$path, fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE)
  stopifnot(all(c("PERIOD", "INDICATOR", "VALUE") %in% names(raw)))

  slug <- c("GDP" = "gdp", "Actual hours worked" = "hours",
            "Productivity" = "productivity")
  ind <- unname(slug[raw$INDICATOR])
  if (anyNA(ind)) stop("ch_fso_labour_productivity: unmapped INDICATOR value(s): ",
                       paste(unique(raw$INDICATOR[is.na(ind)]), collapse = ", "))

  data <- data.frame(
    indicator = ind,
    date = as.Date(paste0(raw$PERIOD, "-01-01")),
    value = suppressWarnings(as.numeric(raw$VALUE)),
    stringsAsFactors = FALSE
  )
  data <- data[!is.na(data$value) & !is.na(data$date), , drop = FALSE]
  data <- data[order(data$indicator, data$date), , drop = FALSE]

  meta <- list(
    source = list(url = "https://www.bfs.admin.ch/asset/en/ts-x-04.07.01.01"),
    license = "fso",
    frequency = "annual",
    updated = if (!is.na(dl$pubdate)) as.character(dl$pubdate) else NULL,
    dimensions = list(indicator = .dam_csv_dim(c("gdp", "hours", "productivity")))
  )
  list(id = dataset_id, data = data, meta = meta)
}

`%||%` <- function(a, b) if (is.null(a)) b else a


# Employed persons (ETS, domestic concept) by economic sector & sex, quarterly.
# FSO DAM CSV master, order ts-x-03.02.01.08. The master is a UTF-8-BOM long CSV
# carrying BOTH quarterly (FREQ=="Q") and annual (FREQ=="A"/"Y") rows; we keep
# only the quarterly average rows so the annual totals don't double-count. The
# sector hierarchy lives in INDICATORS_HRCHY (P total -> P_1/P_2/P_3 sectors ->
# P_x_y NOGA sections); sex is recoded from GENDER_DE. The DETAILS_DE column holds
# the NOGA section letter for each code, but the human labels are FR/DE only, so
# the English level labels are authored here, like the rest of the catalog.
fso_ets <- function(dataset_id = "ch_fso_ets") {
  dl  <- fso_dam_csv_download("ts-x-03.02.01.08")
  raw <- read.csv(dl$path, fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE)
  stopifnot(all(c("INDICATORS_HRCHY", "GENDER_DE", "PERIOD", "FREQ", "VALUE")
                %in% names(raw)))

  # Quarterly averages only (drop annual A/Y rows to avoid double-counting).
  raw <- raw[raw$FREQ == "Q", , drop = FALSE]

  sex_map <- c(Total = "total", "Männer" = "male", Frauen = "female")
  sex <- unname(sex_map[raw$GENDER_DE])
  if (anyNA(sex)) stop("ch_fso_ets: unmapped GENDER_DE value(s): ",
                       paste(unique(raw$GENDER_DE[is.na(sex)]), collapse = ", "))

  # PERIOD "YYYY-Qn" -> first-of-quarter ISO date via the shared helper.
  date <- as.Date(to_iso(raw$PERIOD))
  if (anyNA(date)) stop("ch_fso_ets: unparseable PERIOD value(s): ",
                        paste(unique(raw$PERIOD[is.na(date)]), collapse = ", "))

  data <- data.frame(
    sector = raw$INDICATORS_HRCHY,
    sex    = sex,
    date   = date,
    value  = suppressWarnings(as.numeric(raw$VALUE)),
    stringsAsFactors = FALSE
  )
  data <- data[!is.na(data$value) & !is.na(data$date), , drop = FALSE]
  data <- data[order(data$sector, data$sex, data$date), , drop = FALSE]

  # The 23 INDICATORS_HRCHY sector codes (NOGA 2008 sections), in display order.
  # Their EN/DE/FR labels live in the datasheet ## Labels block.
  sector_codes <- c("P", "P_1", "P_1_1", "P_2", "P_2_1", "P_2_2", "P_2_3", "P_2_4",
                    "P_3", paste0("P_3_", 1:14))
  miss <- setdiff(unique(data$sector), sector_codes)
  if (length(miss)) stop("ch_fso_ets: unlabelled sector code(s): ",
                         paste(miss, collapse = ", "))

  sector_levels <- setNames(lapply(sector_codes, function(x) list()), sector_codes)
  # Hierarchy: total P -> three sectors -> their NOGA sections.
  leaf <- function(codes) setNames(lapply(codes, function(x) list()), codes)
  sector_hierarchy <- list(P = list(
    P_1 = leaf("P_1_1"),
    P_2 = leaf(c("P_2_1", "P_2_2", "P_2_3", "P_2_4")),
    P_3 = leaf(paste0("P_3_", 1:14))
  ))

  meta <- list(
    source = list(url = "https://www.bfs.admin.ch/asset/en/ts-x-03.02.01.08"),
    license = "fso",
    frequency = "quarterly",
    updated = if (!is.na(dl$pubdate)) as.character(dl$pubdate) else NULL,
    dimensions = list(
      sector = list(
        levels    = sector_levels,
        hierarchy = sector_hierarchy
      ),
      sex = .dam_csv_dim(c("total", "male", "female"))
    )
  )
  list(id = dataset_id, data = data, meta = meta)
}

# GFCF by institutional sector & asset type, annual, current-price levels (MCHF).
# Order ts-x-04.02.05.02 (asset 36182144). The master is a tidy long CSV with
# columns SECTOR, PERIOD, CLASSIFICATION, UNIT_MEAS, VALUE, STATUS. UNIT_MEAS has
# three leaves on the SAME (sector, classification, period) key — MCHF (the
# CHF-million level), AC (% change at current prices) and ACPP (% change at
# previous-year prices). We keep ONLY MCHF: the two %-change leaves triple-count
# every observation and break (dims, date) uniqueness, and the app reproduces
# %-change from the level via its transform toggle. Sibling of fso_labour_productivity.
fso_gfcf_detail <- function(dataset_id = "ch_fso_gfcf_detail") {
  dl  <- fso_dam_csv_download("ts-x-04.02.05.02")
  raw <- read.csv(dl$path, fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE)
  stopifnot(all(c("SECTOR", "PERIOD", "CLASSIFICATION", "UNIT_MEAS", "VALUE") %in% names(raw)))

  # Keep CHF-million LEVELS only (drop the AC / ACPP %-change leaves).
  raw <- raw[raw$UNIT_MEAS == "MCHF", , drop = FALSE]

  # Curated code sets + display order; labels live in the datasheet ## Labels block.
  sector_codes <- c("S1", "S11", "S12", "S121T127", "S12Q", "S13", "S1314", "S14", "S15")
  asset_codes  <- c("P51G", "P5111_N111_112G", "6011", "6010", "P5111_N113T117G")

  sec <- as.character(raw$SECTOR)
  ast <- as.character(raw$CLASSIFICATION)
  if (!all(sec %in% sector_codes))
    stop("ch_fso_gfcf_detail: unmapped SECTOR: ",
         paste(unique(sec[!sec %in% sector_codes]), collapse = ", "))
  if (!all(ast %in% asset_codes))
    stop("ch_fso_gfcf_detail: unmapped CLASSIFICATION: ",
         paste(unique(ast[!ast %in% asset_codes]), collapse = ", "))

  data <- data.frame(
    sector = sec,
    asset  = ast,
    date   = as.Date(paste0(raw$PERIOD, "-01-01")),
    value  = suppressWarnings(as.numeric(raw$VALUE)),
    stringsAsFactors = FALSE
  )
  data <- data[!is.na(data$value) & !is.na(data$date), , drop = FALSE]
  data <- data[order(data$sector, data$asset, data$date), , drop = FALSE]

  meta <- list(
    source = list(url  = "https://www.bfs.admin.ch/asset/en/ts-x-04.02.05.02"),
    license   = "fso",
    frequency = "annual",
    updated   = if (!is.na(dl$pubdate)) as.character(dl$pubdate) else NULL,
    dimensions = list(
      sector = .dam_csv_dim(sector_codes),
      # Asset type is hierarchical: P51G = Construction + Equipment, and Construction
      # = Building construction + Civil engineering. P51G (the total) is only present
      # for S1 (total economy) in the source.
      asset  = c(
        .dam_csv_dim(asset_codes),
        list(hierarchy = list(
          P51G = list(
            P5111_N111_112G = list(`6011` = list(), `6010` = list()),
            P5111_N113T117G = list()
          )
        ))
      )
    )
  )
  list(id = dataset_id, data = data, meta = meta)
}

# Actual hours worked (annual working volume, AVOL): the volume of hours actually
# worked in Switzerland, annual. The DAM CSV master stores the three MEASURE values
# as parallel value columns (VALUE = annual volume of hours, VALUE_Y = annual hours
# per job, VALUE_W = usual weekly hours per job) rather than as rows, so they are
# pivoted into a `measure` dimension. The cube also carries NAT / NOGA1 / SECTOR /
# EMP_STATUS / REGION dims; all are sliced to their "_T" (national total) code,
# leaving SEX x WORKTIME as the structural cut. Order ts-x-03.02.03.01.02.01.
fso_hours_worked <- function(dataset_id = "ch_fso_hours_worked") {
  dl <- fso_dam_csv_download("ts-x-03.02.03.01.02.01")
  raw <- read.csv(dl$path, fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE)
  stopifnot(all(c("TIME_PERIOD", "SEX", "NAT", "WORKTIME", "NOGA1", "SECTOR",
                  "EMP_STATUS", "REGION", "VALUE", "VALUE_Y", "VALUE_W") %in% names(raw)))

  # Slice to the national total of the by-nationality / by-branch / by-sector /
  # by-status / by-region dimensions: keep only the "_T" (total) code of each,
  # leaving SEX x WORKTIME as the structural cut.
  sl <- subset(raw, NAT == "_T" & NOGA1 == "_T" & SECTOR == "_T" &
                     EMP_STATUS == "_T" & REGION == "_T")

  # The three MEASURE values are stored as parallel columns, not rows:
  #   VALUE   = annual volume of hours worked (AVOL), absolute hours
  #   VALUE_Y = annual hours actually worked per job
  #   VALUE_W = usual hours worked per week per job
  # Pivot them into a `measure` dimension so they live on one cube.
  date <- as.Date(paste0(sl$TIME_PERIOD, "-01-01"))
  mk <- function(col, code) data.frame(
    sex = sl$SEX, worktime = sl$WORKTIME, measure = code,
    date = date, value = suppressWarnings(as.numeric(sl[[col]])),
    stringsAsFactors = FALSE
  )
  data <- rbind(mk("VALUE", "volume"), mk("VALUE_Y", "annual"), mk("VALUE_W", "weekly"))
  data <- data[!is.na(data$value) & !is.na(data$date), , drop = FALSE]
  data <- data[order(data$measure, data$sex, data$worktime, data$date), , drop = FALSE]

  meta <- list(
    source = list(url = "https://www.bfs.admin.ch/asset/en/ts-x-03.02.03.01.02.01"),
    license = "fso",
    frequency = "annual",
    updated = if (!is.na(dl$pubdate)) as.character(dl$pubdate) else NULL,
    dimensions = list(
      measure  = .dam_csv_dim(c("weekly", "annual", "volume")),
      sex      = .dam_csv_dim(c("_T", "M", "F")),
      worktime = .dam_csv_dim(c("_T", "FT", "PT", "PT_I", "PT_II"))
    )
  )
  list(id = dataset_id, data = data, meta = meta)
}