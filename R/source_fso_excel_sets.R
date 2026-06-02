# FSO Excel per-dataset parsers (the bespoke sheet-parsing layer).
# Each fso_excel_<id>(path, pubdate) returns the standard list(id=, data=, meta=)
# contract. Generated via the fso-excel-parsers workflow, then verified + integrated.
# The common download/asset-resolution lives in source_fso_excel.R.

suppressPackageStartupMessages({ library(readxl); library(dplyr); library(tidyr); library(stringr) })

# These bespoke sheet parsers anchor on column/row HEADER TEXT, never on fixed
# positions, so an inserted column or reordered row can't silently shift values
# onto the wrong label: a missing/renamed anchor fails loud (-> .try_fetch skips
# the dataset, logged + flagged stale by health.R) instead of shipping garbage.
# Header anchoring is also robust to value REVISIONS (seasonal re-runs, rebasing,
# re-benchmarking) that a fixed value-check would false-fail on. The source-
# agnostic structural net is io.R::validate_dataset.

# ---- ch_fso_cpi (Prices) ----
fso_excel_ch_fso_cpi <- function(path, pubdate) {
  sheet <- "INDEX_m"

  # --- header row (row 4) gives column meaning; dates are Excel serials -------
  # Read row 4 as text so date columns yield raw serials, not formatted dates.
  hdr <- suppressWarnings(readxl::read_excel(
    path, sheet = sheet, col_names = FALSE,
    range = readxl::cell_limits(c(4, 1), c(4, NA)), col_types = "text"
  ))
  hdr <- as.character(unlist(hdr, use.names = FALSE))
  n_col <- length(hdr)

  # Metadata columns are the leading named columns (Code .. PosTxt_E + weight
  # year). Date columns are those whose header parses to a large Excel serial.
  serial <- suppressWarnings(as.numeric(hdr))
  is_date_col <- !is.na(serial) & serial > 20000   # > ~1954, excludes weight yr
  date_cols <- which(is_date_col)

  dates <- as.Date(serial[date_cols], origin = "1899-12-30")
  # normalise to first of month
  dates <- as.Date(format(dates, "%Y-%m-01"))

  # --- read full body (row 5 onward) as text, then split meta / values --------
  body <- suppressWarnings(readxl::read_excel(
    path, sheet = sheet, col_names = FALSE,
    range = readxl::cell_limits(c(5, 1), c(NA, n_col)), col_types = "text"
  ))
  body <- as.data.frame(body, stringsAsFactors = FALSE)

  # Locate the metadata columns by their HEADER NAME (row 4), not by position, so
  # an inserted/reordered column can't silently mislabel the series.
  hcol <- function(name) {
    i <- which(hdr == name)
    if (length(i) != 1L)
      stop(sprintf("ch_fso_cpi: header '%s' matched %d columns (expected 1) — sheet layout changed?",
                   name, length(i)), call. = FALSE)
    i
  }
  code     <- body[[hcol("Code")]]      # position code (series key)
  item_e   <- body[[hcol("Item_E")]]    # parent group (English)
  postxt_e <- body[[hcol("PosTxt_E")]]  # position text (English)

  # keep only rows with a real position code, drop duplicates
  keep <- !is.na(code) & !duplicated(code)
  code     <- code[keep]
  item_e   <- item_e[keep]
  postxt_e <- postxt_e[keep]
  vals     <- body[keep, date_cols, drop = FALSE]

  # --- parse European-formatted numbers ---------------------------------------
  parse_num <- function(x) {
    x <- as.character(x)
    x[x %in% c("...", "…", "")] <- NA_character_
    x <- gsub("'", "", x, fixed = TRUE)   # thousands sep
    x <- gsub(" ", "", x)                 # nbsp / spaces
    x <- gsub(",", ".", x, fixed = TRUE)  # decimal separator
    suppressWarnings(as.numeric(x))
  }

  value_mat <- vapply(vals, parse_num, numeric(nrow(vals)))
  if (is.null(dim(value_mat))) value_mat <- matrix(value_mat, nrow = length(code))
  colnames(value_mat) <- as.character(seq_along(date_cols))

  long <- as.data.frame(value_mat, stringsAsFactors = FALSE)
  long$item <- code
  long <- tidyr::pivot_longer(long, cols = -item, names_to = "didx", values_to = "value")
  long$date <- dates[as.integer(long$didx)]
  long$didx <- NULL

  data <- long %>%
    dplyr::filter(!is.na(value), !is.na(date)) %>%
    dplyr::transmute(item = as.character(item),
              date = as.Date(date),
              value = as.numeric(value)) %>%
    dplyr::arrange(item, date)

  # --- build dimension levels (English labels) --------------------------------
  lab_df <- tibble::tibble(
    code  = code,
    label = ifelse(is.na(postxt_e) | postxt_e == "", item_e, postxt_e)
  ) %>%
    dplyr::filter(code %in% unique(data$item)) %>%
    dplyr::distinct(code, .keep_all = TRUE)

  levels <- stats::setNames(
    lapply(lab_df$label, function(l) list(label = list(en = as.character(l)))),
    lab_df$code
  )

  meta <- list(
    title = list(en = "Consumer Price Index (LIK)"),
    source = list(
      name = list(en = "Swiss Federal Statistical Office (FSO)"),
      url  = "https://www.bfs.admin.ch/asset/de/su-d-05.02.66"
    ),
    license = "fso",
    frequency = "monthly",
    topic = "Prices",
    updated = as.character(pubdate),
    dimensions = list(
      item = list(
        label  = list(en = "CPI position"),
        levels = levels
      )
    )
  )

  list(id = "ch_fso_cpi", data = data, meta = meta)
}

