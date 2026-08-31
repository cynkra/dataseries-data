# FSO PX-cube fetcher via the BFS DAM asset API.
#
# The alternative to source_fso.R (PX-Web / json-stat2). Instead of the STAT-TAB
# API, this pulls the cube's *native .px file* straight from the DAM asset hub
# (https://dam-api.bfs.admin.ch, documented by BFS as "Asset Database" /
# "Assets and Dissemination packages API"), addressed by the table id as
# `orderNr` -- the same lookup `fso_asset_master()` already does for the Excel
# assets.
#
# Why: STAT-TAB is deactivated in early 2028 and its /api/v1/ shim is already
# only ~35% reachable. Beyond survival, one .px download strictly dominates the
# json-stat route:
#
#   PX-Web (fso_fetch)                  DAM .px (fso_px_fetch)
#   -----------------------------       ------------------------------
#   1 meta GET + N chunked POSTs        1 GET
#   + 3 GETs for de/fr/it labels        LANGUAGES="de","fr","it","en" inline
#   5000-cell cap -> hand-written       no cap, no query, no chunking
#     query + chunk_by/chunk_size
#   SHOWDECIMALS (0) precision          DECIMALS (4) precision
#   no publication date                 LAST-UPDATED
#
# PX format (plain text, latin1): a header of `KEYWORD[lang]("arg")=value;`
# entries, then `DATA=` followed by the flattened cube. STUB dims are the row
# axis, HEADING dims the column axis; values run row-major with the LAST heading
# dim varying fastest, i.e. expand.grid over c(STUB, HEADING) reversed.

suppressPackageStartupMessages({
  library(dplyr)
  library(httr2)
})

# ---- DAM asset resolution -------------------------------------------------

# Resolve a PX table id (used as the DAM orderNr) to its master link + dates.
# `lifecycle`: CURRENT for the live cube, NON_CURRENT for the archived versions
# (newest first) -- the fallback when FSO publishes a broken CURRENT master.
.px_dam_asset <- function(table_id, lifecycle = "CURRENT") {
  doc <- get_json(sprintf(
    "https://dam-api.bfs.admin.ch/hub/api/dam/assets?orderNr=%s&lifecycleGroup=%s",
    utils::URLencode(table_id, reserved = TRUE), lifecycle
  ))
  entries <- doc$data
  if (!length(entries)) stop(sprintf("no DAM asset for PX table %s", table_id))
  hit <- NULL
  for (e in entries) if (identical(e$shop$orderNr, table_id)) { hit <- e; break }
  if (is.null(hit)) hit <- entries[[1]]

  master <- NULL
  for (l in hit$links) if (identical(l$rel, "master")) master <- l$href
  if (is.null(master)) stop(sprintf("no master link for PX table %s", table_id))

  list(
    url          = master,
    embargo      = hit$bfs$embargo %||% NA_character_,
    last_updated = hit$bfs$lastUpdatedVersion %||% NA_character_
  )
}

# GET the master and decode. The encoding is load-bearing: PX dimension names are
# our stored column names, and level labels are published meta.
#
# The declared CODEPAGE is NOT trustworthy. Every FSO cube says
# CHARSET="ANSI"; CODEPAGE="iso-8859-15", and both halves are wrong somewhere:
#   - px-x-0602000000_103 is single-byte but contains 0x92, the CP1252 right
#     single quote, which is undefined in ISO-8859-1 AND -15. Decoding by the
#     declaration yields `d<0x92>automobiles`; that exact byte is sitting in
#     data/ch_fso_{besta,besta_outlook,vacancies}.json today (20 of them),
#     shipped there by the json-stat route, which trusts the same lie.
#   - px-x-1503040100_103 and px-x-1604000000_102 are actually UTF-8 despite the
#     same declaration. Force-decoding those as single-byte gives `AbschlÃ¼sse`.
# So sniff instead: valid UTF-8 with at least one multi-byte sequence means
# UTF-8; otherwise CP1252, the superset that covers the C1 characters FSO emits.
# 8/24 sampled cubes carry C1 bytes and 2/15 are UTF-8, so both branches are live.
.px_decode <- function(raw) {
  has_high <- any(raw >= as.raw(0x80))
  if (!has_high) return(rawToChar(raw))
  if (!is.na(iconv(list(raw), "UTF-8", "UTF-8"))) return(iconv(list(raw), "UTF-8", "UTF-8"))
  out <- iconv(list(raw), "WINDOWS-1252", "UTF-8")
  if (is.na(out)) stop("PX master is neither UTF-8 nor CP1252")
  out
}

