#!/usr/bin/env Rscript
# Delivery chain check, R side: runs the installed `dataseries` package (CRAN) on
# every selection in verify/out/chain/plan.json (written by `chain.py plan`) and
# dumps each result (codes as strings, NA as null, values as %.17g strings) to
# verify/out/chain/r/{id}__{sel}.json. Edge-case probes go to r/_edge.json and
# the package version to r/_session.json; chain.py compare reads them.
#
#   Rscript verify/chain/chain.R        # DS_RLIB=<dir> uses a private library

rlib <- Sys.getenv("DS_RLIB", unset = NA)
lib_loc <- if (is.na(rlib)) NULL else rlib
suppressPackageStartupMessages(library(dataseries, lib.loc = lib_loc))
library(jsonlite)

args <- commandArgs(trailingOnly = FALSE)
self <- normalizePath(sub("^--file=", "", args[grep("^--file=", args)]))
repo <- normalizePath(file.path(dirname(self), "..", ".."))
work <- file.path(repo, "verify", "out", "chain")
rdir <- file.path(work, "r")
dir.create(rdir, recursive = TRUE, showWarnings = FALSE)
unlink(list.files(rdir, pattern = "[.]json$", full.names = TRUE))

plan <- fromJSON(file.path(work, "plan.json"), simplifyVector = FALSE)
pause <- function() Sys.sleep(0.3)

dump_df <- function(df) {
  if (is.null(df)) return(list(null = TRUE))
  cols <- names(df)
  data <- lapply(cols, function(c) {
    x <- df[[c]]
    if (c == "value") {
      v <- ifelse(is.na(x), NA_character_, sprintf("%.17g", x))
    } else if (inherits(x, "Date")) {
      v <- format(x, "%Y-%m-%d")
    } else {
      v <- as.character(x)
    }
    lapply(v, function(e) if (is.na(e)) NULL else e)
  })
  names(data) <- cols
  list(columns = cols, classes = lapply(df, function(x) class(x)[1]),
       nrow = nrow(df), data = data)
}

ver <- as.character(packageVersion("dataseries", lib.loc = lib_loc))
for (p in plan) {
  dims <- lapply(p$dims, unlist)
  f <- file.path(rdir, paste0(p$id, "__", p$sel, ".json"))
  res <- tryCatch({
    pause()
    df <- if (length(dims)) ds(p$id, dims) else ds(p$id)
    dump_df(df)
  }, error = function(e) list(error = conditionMessage(e)))
  res$version <- ver
  writeLines(toJSON(res, auto_unbox = TRUE, null = "null", na = "null"), f)
}
cat("R selections done:", length(plan), "\n")

# ---------------------------------------------------------------------------
# edge cases
# ---------------------------------------------------------------------------
E <- list()
probe <- function(name, expr) {
  E[[name]] <<- tryCatch(expr, error = function(e) list(exception = conditionMessage(e)))
}

# 1. numeric-looking codes stay character, exactly as requested
probe("numeric_codes_strings", {
  cases <- list(
    list("ch_fso_cpi", list(item = "100_100")),
    list("ch_fso_cross_border_commuters", list(canton = c("1", "10"))),
    list("ch_fso_jobs_sex", list(Grossregion = "0", Wirtschaftssektor = "2",
                                 "Beschäftigungsgrad" = "4.1", Geschlecht = "TOT")),
    list("ch_snb_zavesic", list(D0 = c("50009999990", "149990"))),
    list("ch_fso_ppi", list(base = "1963")),
    list("ch_snb_zikrepro", list(D0 = c("025Q", "05Q"), D1 = "11")),
    list("ch_fso_besta", list(Wirtschaftsabteilung = "77+79-82")),
    list("ch_fso_trade_partner", list(partner = c("Korea (South)", "Hong Kong"),
                                      flow = "export", level = "country")),
    list("ch_seco_gdp", list(seas_adj = "na", type = "real", structure = "gdp")))
  out <- list()
  for (cs in cases) {
    pause()
    df <- ds(cs[[1]], cs[[2]])
    dimcols <- setdiff(names(df), c("date", "value"))
    got <- lapply(dimcols, function(c) sort(unique(ifelse(is.na(df[[c]]), "<NA>", df[[c]]))))
    names(got) <- dimcols
    want <- lapply(cs[[2]], sort)
    ok <- identical(sort(names(want)), sort(names(got))) &&
      all(vapply(names(want), function(n) identical(got[[n]], want[[n]]), logical(1)))
    out[[cs[[1]]]] <- list(requested = cs[[2]], got = got, columns = names(df),
                           classes = lapply(df[dimcols], class), ok = ok)
  }
  out
})

# 2. the literal code "NA" (ch_snb_bopcapbalq D0)
probe("na_code", {
  pause()
  df <- ds("ch_snb_bopcapbalq", D0 = "NA", D1 = "A")
  r <- list(rows = if (is.null(df)) NULL else nrow(df),
            D0_values = if (is.null(df)) NULL else unique(ifelse(is.na(df$D0), "<NA>", df$D0)),
            D0_is_na = if (is.null(df)) NULL else sum(is.na(df$D0)))
  pause()
  t <- tryCatch(colnames(ds("ch_snb_bopcapbalq", D0 = c("NA", "S"), D1 = "A", class = "ts")),
                error = function(e) paste("ERROR:", conditionMessage(e)))
  r$ts_colnames <- t
  r
})

