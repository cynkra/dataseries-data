# FSO / BFS STAT-TAB (PX-Web) fetcher.
#
# The messy one. PX-Web quirks handled here:
#   - table id is a *node*; the real table is at {id}/{id}.px
#   - dimension *codes* are German even on /en/ (Jahr, Monat, ...); we keep the
#     codes but use localized valueTexts as labels
#   - 5000-cell cap per call; the caller's query must select within it
#   - time split across Jahr (+ Monat); we recombine into one ISO date
#
# We POST a json-stat2 query and parse the flattened cube into a tidy long tibble.
# JSON-stat is ingestion-only here; we never publish it.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

.fso_table_url <- function(table_id) {
  sprintf("https://www.pxweb.bfs.admin.ch/api/v1/en/%s/%s.px", table_id, table_id)
}

# GET the table metadata and return the full ordered value-code vector for one
# dimension. Used to expand a "select all" chunk dimension into explicit codes
# so we can split a too-big cube into <5000-cell calls.
.fso_dim_values <- function(table_id, dim_code) {
  doc <- get_json(.fso_table_url(table_id))
  for (v in doc$variables) if (identical(v$code, dim_code)) return(unlist(v$values))
  stop(sprintf("dimension %s not found in %s", dim_code, table_id))
}

# Replace one dimension's selection in a query with an explicit item list.
.fso_set_query_dim <- function(query, dim_code, values) {
  for (i in seq_along(query)) {
    if (identical(query[[i]]$code, dim_code)) {
      query[[i]]$selection <- list(filter = "item", values = as.list(values))
      return(query)
    }
  }
  c(query, list(list(code = dim_code,
                     selection = list(filter = "item", values = as.list(values)))))
}

