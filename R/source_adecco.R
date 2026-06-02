# Adecco Group Swiss Job Market Index (ASJMI) fetcher.
#
# Published by the Stellenmarkt-Monitor Schweiz at the University of Zurich: a
# quarterly index of the number of publicly advertised job openings in
# Switzerland, base Q1 2008 = 100. The headline index decomposes by publication
# channel (internet job portals, company websites, press), plus a seasonally
# adjusted variant of the headline. A leading labour-market indicator and one of
# the few non-government providers in the catalog.
#
# The landing page carries a single .xlsx export link (a CMS DAM asset whose file
# name embeds the latest quarter, e.g. data_gesamtindex_export-2026_Q1.xlsx). We
# scrape that href rather than hardcoding it, so a new quarter is picked up
# automatically. The sheet is a wide table: row 1 years (sparse, forward-filled),
# row 3 quarter (I..IV -> month 3/6/9/12), and one labelled data row per series.

suppressPackageStartupMessages(library(dplyr))

.ADECCO_PAGE <- "https://www.stellenmarktmonitor.uzh.ch/de/indices/asjmi.html"

# Scrape the landing page for the current .xlsx export and return its absolute URL.
adecco_xlsx_url <- function(page = .ADECCO_PAGE) {
  html <- get_text(page)
  href <- regmatches(html, regexpr('/dam/[^"]+?\\.xlsx', html))
  if (!length(href)) stop("adecco: no .xlsx link found on ", page)
  paste0("https://www.stellenmarktmonitor.uzh.ch", href[1])
}

adecco_fetch <- function(dataset_id = "ch_adecco_sjmi", title = NULL) {
  url    <- adecco_xlsx_url()
  target <- tempfile(fileext = ".xlsx")
  download_binary(url, target)

  m <- as.matrix(suppressMessages(readxl::read_xlsx(target, 1, col_names = FALSE, na = "...")))

  # Time axis: year on row 1 (only stamped at Q1, so forward-fill), quarter on
  # row 3. Each value column is one quarter -> first-of-quarter ISO date.
  year <- suppressWarnings(as.integer(m[1, ]))
  for (i in 2:length(year)) if (is.na(year[i])) year[i] <- year[i - 1]
  month <- c(I = 3L, II = 6L, III = 9L, IV = 12L)[trimws(m[3, ])]
  vcol  <- which(!is.na(month) & !is.na(year))
  dates <- as.Date(sprintf("%d-%02d-01", year[vcol], month[vcol]))

  # One labelled data row per series. German source labels -> stable codes.
  rowmap <- c(
    "Adecco Group Swiss Job Market Index" = "gesamt",
    "saisonbereinigte Indexwerte"         = "gesamt_sa",
    "Internet-Stellenportale"             = "internet",
    "Unternehmens-Webseiten"              = "company",
    "Presse (Zeitungen und Anzeiger)"     = "press"
  )
  labels <- trimws(m[, 1])
  data <- dplyr::bind_rows(lapply(names(rowmap), function(lab) {
    r <- which(labels == lab)
    if (!length(r)) return(NULL)
    dplyr::tibble(index = rowmap[[lab]], date = dates,
                  value = suppressWarnings(as.numeric(m[r[1], vcol])))
  }))
  data <- data |>
    dplyr::filter(!is.na(value)) |>
    dplyr::select(index, date, value) |>
    dplyr::arrange(index, date)

  meta <- list(
    title = title %||% list(en = "Adecco Group Swiss Job Market Index"),
    source = list(
      name = list(en = "University of Zurich (Stellenmarkt-Monitor Schweiz)"),
      url  = .ADECCO_PAGE
    ),
    license   = "Stellenmarkt-Monitor Schweiz, University of Zurich (free use, attribution required; Adecco Group Swiss Job Market Index)",
    frequency = "quarterly",
    topic     = "Labour",
    units     = list(en = "Index, Q1 2008 = 100"),
    dimensions = list(
      index = list(
        label = list(en = "Index"),
        levels = list(
          gesamt    = list(label = list(en = "Total")),
          gesamt_sa = list(label = list(en = "Total, seasonally adjusted")),
          internet  = list(label = list(en = "Internet job portals")),
          company   = list(label = list(en = "Company websites")),
          press     = list(label = list(en = "Press (newspapers)"))
        ),
        # The three channels decompose the headline (Total); the seasonally
        # adjusted headline sits alongside it as its own overlay line.
        hierarchy = list(
          gesamt    = list(internet = list(), company = list(), press = list()),
          gesamt_sa = list()
        )
      )
    )
  )

  list(id = dataset_id, data = data, meta = meta)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