# ---- ch_fso_ppi (Prices) ----
fso_excel_ch_fso_ppi <- function(path, pubdate) {
  raw <- readxl::read_excel(path, sheet = "INDEX_m", col_names = FALSE,
                            col_types = "text")

  # Row 6 holds the original-base codes (<1963>, <1993>, ...), row 7 the labels
  # ("Mai 1993 = 100"). Column 3 holds the Excel date serial; columns 4..10 hold
  # the index values for each base. Columns 11+ are % changes -> skip.
  base_codes <- gsub("[<>]", "", as.character(raw[6, ]))
  base_labs  <- as.character(raw[7, ])

  # value columns: those whose row-6 marker is a 4-digit base year
  val_cols <- which(grepl("^[0-9]{4}$", base_codes))
  date_col <- 3L

  body <- raw[8:nrow(raw), , drop = FALSE]

  # date: Excel serial -> Date (first of month). Drop non-numeric (footer) rows.
  serial <- suppressWarnings(as.numeric(body[[date_col]]))
  keep <- !is.na(serial)
  body <- body[keep, , drop = FALSE]
  date <- as.Date(serial[keep], origin = "1899-12-30")
  # normalise to first of month
  date <- as.Date(format(date, "%Y-%m-01"))

  parse_num <- function(x) {
    x <- as.character(x)
    x[x %in% c("…", "...", "")] <- NA
    x <- gsub("'", "", x, fixed = TRUE)
    x <- gsub(",", ".", x, fixed = TRUE)
    suppressWarnings(as.numeric(x))
  }

  pieces <- lapply(val_cols, function(col) {
    tibble::tibble(
      base  = base_codes[col],
      date  = date,
      value = parse_num(body[[col]])
    )
  })
  data <- dplyr::bind_rows(pieces) %>%
    dplyr::filter(!is.na(value)) %>%
    dplyr::arrange(base, date)

  # level labels: "1963 = 100" / "Mai 1993 = 100" -> English-friendly label
  levels <- list()
  for (col in val_cols) {
    code <- base_codes[col]
    lab  <- base_labs[col]
    lab  <- stringr::str_replace(lab, "Mai", "May")
    lab  <- stringr::str_replace(lab, "Dez", "Dec")
    levels[[code]] <- list(label = list(en = sprintf("Base %s (%s)", code, lab)))
  }

  list(
    id   = "ch_fso_ppi",
    data = as.data.frame(data),
    meta = list(
      title  = list(en = "Producer and Import Price Index"),
      source = list(
        name = list(en = "Swiss Federal Statistical Office (FSO)"),
        url  = "https://www.bfs.admin.ch/asset/de/su-q-05.04.03.01-ppi-ipp"
      ),
      license   = "fso",
      frequency = "monthly",
      topic     = "Prices",
      updated   = as.character(pubdate),
      dimensions = list(
        base = list(
          label  = list(en = "Index base"),
          levels = levels
        )
      )
    )
  )
}

