fso_excel_ch_fso_pop <- function(path, pubdate) {
  raw <- readxl::read_excel(path, sheet = 1, col_names = FALSE,
                            .name_repair = "minimal")

  # Component columns (FSO puts components in columns, year in column 1).
  items <- list(
    pop_stock_jan  = list(col = 2,  en = "Population on 1 January"),
    live_births    = list(col = 3,  en = "Live births"),
    deaths         = list(col = 4,  en = "Deaths"),
    birth_surplus  = list(col = 5,  en = "Excess of births over deaths"),
    immigration    = list(col = 6,  en = "Immigration"),
    emigration     = list(col = 7,  en = "Emigration"),
    migration_bal  = list(col = 8,  en = "Net migration"),
    naturalisation = list(col = 9,  en = "Acquisition of Swiss citizenship"),
    adjustments    = list(col = 10, en = "Adjustments"),
    pop_stock_dec  = list(col = 11, en = "Population on 31 December"),
    change_abs     = list(col = 12, en = "Absolute change")
  )

  # Identify data rows: column 1 holds a 4-digit year.
  yr <- suppressWarnings(as.integer(raw[[1]]))
  is_data <- !is.na(yr) & yr > 1800 & yr < 2100
  sub <- raw[is_data, , drop = FALSE]
  years <- yr[is_data]

  parse_num <- function(x) {
    x <- as.character(x)
    x <- stringr::str_replace_all(x, "[']", "")   # thousands separator
    x <- stringr::str_replace_all(x, " ", "") # nbsp
    x <- stringr::str_replace_all(x, ",", ".")      # decimal comma
    x <- stringr::str_trim(x)
    suppressWarnings(as.numeric(x))
  }

  pieces <- lapply(names(items), function(code) {
    col <- items[[code]]$col
    vals <- parse_num(sub[[col]])
    tibble::tibble(
      item  = code,
      date  = as.Date(paste0(years, "-01-01")),
      value = vals
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