.px_text <- function(url) {
  resp <- request(url) |>
    req_headers(`User-Agent` = "dataseries-data (+https://github.com/cynkra/dataseries-data)") |>
    req_timeout(180) |>
    .with_retry() |>
    req_perform()
  .px_decode(resp_body_raw(resp))
}

# ---- PX header parsing ----------------------------------------------------

# Split on `;` that are OUTSIDE double quotes: titles and footnotes contain
# semicolons, so a plain strsplit() shreds the header.
.px_split_entries <- function(hdr) {
  ch <- strsplit(hdr, "", fixed = TRUE)[[1]]
  inq <- FALSE
  cut <- integer()
  for (i in seq_along(ch)) {
    if (ch[i] == '"') inq <- !inq else if (ch[i] == ";" && !inq) cut <- c(cut, i)
  }
  if (!length(cut)) return(character())
  starts <- c(1L, cut + 1L)[seq_along(cut)]
  vapply(seq_along(cut), function(k) {
    paste(ch[starts[k]:(cut[k] - 1L)], collapse = "")
  }, "")
}

.px_quoted <- function(s) {
  out <- regmatches(s, gregexpr('"[^"]*"', s))[[1]]
  if (!length(out)) return(character())
  substr(out, 2L, nchar(out) - 1L)
}

# One header entry -> list(key, lang, args, value). `value` keeps quoted strings
# as a character vector and leaves bare values (numbers, YES/NO) as-is.
#
# The split on `=` is scanned, not regexed: PX dimension names may contain
# parentheses (px-x-0904010000_113 has `Kanton (-) / Gemeinde (......)`), so a
# `\(([^)]*)\)` argument pattern truncates the name and every CODES/VALUES
# lookup for that dimension then misses. Take the first `=` that is outside
# quotes AND at paren depth 0.
.px_entry <- function(txt) {
  ch <- strsplit(txt, "", fixed = TRUE)[[1]]
  inq <- FALSE; depth <- 0L; eq <- NA_integer_
  for (i in seq_along(ch)) {
    c_ <- ch[i]
    if (c_ == '"') inq <- !inq
    else if (!inq && c_ == "(") depth <- depth + 1L
    else if (!inq && c_ == ")") depth <- depth - 1L
    else if (!inq && depth == 0L && c_ == "=") { eq <- i; break }
  }
  if (is.na(eq)) return(NULL)
  lhs <- paste(ch[seq_len(eq - 1L)], collapse = "")
  val <- trimws(paste(ch[-seq_len(eq)], collapse = ""))

  m <- regmatches(lhs, regexec("^\\s*([A-Za-z0-9-]+)\\s*(\\[([a-z]{2})\\])?\\s*(\\((.*)\\))?\\s*$", lhs))[[1]]
  if (!length(m)) return(NULL)
  list(
    key   = m[2],
    lang  = if (nzchar(m[4])) m[4] else NA_character_,
    args  = .px_quoted(m[5]),
    value = if (grepl('^"', val)) .px_quoted(val) else trimws(val)
  )
}

.px_parse_header <- function(hdr) {
  es <- lapply(.px_split_entries(hdr), .px_entry)
  es[!vapply(es, is.null, TRUE)]
}

