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


# ---- ch_fso_trade_partner (External sector) ----
# Foreign trade by partner country: exports + imports, annual, CHF millions.
# Two single-sheet FSO DAM Excel assets, pinned by asset id (the English masters):
#   exports 36664830, imports 36664836.
# The two workbooks have DIFFERENT column layouts (exports put countries in col2 and
# continents/Total in col1; imports put every label flat in col1), so the parser does
# NOT use which column a label sits in to decide country-vs-group. It anchors the
# year-header row by content (>5 cells matching a 4-digit year), reads the data rows
# below until the footnote/Source band, takes the label as col2-if-present-else-col1,
# strips trailing footnote markers (digits + Unicode superscripts), and classifies
# `level` by membership in a fixed continent/economic-area set — robust to either
# layout, and fail-loud (the year-header / value anchors) if the sheets are re-cut.
# Each cleaned label keys a `partner` dimension; `flow` = export/import. Self-contained
# (downloads both asset masters itself) because it pins asset ids, not an order number.
.TRADE_GROUPS <- c("Total", "Europe", "EU", "Asia", "North America",
                   "Central and South America", "Africa", "Oceania")

.trade_partner_sheet <- function(path, flow_code) {
  raw <- suppressMessages(readxl::read_excel(
    path, sheet = 1, col_names = FALSE, .name_repair = "minimal", col_types = "text"))
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)

  # --- locate the year-header row by content (>5 four-digit-year cells) ---------
  is_year <- function(x) grepl("^(19|20)[0-9]{2}$", trimws(x))
  hdr_row <- NA_integer_
  for (i in seq_len(nrow(raw)))
    if (sum(is_year(as.character(raw[i, ])), na.rm = TRUE) > 5L) { hdr_row <- i; break }
  if (is.na(hdr_row))
    stop("ch_fso_trade_partner: no year-header row (>5 4-digit-year cells) — sheet layout changed?",
         call. = FALSE)

  hdr     <- trimws(as.character(raw[hdr_row, ]))
  yr_cols <- which(is_year(hdr))
  years   <- as.integer(hdr[yr_cols])

  # --- data rows: below the header, stop at the footnote / Source band ----------
  body <- raw[(hdr_row + 1L):nrow(raw), , drop = FALSE]
  c1 <- trimws(as.character(body[[1]]))
  c2 <- if (ncol(body) >= 2) trimws(as.character(body[[2]])) else rep(NA_character_, nrow(body))
  c1[c1 == ""] <- NA; c2[c2 == ""] <- NA
  stop_at <- which(!is.na(c1) & grepl("^(Source|Status|Enquir|Information|©)", c1))
  end_row <- if (length(stop_at)) min(stop_at) - 1L else nrow(body)

  # Drop trailing footnote markers (plain digits + Unicode superscripts) + space:
  # "Total 1 2 4" -> "Total", "Belgium ³" -> "Belgium".
  clean_label <- function(x) {
    x <- gsub("[¹²³⁰-⁹]+", "", x)  # superscript digits
    x <- gsub("[[:space:]]+[0-9 ]+$", "", x)               # trailing " 1 2 4"
    trimws(x)
  }

  rows <- list()
  for (r in seq_len(end_row)) {
    raw_lab <- if (!is.na(c2[r])) c2[r] else c1[r]
    if (is.na(raw_lab)) next
    lab <- clean_label(raw_lab)
    if (lab == "") next
    vals <- suppressWarnings(as.numeric(
      gsub("[ ']", "", gsub(",", ".", as.character(body[r, yr_cols])))))  # drops "...." / "" -> NA
    if (all(is.na(vals))) next  # skips footnote-definition rows (no numeric year cells)
    level <- if (lab %in% .TRADE_GROUPS) "group" else "country"
    rows[[length(rows) + 1L]] <- tibble::tibble(
      flow = flow_code, partner = lab, level = level, year = years, value = vals)
  }
  dplyr::bind_rows(rows)
}

