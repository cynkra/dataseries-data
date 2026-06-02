# Eurostat SDMX 2.1 fetcher (ec.europa.eu/eurostat).
#
# The standalone non-FSO sibling of source_fso_sdmx.R: Switzerland's data also
# appears in Eurostat's EU-harmonised statistics, and a few of those harmonised
# series have no clean FSO equivalent. The first is the HICP (Harmonised Index
# of Consumer Prices) -- the EU methodology consumer-price index, distinct from
# the FSO's national LIK (ch_fso_cpi). Eurostat speaks SDMX 2.1 over a different
# REST host than the FSO's disseminate.stats.swiss, so this gets its own module.
#
# get_text()/get_json() in http.R hardcode no Accept header and JSON parsing, so
# we build the httr2 GETs here against the SDMX-CSV dissemination endpoint,
# reusing .with_retry() from http.R for the shared backoff policy.

suppressPackageStartupMessages({
  library(dplyr)
  library(httr2)
})

.EUROSTAT_BASE <- "https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1"

# An httr2 GET against Eurostat with the shared retry/backoff policy. Eurostat
# serves SDMX-CSV / TSV directly from the query string (?format=), so no custom
# Accept header is needed.
.eurostat_get <- function(url) {
  request(url) |>
    req_timeout(120) |>
    .with_retry() |>
    req_perform() |>
    resp_body_string()
}

# Read the ESTAT COICOP codelist (TSV: "<code>\t<english label>") into a named
# vector code -> label. Used to label the consumption-purpose divisions instead
# of hardcoding the 13 strings, so a Eurostat label revision flows through.
.eurostat_coicop_labels <- function() {
  txt <- .eurostat_get(sprintf("%s/codelist/ESTAT/COICOP?format=TSV", .EUROSTAT_BASE))
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  lines <- lines[nzchar(trimws(lines))]
  parts <- strsplit(lines, "\t", fixed = TRUE)
  codes <- trimws(vapply(parts, `[`, "", 1L))
  labs  <- trimws(vapply(parts, function(p) if (length(p) > 1L) p[2] else NA_character_, ""))
  setNames(labs, codes)
}

# Fetch the Swiss HICP monthly index (unit I15 = 2015 = 100) for the all-items
# aggregate CP00 plus the 12 main COICOP divisions CP01..CP12 = 13 series.
# One SDMX-CSV GET per COICOP code (the dimension is keyed in the path); the CSV
# carries DATAFLOW, LAST UPDATE, freq, unit, coicop, geo, TIME_PERIOD, OBS_VALUE,
# OBS_FLAG, CONF_STATUS. We keep coicop as the single dimension, map TIME_PERIOD
# (YYYY-MM) to an ISO first-of-month date via R/dates.R, and label the divisions
# from the ESTAT COICOP codelist.
eurostat_hicp_fetch <- function(dataset_id = "ch_fso_hicp") {
  coicop <- c("CP00", sprintf("CP%02d", 1:12))
  labels <- .eurostat_coicop_labels()

  frames <- lapply(coicop, function(cc) {
    url <- sprintf("%s/data/prc_hicp_midx/M.I15.%s.CH/?format=SDMX-CSV", .EUROSTAT_BASE, cc)
    raw <- readr::read_csv(I(.eurostat_get(url)), show_col_types = FALSE,
                           col_types = readr::cols(.default = readr::col_character()))
    if (!nrow(raw)) return(NULL)
    data.frame(
      coicop = as.character(raw$coicop),
      date   = as.Date(to_iso(as.character(raw$TIME_PERIOD))),
      value  = suppressWarnings(as.numeric(raw$OBS_VALUE)),
      last_update = as.character(raw$`LAST UPDATE`),
      stringsAsFactors = FALSE
    )
  })
  raw <- dplyr::bind_rows(frames)
  raw <- raw[!is.na(raw$value) & !is.na(raw$date), , drop = FALSE]
  stopifnot(nrow(raw) > 0)

  # Source publish date: Eurostat's LAST UPDATE is "DD/MM/YY HH:MM:SS".
  upd <- suppressWarnings(as.Date(sub(" .*", "", raw$last_update[1]), format = "%d/%m/%y"))

  data <- raw[, c("coicop", "date", "value")]
  data <- data[order(data$coicop, data$date), , drop = FALSE]

  # Value anchors: a silent code/row shift would keep the shape valid, so pin the
  # all-items CP00 index at two long-history points (the 2015 base mean = 100 by
  # construction; an off-by-one row would knock these out).
  chk <- function(date_chr, expect, tol = 0.05) {
    v <- data$value[data$coicop == "CP00" & data$date == as.Date(date_chr)]
    if (length(v) != 1L || abs(v - expect) > tol)
      stop(sprintf("eurostat_hicp_fetch: CP00 %s = %s, expected ~%s (parse shift?)",
                   date_chr, if (length(v)) v[1] else "<none>", expect), call. = FALSE)
  }
  chk("2004-12-01", 96.90)
  chk("2025-12-01", 107.07)

  present <- intersect(coicop, unique(data$coicop))  # keep canonical CP00..CP12 order
  levels <- setNames(lapply(present, function(cc) {
    list(label = list(en = unname(labels[[cc]] %||% cc)))
  }), present)
  # CP00 (all-items) is the parent; the 12 divisions are its children.
  kids <- intersect(sprintf("CP%02d", 1:12), present)

  meta <- list(
    title  = list(en = "Harmonised Index of Consumer Prices (HICP)"),
    source = list(name = list(en = "Eurostat"),
                  url  = "https://ec.europa.eu/eurostat/databrowser/view/prc_hicp_midx/default/table"),
    license = "eurostat",
    frequency = "monthly",
    units = list(en = "Index (2015 = 100)"),
    updated = if (!is.na(upd)) as.character(upd) else NULL,
    dimensions = list(coicop = list(
      label = list(en = "COICOP consumption purpose"),
      levels = levels,
      hierarchy = if (length(kids))
        list(CP00 = setNames(lapply(kids, function(x) list()), kids))
    ))
  )
  list(id = dataset_id, data = data, meta = meta)
}

`%||%` <- function(a, b) if (is.null(a)) b else a