# Look up one header entry by key / language / argument.
.px_get <- function(entries, key, lang = NA_character_, arg = NULL) {
  for (e in entries) {
    if (!identical(e$key, key)) next
    if (!identical(e$lang, lang) && !(is.na(e$lang) && is.na(lang))) next
    if (!is.null(arg) && !identical(e$args[1], arg)) next
    return(e$value)
  }
  NULL
}

# ---- data block -----------------------------------------------------------

# PX missing-value tokens are runs of dots (".", "..", ... up to "......") and
# "-"; everything else is numeric. Quoted or bare, both occur in the wild.
.px_values <- function(body) {
  toks <- strsplit(trimws(sub(";\\s*$", "", body)), "[[:space:],]+")[[1]]
  toks <- toks[nzchar(toks)]
  toks <- gsub('"', "", toks, fixed = TRUE)
  suppressWarnings(as.numeric(ifelse(grepl("^(\\.+|-)$", toks), NA, toks)))
}

# ---- main entry point -----------------------------------------------------

# Fetch one FSO PX cube from DAM and return the same shape fso_fetch() returns:
# list(id, data = <dims + date + value>, meta = <title/source/license/freq/dims>).
#
#   select   named list pinning dimensions to a subset of codes, e.g.
#            list(Beschäftigungsgrad = "TOT", Geschlecht = "TOT"). This replaces
#            the hand-written PX-Web `query`: there is no cell cap, so a pin is
#            now purely a curation choice, not a transport workaround.
#   eliminate dimension names to collapse to their PX `ELIMINATION` level (the
#            cube's declared "total" for that axis). PX-Web applies this
#            IMPLICITLY to every dimension a query does not mention, which is why
#            the production hesta query never names `Herkunftsland` yet the stored
#            data has no country column. The .px route serves the whole cube, so
#            that implicit collapse has to be asked for. ELIMINATION names the
#            level by LABEL, not code, so it is resolved against VALUES.
#   lifecycle "CURRENT" (live cube) or "NON_CURRENT" (newest archived version).
fso_px_fetch <- function(dataset_id, table_id, title = NULL, select = NULL,
                         eliminate = character(), year_col = "Jahr",
                         month_col = "Monat", quarter_col = NULL,
                         lifecycle = "CURRENT") {
  asset <- .px_dam_asset(table_id, lifecycle)
  txt <- .px_text(asset$url)
  if (!grepl("^\\s*CHARSET", txt)) {
    stop(sprintf("DAM master for %s is not a PX file (got: %s)",
                 table_id, substr(txt, 1, 40)))
  }

  parts <- strsplit(txt, "\nDATA=", fixed = TRUE)[[1]]
  if (length(parts) < 2) stop(sprintf("no DATA block in PX file for %s", table_id))
  entries <- .px_parse_header(parts[1])
  vals <- .px_values(paste(parts[-1], collapse = "\nDATA="))

  langs <- .px_get(entries, "LANGUAGES")
  deflang <- .px_get(entries, "LANGUAGE")
  stub <- .px_get(entries, "STUB") %||% character()
  head <- .px_get(entries, "HEADING") %||% character()
  dim_ids <- c(stub, head)
  if (!length(dim_ids)) stop(sprintf("no STUB/HEADING in PX file for %s", table_id))

  # Codes + default-language labels, per dimension.
  codes <- lapply(dim_ids, function(d) {
    cd <- .px_get(entries, "CODES", arg = d)
    vl <- .px_get(entries, "VALUES", arg = d)
    # A dimension with no CODES (rare, e.g. a pure time axis) uses its labels as
    # codes, which is what PX-Web's json-stat does too.
    if (is.null(cd)) cd <- vl
    list(codes = cd, labels = vl)
  })
  names(codes) <- dim_ids

  n <- prod(vapply(codes, function(x) length(x$codes), 1L))
  if (length(vals) != n) {
    stop(sprintf("PX cell count mismatch for %s: header declares %d, DATA has %d",
                 table_id, n, length(vals)))
  }

  # Row-major with the LAST dimension varying fastest.
  grid <- expand.grid(lapply(rev(codes), function(x) x$codes),
                      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  grid <- grid[, rev(seq_along(grid)), drop = FALSE]
  names(grid) <- dim_ids
  grid$value <- vals
  data <- grid[!is.na(grid$value), , drop = FALSE]

  # Dimensions PX-Web would have eliminated implicitly.
  for (dn in eliminate) {
    if (!dn %in% names(data)) stop(sprintf("eliminate: no dimension '%s' in %s", dn, table_id))
    el <- .px_get(entries, "ELIMINATION", arg = dn)
    if (is.null(el)) stop(sprintf("dimension '%s' in %s declares no ELIMINATION level", dn, table_id))
    i <- match(el, codes[[dn]]$labels)
    if (is.na(i)) stop(sprintf("ELIMINATION level '%s' not found among '%s' values", el, dn))
    select[[dn]] <- codes[[dn]]$codes[i]
  }

  # Curation pins, applied after the cube is assembled.
  for (dn in names(select)) {
    if (!dn %in% names(data)) stop(sprintf("select: no dimension '%s' in %s", dn, table_id))
    data <- data[data[[dn]] %in% select[[dn]], , drop = FALSE]
  }

  # Localized labels. STUB[fr]/HEADING[fr] give the fr *names* of the same dims
  # in the same order, and VALUES[fr]("<fr name>") its level labels -- so the
  # merge key is position, not name.
  names_by_lang <- list()
  for (L in setdiff(langs, deflang)) {
    s <- .px_get(entries, "STUB", lang = L) %||% character()
    h <- .px_get(entries, "HEADING", lang = L) %||% character()
    if (length(c(s, h)) == length(dim_ids)) names_by_lang[[L]] <- c(s, h)
  }

  dimensions <- setNames(lapply(seq_along(dim_ids), function(i) {
    d <- dim_ids[i]
    cd <- codes[[d]]$codes
    lb <- codes[[d]]$labels %||% cd
    dim_label <- setNames(list(d), deflang)
    # Same shape write_dataset()/drop_lang_echo() expect: levels[[code]]$label$<lang>.
    lev_label <- setNames(lapply(seq_along(cd), function(j) {
      lab <- if (j <= length(lb) && !is.na(lb[j])) lb[j] else cd[j]
      list(label = setNames(list(lab), deflang))
    }), cd)
    for (L in names(names_by_lang)) {
      dn_L <- names_by_lang[[L]][i]
      dim_label[[L]] <- dn_L
      vl <- .px_get(entries, "VALUES", lang = L, arg = dn_L)
      if (is.null(vl) || length(vl) != length(cd)) next
      for (j in seq_along(cd)) lev_label[[cd[j]]]$label[[L]] <- vl[j]
    }
    list(label = dim_label, levels = lev_label)
  }), dim_ids)

  dated <- .fso_make_date(data, year_col, month_col, quarter_col)
  data <- dated$data
  data <- data[!is.na(data$date), , drop = FALSE]
  for (t in dated$used) dimensions[[t]] <- NULL
  dim_out <- setdiff(dim_ids, dated$used)

  data <- data |>
    dplyr::select(dplyr::all_of(c(dim_out, "date", "value"))) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(c(dim_out, "date"))))

  # LAST-UPDATED is "YYYYMMDD HH:MM"; the embargo is the dissemination date. The
  # json-stat route had neither, so the datasheets say "not published".
  lu <- .px_get(entries, "LAST-UPDATED")
  updated <- if (!is.null(lu)) as.character(as.Date(substr(lu, 1, 8), "%Y%m%d")) else NA_character_

  meta <- list(
    title = title %||% list(en = table_id),
    source = list(url = sprintf("https://www.bfs.admin.ch/asset/en/%s", table_id)),
    license = "fso",
    frequency = dated$freq,
    updated = updated,
    dimensions = dimensions
  )

  list(id = dataset_id, data = tibble::as_tibble(data), meta = meta)
}