# JSON-stat 2.0 dataset -> list(data=<tibble dims+value>, dimensions=<meta>, dim_ids)
.fso_parse_jsonstat <- function(doc) {
  dim_ids <- unlist(doc$id)
  dims <- doc$dimension

  ordered_codes <- list()
  code_labels <- list()
  for (d in dim_ids) {
    cat_ <- dims[[d]]$category
    idx <- cat_$index
    if (!is.null(names(idx))) {
      codes <- names(idx)[order(unlist(idx))]
    } else {
      codes <- unlist(idx)
    }
    ordered_codes[[d]] <- codes
    lbls <- cat_$label
    code_labels[[d]] <- setNames(
      vapply(codes, function(c) lbls[[c]] %||% c, ""), codes
    )
  }

  values <- doc$value
  # JSON-stat is row-major; last dim iterates fastest. expand.grid with the first
  # dimension varying slowest reproduces that order.
  rev_codes <- ordered_codes[rev(dim_ids)]
  grid <- expand.grid(rev_codes, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  grid <- grid[, rev(seq_along(grid)), drop = FALSE]
  names(grid) <- dim_ids

  val <- vapply(values, function(v) if (is.null(v)) NA_real_ else as.numeric(v), 0)
  grid$value <- val
  data <- grid[!is.na(grid$value), , drop = FALSE]

  dimensions <- setNames(lapply(dim_ids, function(d) {
    list(
      label = list(en = dims[[d]]$label %||% d),
      levels = setNames(
        lapply(names(code_labels[[d]]), function(c) {
          list(label = list(en = unname(code_labels[[d]][[c]])))
        }),
        names(code_labels[[d]])
      )
    )
  }), dim_ids)

  list(data = data, dimensions = dimensions, dim_ids = dim_ids)
}

# Turn the FSO time dimension(s) into one ISO date column. FSO splits time three
# ways depending on table: Jahr+Monat (monthly), a single Quartal code like
# "1991Q3" (quarterly), or Jahr alone (annual). Returns the data with a `date`
# column plus which source columns were consumed and the inferred frequency.
.fso_make_date <- function(data, year_col, month_col, quarter_col) {
  if (!is.null(quarter_col) && quarter_col %in% names(data)) {
    q <- data[[quarter_col]]
    yr <- as.integer(substr(q, 1, 4))
    mo <- (as.integer(substr(q, 6, 6)) - 1L) * 3L + 1L
    data$date <- as.Date(sprintf("%04d-%02d-01", yr, mo))
    list(data = data, used = quarter_col, freq = "quarterly")
  } else if (!is.null(month_col) && month_col %in% names(data)) {
    data$date <- as.Date(sprintf(
      "%04d-%02d-01", as.integer(data[[year_col]]), as.integer(data[[month_col]])))
    list(data = data, used = c(year_col, month_col), freq = "monthly")
  } else {
    data$date <- as.Date(sprintf("%04d-01-01", as.integer(data[[year_col]])))
    list(data = data, used = year_col, freq = "annual")
  }
}

# chunk_by/chunk_size split one dimension across several PX-Web calls so a cube
# whose full selection exceeds the 5000-cell cap still imports. Typically chunk
# the time dimension; the non-time dimensions are identical across chunks.
# Auto-query a PX-Web table: select ALL values of every dimension (the project
# stores the complete source, the site curates), detect the time dimension, and
# size the time chunk so each call stays under the 5000-cell cap. Saves
# hand-writing a query per sibling table.
fso_fetch_auto <- function(dataset_id, table_id, title = NULL) {
  vars <- get_json(.fso_table_url(table_id))$variables
  codes <- vapply(vars, function(v) v$code, "")
  sizes <- setNames(vapply(vars, function(v) length(v$values), 0L), codes)

  if ("Quartal" %in% codes) {
    tcols <- "Quartal"; ycol <- "Jahr"; mcol <- NULL; qcol <- "Quartal"
    chunk_by <- "Quartal"; per_unit <- 1L
  } else if (all(c("Jahr", "Monat") %in% codes)) {
    tcols <- c("Jahr", "Monat"); ycol <- "Jahr"; mcol <- "Monat"; qcol <- NULL
    chunk_by <- "Jahr"; per_unit <- 12L          # a year-chunk carries 12 months
  } else if ("Jahr" %in% codes) {
    tcols <- "Jahr"; ycol <- "Jahr"; mcol <- NULL; qcol <- NULL
    chunk_by <- "Jahr"; per_unit <- 1L
  } else {
    stop(sprintf("no recognized time dimension (Quartal/Jahr[/Monat]) in %s", table_id))
  }

  cells_per_period <- prod(sizes[setdiff(codes, tcols)])
  chunk_size <- max(1L, floor(4500 / (cells_per_period * per_unit)))

  query <- lapply(vars, function(v) {
    list(code = v$code, selection = list(filter = "all", values = list("*")))
  })
  fso_fetch(dataset_id, table_id, query, title = title,
            year_col = ycol, month_col = mcol, quarter_col = qcol,
            chunk_by = chunk_by, chunk_size = chunk_size)
}

fso_fetch <- function(dataset_id, table_id, query,
                      title = NULL, year_col = "Jahr", month_col = "Monat",
                      quarter_col = NULL, chunk_by = NULL, chunk_size = 40L) {
  if (is.null(chunk_by)) {
    queries <- list(query)
  } else {
    vals <- .fso_dim_values(table_id, chunk_by)
    groups <- split(vals, ceiling(seq_along(vals) / chunk_size))
    queries <- lapply(groups, function(g) .fso_set_query_dim(query, chunk_by, g))
  }

  parsed <- NULL
  data_parts <- list()
  for (q in queries) {
    body <- list(query = q, response = list(format = "json-stat2"))
    p <- .fso_parse_jsonstat(post_json(.fso_table_url(table_id), body))
    if (is.null(parsed)) parsed <- p          # dimensions/dim_ids are stable across chunks
    data_parts[[length(data_parts) + 1L]] <- p$data
  }

  data <- do.call(rbind, data_parts)
  dimensions <- parsed$dimensions
  dim_ids <- parsed$dim_ids

  dated <- .fso_make_date(data, year_col, month_col, quarter_col)
  data <- dated$data
  used <- dated$used
  freq <- dated$freq
  # FSO mixes annual aggregates into monthly cubes via a non-numeric time code
  # (e.g. Monat = "YYYY"); those rows parse to NA dates — drop them.
  data <- data[!is.na(data$date), , drop = FALSE]
  for (t in used) dimensions[[t]] <- NULL
  dim_cols <- setdiff(dim_ids, used)

  data <- data |>
    dplyr::select(dplyr::all_of(c(dim_cols, "date", "value"))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c(dim_cols, "date"))))

  meta <- list(
    title = title %||% setNames(list(table_id), "en"),
    source = list(
      name = list(en = "Swiss Federal Statistical Office (FSO)"),
      url = sprintf("https://www.pxweb.bfs.admin.ch/pxweb/en/%s", table_id)
    ),
    license = "fso",
    frequency = freq,
    dimensions = dimensions
  )

  list(id = dataset_id, data = data, meta = meta)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
