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

# Build the standard one-dimension `dimensions` meta from a code->label map.
.dam_csv_dim <- function(label_en, level_labels) {
  list(
    label = list(en = label_en),
    levels = setNames(
      lapply(unname(level_labels), function(l) list(label = list(en = l))),
      names(level_labels)
    )
  )
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
    title = list(en = "Labour productivity (GDP per hour worked, index)"),
    source = list(
      name = list(en = "Swiss Federal Statistical Office (FSO)"),
      url = "https://www.bfs.admin.ch/asset/en/ts-x-04.07.01.01"
    ),
    license = "fso",
    frequency = "annual",
    updated = if (!is.na(dl$pubdate)) as.character(dl$pubdate) else NULL,
    units = list(en = "Index (1991 = 100), chained volume (previous year's prices)"),
    dimensions = list(indicator = .dam_csv_dim("Indicator", c(
      gdp = "Gross domestic product (volume)",
      hours = "Actual hours worked",
      productivity = "Labour productivity (GDP per hour worked)"
    )))
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

  # Authored EN labels for the 23 INDICATORS_HRCHY sector codes (NOGA 2008
  # sections in DETAILS_DE: A; B-F; G-T; and the single-letter divisions).
  sector_labels <- c(
    P      = "Total",
    P_1    = "Sector 1: Agriculture, forestry and fishing",
    P_1_1  = "A Agriculture, forestry and fishing",
    P_2    = "Sector 2: Industry and construction",
    P_2_1  = "B-C Mining, quarrying and manufacturing",
    P_2_2  = "D Electricity, gas, steam and air conditioning supply",
    P_2_3  = "E Water supply; sewerage, waste management and remediation",
    P_2_4  = "F Construction",
    P_3    = "Sector 3: Services",
    P_3_1  = "G Wholesale and retail trade; repair of motor vehicles",
    P_3_2  = "H Transportation and storage",
    P_3_3  = "I Accommodation and food service activities",
    P_3_4  = "J Information and communication",
    P_3_5  = "K Financial and insurance activities",
    P_3_6  = "L Real estate activities",
    P_3_7  = "M Professional, scientific and technical activities",
    P_3_8  = "N Administrative and support service activities",
    P_3_9  = "O Public administration and defence; compulsory social security",
    P_3_10 = "P Education",
    P_3_11 = "Q Human health and social work activities",
    P_3_12 = "R Arts, entertainment and recreation",
    P_3_13 = "S Other service activities",
    P_3_14 = "T Activities of households as employers"
  )
  miss <- setdiff(unique(data$sector), names(sector_labels))
  if (length(miss)) stop("ch_fso_ets: unlabelled sector code(s): ",
                         paste(miss, collapse = ", "))

  sector_levels <- setNames(
    lapply(sector_labels, function(l) list(label = list(en = l))),
    names(sector_labels)
  )
  # Hierarchy: total P -> three sectors -> their NOGA sections.
  leaf <- function(codes) setNames(lapply(codes, function(x) list()), codes)
  sector_hierarchy <- list(P = list(
    P_1 = leaf("P_1_1"),
    P_2 = leaf(c("P_2_1", "P_2_2", "P_2_3", "P_2_4")),
    P_3 = leaf(paste0("P_3_", 1:14))
  ))

  meta <- list(
    title = list(en = "Employed persons by economic sector and sex (ETS, quarterly)"),
    source = list(
      name = list(en = "Swiss Federal Statistical Office (FSO)"),
      url  = "https://www.bfs.admin.ch/asset/en/ts-x-03.02.01.08"
    ),
    license = "fso",
    frequency = "quarterly",
    updated = if (!is.na(dl$pubdate)) as.character(dl$pubdate) else NULL,
    units = list(en = "Number of employed persons (domestic concept, quarterly average)"),
    dimensions = list(
      sector = list(
        label     = list(en = "Economic sector"),
        levels    = sector_levels,
        hierarchy = sector_hierarchy
      ),
      sex = .dam_csv_dim("Sex", c(total = "Total", male = "Men", female = "Women"))
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

  sector_labels <- c(
    S1       = "Total economy",
    S11      = "Non-financial corporations",
    S12      = "Financial corporations",
    S121T127 = "Financial institutions (other than S128 S129)",
    S12Q     = "Insurance corporations and pension funds",
    S13      = "General government",
    S1314    = "Social security funds",
    S14      = "Households",
    S15      = "Non-profit institutions serving households"
  )
  asset_labels <- c(
    P51G            = "Gross fixed capital formation (total)",
    P5111_N111_112G = "Construction",
    `6011`          = "Building construction",
    `6010`          = "Civil engineering",
    P5111_N113T117G = "Equipment, fixed assets and software"
  )

  sec <- as.character(raw$SECTOR)
  ast <- as.character(raw$CLASSIFICATION)
  if (!all(sec %in% names(sector_labels)))
    stop("ch_fso_gfcf_detail: unmapped SECTOR: ",
         paste(unique(sec[!sec %in% names(sector_labels)]), collapse = ", "))
  if (!all(ast %in% names(asset_labels)))
    stop("ch_fso_gfcf_detail: unmapped CLASSIFICATION: ",
         paste(unique(ast[!ast %in% names(asset_labels)]), collapse = ", "))

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
    title = list(en = "Gross fixed capital formation by institutional sector and asset type"),
    source = list(
      name = list(en = "Swiss Federal Statistical Office (FSO)"),
      url  = "https://www.bfs.admin.ch/asset/en/ts-x-04.02.05.02"
    ),
    license   = "fso",
    frequency = "annual",
    updated   = if (!is.na(dl$pubdate)) as.character(dl$pubdate) else NULL,
    units     = list(en = "CHF million, current prices"),
    dimensions = list(
      sector = .dam_csv_dim("Institutional sector", sector_labels),
      # Asset type is hierarchical: P51G = Construction + Equipment, and Construction
      # = Building construction + Civil engineering. P51G (the total) is only present
      # for S1 (total economy) in the source.
      asset  = c(
        .dam_csv_dim("Asset type", asset_labels),
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
    title = list(en = "Actual hours worked (annual working volume)"),
    source = list(
      name = list(en = "Swiss Federal Statistical Office (FSO)"),
      url = "https://www.bfs.admin.ch/asset/en/ts-x-03.02.03.01.02.01"
    ),
    license = "fso",
    frequency = "annual",
    updated = if (!is.na(dl$pubdate)) as.character(dl$pubdate) else NULL,
    dimensions = list(
      measure = .dam_csv_dim("Measure", c(
        weekly = "Usual hours worked per week per job",
        annual = "Annual hours worked per job",
        volume = "Annual volume of hours worked (total)"
      )),
      sex = .dam_csv_dim("Sex", c(
        `_T` = "Total", M = "Men", F = "Women"
      )),
      worktime = .dam_csv_dim("Working time", c(
        `_T`   = "Total",
        FT     = "Full-time",
        PT     = "Part-time",
        PT_I   = "Part-time I (50-89%)",
        PT_II  = "Part-time II (under 50%)"
      ))
    )
  )
  list(id = dataset_id, data = data, meta = meta)
}