fso_excel_ch_fso_trade_partner <- function(pubdate = NULL) {
  base <- "https://dam-api.bfs.admin.ch/hub/api/dam/assets/%s/master"
  ex_path <- tempfile(fileext = ".xlsx"); download_binary(sprintf(base, "36664830"), ex_path)
  im_path <- tempfile(fileext = ".xlsx"); download_binary(sprintf(base, "36664836"), im_path)

  long <- dplyr::bind_rows(
    .trade_partner_sheet(ex_path, "export"),
    .trade_partner_sheet(im_path, "import"))

  data <- long %>%
    dplyr::filter(!is.na(value), !is.na(year)) %>%
    dplyr::transmute(
      flow    = as.character(flow),
      partner = as.character(partner),
      level   = as.character(level),
      date    = as.Date(sprintf("%d-01-01", year)),
      value   = as.numeric(value)) %>%
    dplyr::distinct(flow, partner, date, .keep_all = TRUE) %>%  # one row per flow x partner x year
    dplyr::arrange(flow, partner, date)

  # Value anchors: a silent column/row shift would move these off their labels.
  anchor <- function(fl, pt, yr, want) {
    got <- data$value[data$flow == fl & data$partner == pt &
                        data$date == as.Date(sprintf("%d-01-01", yr))]
    if (length(got) != 1L || abs(got - want) > 0.5)
      stop(sprintf("ch_fso_trade_partner: anchor %s/%s/%d = %s, expected %.1f — layout changed?",
                   fl, pt, yr, if (length(got)) sprintf("%.1f", got[1]) else "NA", want), call. = FALSE)
  }
  anchor("export", "Total",   2024, 393833.5)
  anchor("export", "Germany", 2024, 45218.3)
  anchor("export", "USA",     2024, 65297.2)
  anchor("import", "Germany", 2024, 59891.6)

  partners <- data %>% dplyr::distinct(partner, level)
  partner_levels <- stats::setNames(
    lapply(partners$partner, function(p) list(label = list(en = p))),
    partners$partner)

  meta <- list(
    title = list(en = "Foreign trade by partner country"),
    source = list(
      name = list(en = "Swiss Federal Statistical Office (FSO) / Federal Office for Customs and Border Security (FOCBS)"),
      url  = "https://www.bfs.admin.ch/asset/en/36664830"
    ),
    license   = "fso",
    frequency = "annual",
    topic     = "External sector",
    units     = list(en = "CHF millions"),
    updated   = if (is.null(pubdate)) NA_character_ else as.character(pubdate),
    dimensions = list(
      flow = list(
        label = list(en = "Trade flow"),
        levels = list(
          export = list(label = list(en = "Exports")),
          import = list(label = list(en = "Imports"))
        )
      ),
      partner = list(
        label  = list(en = "Partner country / region"),
        levels = partner_levels
      ),
      level = list(
        label = list(en = "Aggregation level"),
        levels = list(
          group   = list(label = list(en = "Continent / economic area")),
          country = list(label = list(en = "Individual country"))
        )
      )
    )
  )

  list(id = "ch_fso_trade_partner", data = as.data.frame(data), meta = meta)
}

# ---- ch_fso_gdp_region (National accounts) ----