# 3. missing values
probe("missing_values", {
  pause()
  df <- ds("ch_fso_ppi")
  list(rows = nrow(df), na_values = sum(is.na(df$value)))
})

# 4. from/to inclusive (Date and character bounds)
probe("from_to_inclusive", {
  cases <- list(
    list("ch_fso_cpi", list(item = "100_100"), "2025-01-01", "2025-06-01"),
    list("ch_seco_gdp", list(type = "real", structure = "gdp", seas_adj = "csa"), "2020-04-01", "2021-01-01"),
    list("ch_fso_pop", list(item = "pop_stock_jan"), "2010-01-01", "2012-01-01"),
    list("ch_fso_cpi", list(item = "100_100"), "2025-01-15", "2025-06-15"),
    list("ch_snb_devwkieffid", list(D0 = "K", D1 = "G"), "2026-01-05", "2026-01-09"))
  out <- list()
  for (cs in cases) {
    pause()
    a <- ds(cs[[1]], cs[[2]], from = cs[[3]], to = cs[[4]])
    pause()
    b <- ds(cs[[1]], cs[[2]], from = as.Date(cs[[3]]), to = as.Date(cs[[4]]))
    out[[paste(cs[[1]], cs[[3]], cs[[4]])]] <- list(
      dates_chr = format(a$date), dates_Date = format(b$date),
      same = identical(a, b))
  }
  out
})

# 5. wide (ts) format alignment when series have different date ranges
probe("wide_ts", {
  cases <- list(
    list("ch_fso_ppi", list(base = c("1963", "2020"))),
    list("ch_fso_cpi", list(item = c("100_100", "100_10100", "100_9726"))),
    list("ch_seco_gdp", list(type = "real", structure = c("gdp", "gva"), seas_adj = "csa")))
  out <- list()
  for (cs in cases) {
    pause()
    long <- ds(cs[[1]], cs[[2]])
    pause()
    x <- ds(cs[[1]], cs[[2]], class = "ts")
    dimcols <- setdiff(names(long), c("date", "value"))
    key <- do.call(paste, c(long[dimcols], sep = "."))
    tt <- time(x)
    fr <- frequency(x)
    # date of each ts row
    yr <- floor(as.numeric(tt) + 1e-8)
    per <- round((as.numeric(tt) - yr) * fr)
    mon <- if (fr == 12) per + 1 else if (fr == 4) per * 3 + 1 else rep(1, length(yr))
    tsd <- as.Date(sprintf("%04d-%02d-01", yr, mon))
    m <- unclass(x)
    if (is.null(dim(m))) m <- matrix(m, ncol = 1, dimnames = list(NULL, unique(key)))
    bad <- 0
    for (n in seq_len(nrow(long))) {
      r <- match(long$date[n], tsd)
      if (is.na(r) || !identical(unname(m[r, key[n]]), long$value[n])) bad <- bad + 1
    }
    out[[cs[[1]]]] <- list(colnames = colnames(x), tsp = tsp(x), long_rows = nrow(long),
                           nonnull = sum(!is.na(m)), misaligned = bad,
                           ok = bad == 0 && sum(!is.na(m)) == nrow(long))
  }
  out
})

# 6. ts date conventions per frequency
probe("ts_frequency", {
  cases <- list(
    list("ch_seco_gdp", list(type = "real", structure = "gdp", seas_adj = "csa")),
    list("ch_fso_pop", list(item = "pop_stock_jan")),
    list("ch_fso_cpi", list(item = "100_100")),
    list("ch_fso_construction_prices", list(worktype = "total")),
    list("ch_seco_wwa", list(structure = "seco_wwa")),
    list("ch_snb_capchstocki", list(D0 = "GDR")))
  out <- list()
  for (cs in cases) {
    pause()
    long <- ds(cs[[1]], cs[[2]])
    r <- tryCatch({
      x <- ds(cs[[1]], cs[[2]], class = "ts")
      list(tsp = tsp(x), length = length(x), nonnull = sum(!is.na(x)),
           first_date = format(min(long$date)), last_date = format(max(long$date)),
           long_rows = nrow(long))
    }, error = function(e) list(error = conditionMessage(e)))
    out[[cs[[1]]]] <- r
  }
  out
})