# ---- ch_fso_wage_idx (Wages) ----
fso_excel_ch_fso_wage_idx <- function(path, pubdate) {

  num_eu <- function(x) {
    x <- as.character(x)
    x <- stringr::str_replace_all(x, "'", "")
    x <- stringr::str_replace_all(x, " ", "")
    x <- stringr::str_trim(x)
    x <- stringr::str_replace(x, ",", ".")
    suppressWarnings(as.numeric(x))
  }

  # The data rows are the components of the wage total, cut two non-crossing ways:
  # by sex (Men/Women) and by sector (Secondary/Construction/Tertiary). They live on
  # a single `breakdown` dimension. Each row is identified by its workbook LABEL
  # (column 3), not its position, so an inserted/reordered row can't mislabel them.
  label_to_code <- c("TOTAL" = "tot", "Men" = "m", "Women" = "f",
                     "SECTOR 2" = "bf1", "Construction" = "f41", "SECTOR 3" = "gs4")

  parse_block <- function(m, header_row, body_rows, measure_code) {
    # value columns = header cells that parse to a 4-digit year (skips the
    # NOGA02/NOGA08 break columns, which carry code/label artifacts, not years).
    yrs <- suppressWarnings(as.integer(round(num_eu(m[header_row, ]))))
    col_idx <- which(!is.na(yrs) & yrs >= 1900 & yrs <= 2100)
    years   <- yrs[col_idx]
    labs    <- trimws(m[body_rows, 3])

    out <- lapply(names(label_to_code), function(lab) {
      rr <- body_rows[match(lab, labs)]
      if (is.na(rr))
        stop(sprintf("ch_fso_wage_idx: row label '%s' missing from the %s block — sheet layout changed?",
                     lab, measure_code), call. = FALSE)
      dplyr::tibble(breakdown = label_to_code[[lab]], measure = measure_code,
                    year = years, value = num_eu(m[rr, col_idx]))
    })
    dplyr::bind_rows(out)
  }

  read_sheet <- function(sheet, adjustment_code) {
    m <- as.matrix(readxl::read_excel(path, sheet = sheet, col_names = FALSE))
    # The sheet stacks two blocks, each introduced by a "NOGA02" header row: the
    # index (1993=100) first, then the year-on-year change. Anchor on those header
    # rows instead of hardcoded row numbers.
    hdr_rows <- which(trimws(m[, 1]) == "NOGA02")
    if (length(hdr_rows) != 2L)
      stop(sprintf("ch_fso_wage_idx: expected 2 NOGA02 header rows in sheet %s, found %d — layout changed?",
                   sheet, length(hdr_rows)), call. = FALSE)
    ends <- c(hdr_rows[2] - 1L, nrow(m))
    idx <- parse_block(m, hdr_rows[1], (hdr_rows[1] + 1L):ends[1], "index")
    chg <- parse_block(m, hdr_rows[2], (hdr_rows[2] + 1L):ends[2], "change")
    # Loose, revision-proof sanity that the blocks are in the documented order
    # (index ~100-150 vs change ~%): catches a block swap without pinning a value.
    if (stats::median(idx$value, na.rm = TRUE) < 50)
      stop(sprintf("ch_fso_wage_idx: first block in %s is not index-like (median %.1f) — blocks reordered?",
                   sheet, stats::median(idx$value, na.rm = TRUE)), call. = FALSE)
    dplyr::mutate(dplyr::bind_rows(idx, chg), adjustment = adjustment_code)
  }

  nominal <- read_sheet("T1.93", "nominal")  # sheet 1 = nominal wage index
  real    <- read_sheet("T2.93", "real")     # sheet 2 = real wage index

  data <- dplyr::bind_rows(nominal, real)
  data <- dplyr::filter(data, !is.na(year), !is.na(value))
  data <- dplyr::mutate(data, date = as.Date(sprintf("%d-01-01", year)))
  data <- dplyr::select(data, breakdown, measure, adjustment, date, value)
  data <- dplyr::arrange(data, adjustment, measure, breakdown, date)

  meta <- list(
    title  = list(en = "Swiss Wage Index"),
    source = list(
      name = list(en = "Swiss Federal Statistical Office (FSO)"),
      url  = "https://www.bfs.admin.ch/asset/de/je-e-03.04.03.00.04"
    ),
    license   = "fso",
    frequency = "annual",
    topic     = "Wages",
    updated   = as.character(pubdate),
    dimensions = list(
      # One overlay axis: the Total wage index and its two non-crossing cuts
      # (by sex, by sector). Encoded as a hierarchy so the picker renders the
      # "By sex" / "By sector" groups as headers and Men/Women can be overlaid
      # in the same chart. Construction is nested under Secondary (sub-position).
      breakdown = list(
        label = list(en = "Breakdown"),
        levels = list(
          tot       = list(label = list(en = "Total")),
          by_sex    = list(label = list(en = "By sex")),
          m         = list(label = list(en = "Men")),
          f         = list(label = list(en = "Women")),
          by_sector = list(label = list(en = "By sector")),
          bf1       = list(label = list(en = "Secondary sector")),
          f41       = list(label = list(en = "Construction")),
          gs4       = list(label = list(en = "Tertiary sector"))
        ),
        hierarchy = list(
          tot = list(
            by_sex    = list(m = list(), f = list()),
            by_sector = list(bf1 = list(f41 = list()), gs4 = list())
          )
        )
      ),
      measure = list(
        label = list(en = "Measure"),
        levels = list(
          index  = list(label = list(en = "Index (1993 = 100)")),
          change = list(label = list(en = "Variation in % compared with previous year"))
        )
      ),
      adjustment = list(
        label = list(en = "Adjustment"),
        levels = list(
          nominal = list(label = list(en = "Nominal wage index")),
          real    = list(label = list(en = "Real wage index"))
        )
      )
    )
  )

  list(id = "ch_fso_wage_idx", data = data, meta = meta)
}