fso_excel_ch_fso_gdp_region <- function(path, pubdate) {

  num_eu <- function(x) {
    x <- as.character(x)
    x[x %in% c("...", "…", "")] <- NA_character_
    x <- gsub("'", "", x, fixed = TRUE)   # thousands separator
    x <- gsub(" ", "", x)             # nbsp
    x <- gsub(" ", "", x)                  # spaces
    x <- gsub(",", ".", x, fixed = TRUE)   # decimal comma
    suppressWarnings(as.numeric(x))
  }

  # Stable codes keyed on the workbook's English row label (column 1). The asset
  # has two sheets — "GDP per canton" and "GDP per region" — each beginning with
  # a current-price levels block, followed by "Change over previous year" blocks
  # we ignore. Switzerland appears in BOTH sheets with identical values, so it is
  # taken once (from the canton sheet). Zurich/Ticino each appear as a one-canton
  # greater region AND as the canton itself (identical values): the greater-region
  # row keeps the region slug (zurich/ticino_r), the canton row keeps the 2-letter
  # canton code (ZH/TI), and the region HIERARCHY nests the canton under it — both
  # are real, data-bearing series, never grouping-only placeholders.
  canton_codes <- c(
    "Zurich" = "ZH", "Berne" = "BE", "Lucerne" = "LU", "Uri" = "UR",
    "Schwyz" = "SZ", "Obwalden" = "OW", "Nidwalden" = "NW", "Glarus" = "GL",
    "Zug" = "ZG", "Fribourg" = "FR", "Solothurn" = "SO", "Basel-Stadt" = "BS",
    "Basel-Landschaft" = "BL", "Schaffhausen" = "SH", "Appenzell A. Rh." = "AR",
    "Appenzell I. Rh." = "AI", "St. Gallen" = "SG", "Graubünden" = "GR",
    "Aargau" = "AG", "Thurgau" = "TG", "Ticino" = "TI", "Vaud" = "VD",
    "Valais" = "VS", "Neuchâtel" = "NE", "Geneva" = "GE", "Jura" = "JU"
  )
  region_codes <- c(
    "Lake Geneva Region"       = "leman",
    "Espace Mittelland"        = "mittelland",
    "Northwestern Switzerland" = "nw",
    "Zurich"                   = "zurich",
    "Eastern Switzerland"      = "east",
    "Central Switzerland"      = "central",
    "Ticino"                   = "ticino_r"
  )

  # Canton -> greater-region grouping (FSO / Eurostat NUTS-2). Drives the
  # CH -> greater region -> canton hierarchy; every code here is data-bearing.
  region_members <- list(
    leman      = c("VD", "VS", "GE"),
    mittelland = c("BE", "FR", "SO", "NE", "JU"),
    nw         = c("BS", "BL", "AG"),
    zurich     = c("ZH"),
    east       = c("GL", "SH", "AR", "AI", "SG", "GR", "TG"),
    central    = c("LU", "UR", "SZ", "OW", "NW", "ZG"),
    ticino_r   = c("TI")
  )

  # Pull the current-price (block 1) levels out of one sheet, anchoring on header
  # TEXT not fixed rows: `header_label` ("Canton"/"Region") locates the year
  # header row; the value block starts after the "In CHF million" subheader and
  # ends at the first blank col-1 cell (the gap before "Change over previous
  # year"). An inserted/reordered row or renamed anchor fails loud.
  read_block <- function(sheet, header_label) {
    m <- as.data.frame(readxl::read_excel(
      path, sheet = sheet, col_names = FALSE, col_types = "text",
      .name_repair = "minimal"
    ))
    col1 <- trimws(as.character(m[[1]]))

    hdr_row <- which(col1 == header_label)
    if (length(hdr_row) != 1L)
      stop(sprintf("ch_fso_gdp_region: header '%s' matched %d rows in sheet '%s' — layout changed?",
                   header_label, length(hdr_row), sheet), call. = FALSE)

    sub_row <- which(grepl("^In CHF million", col1))
    sub_row <- sub_row[sub_row > hdr_row][1]
    if (is.na(sub_row))
      stop(sprintf("ch_fso_gdp_region: 'In CHF million' subheader missing in sheet '%s' — layout changed?",
                   sheet), call. = FALSE)

    hdr_vals <- as.character(m[hdr_row, ])
    yr <- suppressWarnings(as.integer(stringr::str_match(hdr_vals, "^\\s*(\\d{4})")[, 2]))
    col_idx <- which(!is.na(yr) & yr >= 1900 & yr <= 2100)
    years <- yr[col_idx]
    if (!length(col_idx))
      stop(sprintf("ch_fso_gdp_region: no year columns found in sheet '%s' — layout changed?",
                   sheet), call. = FALSE)

    start <- sub_row + 1L
    rest  <- col1[start:length(col1)]
    blank <- which(is.na(rest) | rest == "")
    end   <- if (length(blank)) start + blank[1] - 2L else length(col1)
    rows  <- start:end

    labs <- col1[rows]
    out <- lapply(seq_along(rows), function(k) {
      r <- rows[k]
      tibble::tibble(label = labs[k], year = years, value = num_eu(m[r, col_idx]))
    })
    dplyr::bind_rows(out)
  }

  cant <- read_block("GDP per canton", "Canton")
  regn <- read_block("GDP per region", "Region")

  # Switzerland (national total) + the 26 cantons from the canton sheet.
  cant_lvl <- cant %>%
    dplyr::filter(label %in% c(names(canton_codes), "Switzerland")) %>%
    dplyr::mutate(
      region = dplyr::if_else(label == "Switzerland", "ch", unname(canton_codes[label]))
    )

  # The 7 greater regions from the region sheet (drop the duplicate Switzerland row).
  regn_lvl <- regn %>%
    dplyr::filter(label %in% names(region_codes)) %>%
    dplyr::mutate(region = unname(region_codes[label]))

  # Fail loud if any expected label went unmapped (a renamed/inserted row).
  miss_c <- setdiff(c(names(canton_codes), "Switzerland"), cant$label)
  miss_r <- setdiff(names(region_codes), regn$label)
  if (length(miss_c) || length(miss_r))
    stop(sprintf("ch_fso_gdp_region: unmapped labels (canton: %s | region: %s) — layout changed?",
                 paste(miss_c, collapse = ", "), paste(miss_r, collapse = ", ")), call. = FALSE)

  data <- dplyr::bind_rows(cant_lvl, regn_lvl) %>%
    dplyr::filter(!is.na(value)) %>%
    dplyr::transmute(
      region = as.character(region),
      date   = as.Date(sprintf("%d-01-01", year)),
      value  = as.numeric(value)
    ) %>%
    dplyr::arrange(region, date)

  # ---- one hierarchical `region` dimension: CH -> greater region -> canton ----
  region_labels <- c(
    list(ch = "Switzerland"),
    stats::setNames(as.list(names(region_codes)), unname(region_codes)),
    stats::setNames(as.list(names(canton_codes)), unname(canton_codes))
  )
  region_levels <- stats::setNames(
    lapply(names(region_labels), function(cd) list(label = list(en = region_labels[[cd]]))),
    names(region_labels)
  )

  # Nested tree. Every node is a real data-bearing series (CH total, each greater
  # region, each canton) — none are grouping-only, so all are selectable.
  region_hierarchy <- list(
    ch = stats::setNames(
      lapply(names(region_members), function(rg) {
        stats::setNames(
          lapply(region_members[[rg]], function(ct) list()),
          region_members[[rg]]
        )
      }),
      names(region_members)
    )
  )

  meta <- list(
    title = list(en = "Regional gross domestic product (GDP), current prices"),
    source = list(
      name = list(en = "Swiss Federal Statistical Office (FSO)"),
      url  = "https://www.bfs.admin.ch/asset/en/je-e-04.02.06.01"
    ),
    license   = "fso",
    frequency = "annual",
    topic     = "National accounts",
    units     = list(en = "CHF million, at current prices"),
    updated   = as.character(pubdate),
    dimensions = list(
      region = list(
        label     = list(en = "Region"),
        levels    = region_levels,
        hierarchy = region_hierarchy
      )
    )
  )

  list(id = "ch_fso_gdp_region", data = as.data.frame(data), meta = meta)
}