# 7. multi-code == union of single-code selections
probe("multi_code", {
  cases <- list(
    list("ch_fso_cpi", "item", c("100_100", "100_1"), list()),
    list("ch_seco_gdp", "structure", c("gdp", "gva"), list(type = "real", seas_adj = "csa")),
    list("ch_fso_trade_partner", "partner", c("Korea (South)", "Hong Kong"), list(flow = "export", level = "country")))
  out <- list()
  for (cs in cases) {
    d <- cs[[4]]; d[[cs[[2]]]] <- cs[[3]]
    pause()
    both <- ds(cs[[1]], d)
    parts <- lapply(cs[[3]], function(cc) { dd <- cs[[4]]; dd[[cs[[2]]]] <- cc; pause(); ds(cs[[1]], dd) })
    u <- do.call(rbind, parts)
    k1 <- do.call(paste, c(both[setdiff(names(both), "value")], list(sprintf("%.17g", both$value))))
    k2 <- do.call(paste, c(u[setdiff(names(u), "value")], list(sprintf("%.17g", u$value))))
    out[[cs[[1]]]] <- list(equal = setequal(k1, k2) && length(k1) == length(k2),
                           n_multi = nrow(both), n_union = nrow(u))
  }
  out
})

# 8. caching
probe("caching", {
  cache_rm()
  pause()
  a <- ds("ch_fso_cpi", item = "100_100")
  k <- cache_ls()
  a$value <- -1
  b <- ds("ch_fso_cpi", item = "100_100")
  m <- ds_meta("ch_fso_cpi"); m$dim_order <- c(m$dim_order, "MUTATED")
  m2 <- ds_meta("ch_fso_cpi")
  cache_rm()
  list(cache_keys = k, ds_mutation_isolated = all(b$value != -1),
       meta_mutation_isolated = !("MUTATED" %in% unlist(m2$dim_order)),
       n_keys_after_rm = length(cache_ls()))
})

# 9. discovery functions vs raw API
probe("discovery", {
  base <- sub("/$", "", Sys.getenv("DS_API", "https://dataseries.org"))
  pause()
  raw <- fromJSON(paste0(base, "/catalog"), simplifyVector = FALSE)
  cat <- ds_catalog()
  bad <- list()
  for (d in raw) {
    row <- cat[cat$id == d$id, ]
    chk <- list(title = d$title$en, frequency = d$frequency, start = d$start, end = d$end,
                n_series = d$n_series, topic = d$topic$key, source = d$source$name$en,
                concept = d$concept$en, license = d$license)
    for (n in names(chk)) {
      want <- chk[[n]]; got <- row[[n]]
      if (is.null(want)) want <- NA
      if (!isTRUE(all.equal(as.character(got), as.character(want))) &&
          !(is.na(got) && is.na(want))) {
        bad[[length(bad) + 1]] <- list(id = d$id, col = n, got = got, want = want)
      }
    }
  }
  de <- ds_catalog(lang = "de")
  pause()
  si <- ds_search()
  pause()
  rawsi <- fromJSON(paste0(base, "/search-index.json"), simplifyVector = FALSE)
  # ds_meta for every dataset vs the raw meta JSON
  mm <- character()
  for (id in cat$id) {
    pause()
    a <- ds_meta(id)
    b <- fromJSON(paste0(base, "/dataset/", id, "/meta"), simplifyVector = FALSE)
    if (!identical(a, b)) mm <- c(mm, id)
  }
  list(n_catalog = nrow(cat), n_raw = length(raw), field_mismatches = head(bad, 20),
       n_field_mismatches = length(bad), de_title_cpi = de$title[de$id == "ch_fso_cpi"],
       n_search = nrow(si), n_search_raw = length(rawsi),
       search_na_datasets = unique(si$dataset[is.na(si$code)]), meta_not_identical = mm)
})

# 10. error messages
probe("errors", {
  f <- function(expr) tryCatch({ r <- expr; if (is.null(r)) "NULL" else paste("data.frame", nrow(r)) },
                               error = function(e) paste("ERROR:", conditionMessage(e)))
  list(
    unknown_code = f(ds("ch_fso_cpi", item = "nonexistent")),
    unknown_dim = f(ds("ch_fso_cpi", bogus = "1")),
    unknown_dataset = f(ds("bogus_dataset")),
    empty_range = f(ds("ch_fso_cpi", item = "100_100", from = "2099-01-01")),
    numeric_code = f(ds("ch_fso_cross_border_commuters", canton = 1)))
})

# 11. dimension names with space / umlaut
probe("dim_names", {
  pause()
  a <- ds("ch_fso_vacancies", list("Offene Stellen" = "1", Wirtschaftsabteilung = "5-96"))
  pause()
  b <- ds("ch_fso_jobs_sex", list(Grossregion = "0", Wirtschaftssektor = "TOT",
                                  "Beschäftigungsgrad" = "TOT", Geschlecht = "TOT"))
  list(vacancies_columns = names(a), jobs_sex_columns = names(b),
       meta_dim_order_vacancies = unlist(ds_meta("ch_fso_vacancies")$dim_order))
})

writeLines(toJSON(E, auto_unbox = TRUE, null = "null", na = "null", digits = NA, pretty = TRUE),
           file.path(rdir, "_edge.json"))
writeLines(toJSON(list(version = ver, R = R.version.string, locale = Sys.getlocale("LC_CTYPE")),
                  auto_unbox = TRUE), file.path(rdir, "_session.json"))
cat("R edge probes done\n")