# ---- ch_fso_pop (Population) ----
fso_excel_ch_fso_pop <- function(path, pubdate) {
  raw <- readxl::read_excel(path, sheet = 1, col_names = FALSE,
                            .name_repair = "minimal")
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)

  # Each component is anchored on a distinctive word in its German column header
  # (the header band spans rows 2-5), not a fixed column number — so an inserted
  # column can't silently shift the data. The source's `change_abs` / `in %`
  # columns are intentionally not matched (the first is a trivial first difference
  # we drop, the second a percentage). `pat` -> (code, English label).
  items <- list(
    pop_stock_jan  = list(pat = "Januar",        en = "Population on 1 January"),
    live_births    = list(pat = "Lebend",        en = "Live births"),
    deaths         = list(pat = "Todes",         en = "Deaths"),
    birth_surplus  = list(pat = "schuss",        en = "Excess of births over deaths"),
    immigration    = list(pat = "Einwanderung",  en = "Immigration"),
    emigration     = list(pat = "Auswanderung",  en = "Emigration"),
    migration_bal  = list(pat = "saldo",         en = "Net migration"),
    naturalisation = list(pat = "Bürgerrecht", en = "Acquisition of Swiss citizenship"),
    adjustments    = list(pat = "bereini",       en = "Adjustments"),
    pop_stock_dec  = list(pat = "Dezember",      en = "Population on 31 December")
  )

  hdr_band <- apply(raw[2:5, , drop = FALSE], 2,
                    function(col) paste(stats::na.omit(col), collapse = " "))
  col_of <- function(pat) {
    hit <- grep(pat, hdr_band, ignore.case = TRUE)
    if (length(hit) != 1L)
      stop(sprintf("ch_fso_pop: header pattern '%s' matched %d columns (expected 1) — sheet layout changed?",
                   pat, length(hit)), call. = FALSE)
    hit
  }

  # Identify data rows: column 1 holds a 4-digit year.
  yr <- suppressWarnings(as.integer(raw[[1]]))
  is_data <- !is.na(yr) & yr > 1800 & yr < 2100
  sub <- raw[is_data, , drop = FALSE]
  years <- yr[is_data]

  parse_num <- function(x) {
    x <- as.character(x)
    x <- stringr::str_replace_all(x, "[']", "")   # thousands separator
    x <- stringr::str_replace_all(x, " | ", "") # nbsp / spaces
    x <- stringr::str_replace_all(x, ",", ".")      # decimal comma
    x <- stringr::str_trim(x)
    suppressWarnings(as.numeric(x))
  }

  pieces <- lapply(names(items), function(code) {
    col <- col_of(items[[code]]$pat)
    tibble::tibble(
      item  = code,
      date  = as.Date(paste0(years, "-01-01")),
      value = parse_num(sub[[col]])
    )
  })
  data <- dplyr::bind_rows(pieces)
  data <- data[!is.na(data$value) & !is.na(data$date), , drop = FALSE]
  data <- dplyr::arrange(data, .data$item, .data$date)

  levels <- lapply(names(items), function(code) {
    list(label = list(en = items[[code]]$en))
  })
  names(levels) <- names(items)

  list(
    id   = "ch_fso_pop",
    data = data,
    meta = list(
      title  = list(en = "Permanent resident population"),
      source = list(
        name = list(en = "Swiss Federal Statistical Office (FSO)"),
        url  = "https://www.bfs.admin.ch/asset/de/su-d-01.02.04.05"
      ),
      license   = "fso",
      frequency = "annual",
      topic     = "Population",
      updated   = as.character(pubdate),
      dimensions = list(
        item = list(
          label  = list(en = "Demographic component"),
          levels = levels
        )
      )
    )
  )
}