fso_excel_ch_fso_construction_prices <- function(path, pubdate) {
  # The Swiss Construction Price Index is a multi-base workbook (one sheet per
  # index base: 1998 / 2010 / 2015 / 2020). We take the base-2020 sheet for the
  # current levels (Oct 2020 = 100). The sheet is region-blocked: a <REG_nn> row
  # opens each Greater-Region block, followed by its <OBJ_nn> work-type rows.
  sheet <- "2020"

  raw <- suppressMessages(readxl::read_excel(
    path, sheet = sheet, col_names = FALSE, col_types = "text", .name_repair = "minimal"
  ))
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)

  tag1 <- trimws(as.character(raw[[1]]))   # <REG_nn> / <OBJ_nn> row tags

  # --- date columns: anchor on the month name (row 5) + year (row 6), NEVER on a
  # fixed column index. Reference months are October & April; map to first-of-month.
  month_row <- as.character(unlist(raw[5, ], use.names = FALSE))
  year_row  <- as.character(unlist(raw[6, ], use.names = FALSE))
  # normalise potential non-breaking spaces before matching
  month_row <- trimws(gsub(" ", " ", month_row))
  mon <- ifelse(grepl("^Okt", month_row), 10L,
         ifelse(grepl("^Apr", month_row),  4L, NA_integer_))
  yr  <- suppressWarnings(as.integer(year_row))
  date_cols <- which(!is.na(mon) & !is.na(yr) & yr >= 1900 & yr <= 2100)
  if (!length(date_cols))
    stop("ch_fso_construction_prices: no Oct/Apr date columns found in sheet 2020 — layout changed?",
         call. = FALSE)
  dates <- as.Date(sprintf("%04d-%02d-01", yr[date_cols], mon[date_cols]))

  # --- scope to the Switzerland region block (<REG_01> .. next <REG_>) ---------
  # The <OBJ_nn> work-type tags repeat in every regional block, so a row match
  # must be confined to the Switzerland block or it would collide across regions.
  reg_rows <- which(grepl("^<REG_", tag1))
  r01 <- which(tag1 == "<REG_01>")
  if (length(r01) != 1L)
    stop("ch_fso_construction_prices: <REG_01> (Switzerland) marker not found exactly once — layout changed?",
         call. = FALSE)
  nxt <- reg_rows[reg_rows > r01]
  block_end <- if (length(nxt)) min(nxt) - 1L else nrow(raw)
  block <- (r01 + 1L):block_end

  # --- three headline work-types matched by OBJ tag (Total / building / civil) -
  worktypes <- list(
    total   = list(tag = "<OBJ_02>", en = "Construction: Total"),
    hochbau = list(tag = "<OBJ_03>", en = "Building construction (Hochbau)"),
    tiefbau = list(tag = "<OBJ_13>", en = "Civil engineering (Tiefbau)")
  )

  parse_num <- function(x) {
    x <- as.character(x)
    x[x %in% c("...", "…", "")] <- NA_character_
    x <- gsub("'", "", x, fixed = TRUE)        # thousands separator
    x <- gsub(" ", "", x)                 # non-breaking space
    x <- gsub(" ", "", x)                      # ordinary space
    x <- gsub(",", ".", x, fixed = TRUE)       # decimal comma
    suppressWarnings(as.numeric(x))
  }

  pieces <- lapply(names(worktypes), function(code) {
    tag <- worktypes[[code]]$tag
    rr <- block[which(tag1[block] == tag)]   # which() guards against NA rows in the block
    if (length(rr) != 1L)
      stop(sprintf("ch_fso_construction_prices: work-type %s matched %d rows in the Switzerland block (expected 1) — layout changed?",
                   tag, length(rr)), call. = FALSE)
    tibble::tibble(
      worktype = code,
      date     = dates,
      value    = parse_num(as.character(unlist(raw[rr, date_cols], use.names = FALSE)))
    )
  })

  data <- dplyr::bind_rows(pieces)
  data <- data[!is.na(data$value) & !is.na(data$date), , drop = FALSE]
  data <- dplyr::arrange(data, .data$worktype, .data$date)
  data <- as.data.frame(data, stringsAsFactors = FALSE)

  levels <- lapply(names(worktypes), function(code) {
    list(label = list(en = worktypes[[code]]$en))
  })
  names(levels) <- names(worktypes)

  list(
    id   = "ch_fso_construction_prices",
    data = data,
    meta = list(
      title  = list(en = "Construction Price Index"),
      source = list(
        name = list(en = "Swiss Federal Statistical Office (FSO)"),
        url  = "https://www.bfs.admin.ch/asset/de/cc-t-05.05.01"
      ),
      license   = "fso",
      # Semi-annual (Apr & Oct reference months); infer_frequency has no such
      # bucket, so it is set manually here.
      frequency = "semi-annual",
      topic     = "Prices",
      units     = list(en = "Index (October 2020 = 100)"),
      updated   = as.character(pubdate),
      dimensions = list(
        worktype = list(
          label  = list(en = "Type of work"),
          levels = levels
        )
      )
    )
  )
}