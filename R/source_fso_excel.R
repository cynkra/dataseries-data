# FSO Excel-asset fetcher (the non-PX-Web FSO track).
#
# Many FSO datasets — CPI, producer/import prices, wages, population, unemployment,
# national-accounts detail — are NOT in STAT-TAB/PX-Web. FSO disseminates them as
# Excel ("cube") downloads behind the DAM asset API, addressed by an order number
# like "su-q-05.04.03.01-ppi-ipp" or "je-e-03.04.03.00.04".
#
# This module handles the COMMON part: resolve order number -> master xlsx URL +
# publish date, and download it. The per-dataset SHEET PARSING is bespoke (FSO
# spreadsheets put dimensions in both rows and columns) and lives in
# source_fso_excel_sets.R, one parser per dataset, each returning the standard
# list(id=, data=, meta=) contract that write_dataset() consumes.

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
})

# Resolve an FSO order number to its current master asset.
# Returns list(url = <master download url>, pubdate = <Date or NA>).
fso_asset_master <- function(order_nr) {
  doc <- get_json(sprintf(
    "https://dam-api.bfs.admin.ch/hub/api/dam/assets?orderNr=%s&lifecycleGroup=CURRENT",
    utils::URLencode(order_nr, reserved = TRUE)
  ))
  entries <- doc$data
  # The query is by orderNr but can return siblings; keep the exact match.
  hit <- NULL
  for (e in entries) {
    onr <- e$shop$orderNr %||% e$shop[["orderNr"]]
    if (identical(onr, order_nr)) { hit <- e; break }
  }
  if (is.null(hit)) hit <- entries[[1]]
  if (is.null(hit)) stop(sprintf("no DAM asset for order number %s", order_nr))

  master <- NULL
  for (l in hit$links) if (identical(l$rel, "master")) master <- l$href
  if (is.null(master)) stop(sprintf("no master link for %s", order_nr))

  embargo <- hit$bfs$embargo %||% NA_character_
  pubdate <- tryCatch(as.Date(substr(embargo, 1, 10)), error = function(e) NA)

  list(url = master, pubdate = pubdate)
}

# Download the master xlsx for an order number to a local path (default tempfile).
# Returns list(path=, pubdate=) so parsers can stamp meta$updated.
fso_excel_download <- function(order_nr, target_file = tempfile(fileext = ".xlsx")) {
  m <- fso_asset_master(order_nr)
  download_binary(m$url, target_file)
  list(path = target_file, pubdate = m$pubdate)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