# ---- ch_fso_unemp_rate (Labour) ----
fso_excel_ch_fso_unemp_rate <- function(path, pubdate) {
  suppressWarnings(suppressMessages({
    library(dplyr); library(tidyr); library(readxl); library(stringr)
  }))

  sheets <- readxl::excel_sheets(path)
  monthly_sheet <- grep("^Monatswerte", sheets, value = TRUE)[1]

  raw <- suppressMessages(readxl::read_excel(
    path, sheet = monthly_sheet, col_names = FALSE, .name_repair = "minimal"
  ))
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)

  # Row 3 holds date headers (cols 2..N). Col 1 holds row category labels.
  date_hdr <- as.character(unlist(raw[3, ]))
  labels   <- as.character(raw[[1]])

  # Map each value row (by its German label) to (origin, sex) codes.
  # The sheet is a marginal breakdown: each breakdown row sets one dimension
  # to its level while keeping the other at "tot".
  row_map <- list(
    "Total"           = list(origin = "tot", sex = "tot"),
    "Schweizer/innen" = list(origin = "ch",  sex = "tot"),
    "Ausländer/innen" = list(origin = "ex",  sex = "tot"),
    "Männer"          = list(origin = "tot", sex = "men"),
    "Frauen"          = list(origin = "tot", sex = "wom")
  )

  # German month abbreviations used by FSO
  mnths <- c("Jan"=1,"Febr"=2,"März"=3,"Apr"=4,"April"=4,"Mai"=5,"Juni"=6,
             "Juli"=7,"Aug"=8,"Sept"=9,"Okt"=10,"Nov"=11,"Dez"=12)

  parse_month_date <- function(x) {
    # x like "Jan.91", "Sept.00", "Jan.262" (trailing footnote digit)
    x <- trimws(x)
    parts <- str_match(x, "^([A-Za-zäöü]+)\\.(\\d+)$")
    mon_txt <- parts[, 2]
    yr_txt  <- parts[, 3]
    # strip a misread footnote: a 3-digit "year" => drop last digit
    yr_num <- suppressWarnings(as.integer(yr_txt))
    yr_num <- ifelse(!is.na(yr_num) & yr_num >= 100, yr_num %/% 10L, yr_num)
    mon <- mnths[mon_txt]
    # 2-digit year -> 1900s if >= 50 (data starts 1991), else 2000s
    full_year <- ifelse(is.na(yr_num), NA_integer_,
                        ifelse(yr_num >= 50L, 1900L + yr_num, 2000L + yr_num))
    out <- rep(as.Date(NA), length(x))
    ok <- !is.na(mon) & !is.na(full_year)
    out[ok] <- as.Date(sprintf("%04d-%02d-01", full_year[ok], mon[ok]))
    out
  }

  dates <- parse_month_date(date_hdr)
  val_cols <- which(!is.na(dates))

  rows_out <- list()
  for (lab in names(row_map)) {
    ridx <- which(labels == lab)
    ridx <- ridx[ridx >= 4]          # only data rows, not title row
    if (length(ridx) == 0) next
    ridx <- ridx[1]
    vals <- suppressWarnings(as.numeric(unlist(raw[ridx, val_cols])))
    rows_out[[lab]] <- tibble(
      origin = row_map[[lab]]$origin,
      sex    = row_map[[lab]]$sex,
      date   = dates[val_cols],
      value  = vals
    )
  }

  data <- bind_rows(rows_out) %>%
    filter(!is.na(date), !is.na(value)) %>%
    arrange(origin, sex, date) %>%
    select(origin, sex, date, value)

  meta <- list(
    title = list(en = "Unemployment rate (ILO) by sex and nationality, Switzerland"),
    source = list(
      name = list(en = "Swiss Federal Statistical Office (FSO)"),
      url  = "https://www.bfs.admin.ch/asset/de/je-d-03.03.01.03"
    ),
    license   = "fso",
    frequency = "monthly",
    topic     = "Labour",
    updated   = as.character(pubdate),
    dimensions = list(
      origin = list(
        label = list(en = "Nationality"),
        levels = list(
          tot = list(label = list(en = "Total")),
          ch  = list(label = list(en = "Swiss nationals")),
          ex  = list(label = list(en = "Foreign nationals"))
        )
      ),
      sex = list(
        label = list(en = "Sex"),
        levels = list(
          tot = list(label = list(en = "Total")),
          men = list(label = list(en = "Men")),
          wom = list(label = list(en = "Women"))
        )
      )
    )
  )

  list(id = "ch_fso_unemp_rate", data = data, meta = meta)
}
