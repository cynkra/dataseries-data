#!/usr/bin/env Rscript
# Compare the DAM .px route (R/source_fso_px.R) against the PX-Web json-stat
# route currently in production, for every fso-pxweb dataset.
#
# For each dataset: fetch both ways, then diff the DATA (cell by cell on the
# shared keys) and the META (dimension labels per language). Reports timing and
# request-count too. Read-only: writes nothing into data/.

`%||%` <- function(a, b) if (is.null(a)) b else a

suppressPackageStartupMessages({library(dplyr); library(tibble)})
for (f in c("R/http.R", "R/dates.R", "R/io.R", "R/source_fso.R",
            "R/source_fso_px.R")) source(f)

# The five fso-pxweb datasets, with the slice the datasheets curate.
SPECS <- list(
  list(id = "ch_fso_jobs_sex",      table = "px-x-0602000000_102", quarter_col = "Quartal",
       select = NULL),
  list(id = "ch_fso_vacancies",     table = "px-x-0602000000_103", quarter_col = "Quartal",
       select = NULL),
  list(id = "ch_fso_besta_outlook", table = "px-x-0602000000_105", quarter_col = "Quartal",
       select = list(`Voraussichtliche Beschäftigungsentwicklung` = "5", Gewichtung = "1")),
  list(id = "ch_fso_hesta",         table = "px-x-1003020000_103", quarter_col = NULL,
       select = list(Monat = as.character(1:12), Indikator = "2"),
       eliminate = "Herkunftsland"),
  # The CURRENT master for _101 is FSO's mis-uploaded CSV, so this one exercises
  # the NON_CURRENT fallback: the newest archived .px (one quarter behind).
  list(id = "ch_fso_besta",         table = "px-x-0602000000_101", quarter_col = "Quartal",
       select = list(`Beschäftigungsgrad` = "TOT", `Geschlecht` = "TOT"),
       lifecycle = "NON_CURRENT")
)

# Count HTTP calls per route by wrapping the shared helpers.
.CALLS <- new.env(parent = emptyenv())
.CALLS$n <- 0L
local({
  for (fn in c("get_json", "post_json")) {
    orig <- get(fn, envir = globalenv())
    assign(fn, local({
      f <- orig
      function(...) { .CALLS$n <- .CALLS$n + 1L; f(...) }
    }), envir = globalenv())
  }
  orig_px <- .px_text
  assign(".px_text", function(...) { .CALLS$n <- .CALLS$n + 1L; orig_px(...) },
         envir = globalenv())
})

timed <- function(expr) {
  .CALLS$n <- 0L
  t0 <- Sys.time()
  val <- tryCatch(expr, error = function(e) structure(list(msg = conditionMessage(e)),
                                                      class = "fetch_error"))
  list(value = val, secs = round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1),
       calls = .CALLS$n)
}

# Compare two long tibbles on their shared dimension columns + date.
diff_data <- function(new, old) {
  kd <- intersect(setdiff(names(new), c("date", "value")),
                  setdiff(names(old), c("date", "value")))
  key <- c(kd, "date")
  n <- new |> mutate(across(all_of(kd), as.character))
  o <- old |> mutate(across(all_of(kd), as.character))
  j <- full_join(n, o, by = key, suffix = c("_new", "_old"))
  both <- j |> filter(!is.na(value_new), !is.na(value_old))
  list(
    key_cols   = kd,
    n_new      = nrow(n),
    n_old      = nrow(o),
    only_new   = sum(is.na(j$value_old)),
    only_old   = sum(is.na(j$value_new)),
    compared   = nrow(both),
    exact      = sum(both$value_new == both$value_old),
    within_0.5 = sum(abs(both$value_new - both$value_old) <= 0.5),
    max_absdiff = if (nrow(both)) max(abs(both$value_new - both$value_old)) else NA_real_,
    decimals_new = sum(both$value_new %% 1 != 0),
    decimals_old = sum(both$value_old %% 1 != 0)
  )
}

langs_of <- function(dims) {
  if (!length(dims)) return(character())
  sort(unique(unlist(lapply(dims, function(d) {
    c(names(d$label), unlist(lapply(d$levels, function(l) names(l$label))))
  }))))
}

# Compare dimension + level labels, per language, between the two routes.
diff_meta <- function(new, old) {
  ds <- intersect(names(new), names(old))
  langs <- union(langs_of(new), langs_of(old))
  out <- list()
  for (L in langs) {
    same <- diff <- miss_new <- miss_old <- 0L
    ex <- character()
    for (d in ds) {
      lv <- union(names(new[[d]]$levels), names(old[[d]]$levels))
      for (code in lv) {
        a <- new[[d]]$levels[[code]]$label[[L]]
        b <- old[[d]]$levels[[code]]$label[[L]]
        if (is.null(a) && is.null(b)) next
        if (is.null(a)) { miss_new <- miss_new + 1L; next }
        if (is.null(b)) { miss_old <- miss_old + 1L; next }
        if (identical(a, b)) same <- same + 1L else {
          diff <- diff + 1L
          if (length(ex) < 2) ex <- c(ex, sprintf("%s/%s: px=%s | web=%s", d, code, a, b))
        }
      }
    }
    out[[L]] <- list(same = same, diff = diff, miss_new = miss_new,
                     miss_old = miss_old, ex = ex)
  }
  out
}

cat("\n================= DAM .px  vs  PX-Web json-stat =================\n")
results <- list()
for (s in SPECS) {
  cat(sprintf("\n### %s  (%s)\n", s$id, s$table))

  a <- timed(fso_px_fetch(s$id, s$table, select = s$select, quarter_col = s$quarter_col,
                          eliminate = s$eliminate %||% character(),
                          lifecycle = s$lifecycle %||% "CURRENT"))
  if (inherits(a$value, "fetch_error")) {
    cat(sprintf("  DAM .px   FAILED after %ss: %s\n", a$secs, a$value$msg))
  } else {
    cat(sprintf("  DAM .px   %6.1fs  %2d req  %7d rows  langs=%s  updated=%s\n",
                a$secs, a$calls, nrow(a$value$data),
                paste(langs_of(a$value$meta$dimensions), collapse = "/"),
                a$value$meta$updated %||% "NA"))
  }

  b <- timed(if (is.null(s$select)) {
    fso_fetch_auto(s$id, s$table)
  } else {
    q <- lapply(names(s$select), function(dn)
      list(code = dn, selection = list(filter = "item", values = as.list(s$select[[dn]]))))
    vars <- get_json(sprintf("https://www.pxweb.bfs.admin.ch/api/v1/en/%s/%s.px", s$table, s$table))$variables
    for (v in vars) if (!v$code %in% names(s$select))
      q <- c(q, list(list(code = v$code, selection = list(filter = "all", values = list("*")))))
    tcol <- if (is.null(s$quarter_col)) NULL else s$quarter_col
    fso_fetch(s$id, s$table, q, quarter_col = tcol,
              chunk_by = if (!is.null(tcol)) tcol else "Jahr", chunk_size = 40L)
  })
  if (inherits(b$value, "fetch_error")) {
    cat(sprintf("  PX-Web    FAILED after %ss: %s\n", b$secs, b$value$msg))
  } else {
    cat(sprintf("  PX-Web    %6.1fs  %2d req  %7d rows  langs=%s  updated=%s\n",
                b$secs, b$calls, nrow(b$value$data),
                paste(langs_of(b$value$meta$dimensions), collapse = "/"),
                b$value$meta$updated %||% "NA"))
  }

  if (!inherits(a$value, "fetch_error") && !inherits(b$value, "fetch_error")) {
    m <- diff_meta(a$value$meta$dimensions, b$value$meta$dimensions)
    cat("  level labels:")
    for (L in names(m)) cat(sprintf("  %s=%d/%d", L, m[[L]]$same, m[[L]]$same + m[[L]]$diff))
    cat("\n")
    for (L in names(m)) for (e in m[[L]]$ex) cat(sprintf("      [%s] %s\n", L, e))
  }

  # Against what is on disk today (the real regression check).
  disk_f <- file.path("data", paste0(s$id, ".csv"))
  if (!inherits(a$value, "fetch_error") && file.exists(disk_f)) {
    disk <- readr::read_csv(disk_f, show_col_types = FALSE) |> mutate(date = as.Date(date))
    d <- diff_data(a$value$data, disk)
    cat(sprintf("  vs data/%s.csv on key [%s]\n", s$id, paste(d$key_cols, collapse = ", ")))
    cat(sprintf("      rows new=%d disk=%d | only-new=%d only-disk=%d | compared=%d\n",
                d$n_new, d$n_old, d$only_new, d$only_old, d$compared))
    cat(sprintf("      exact match=%d  within 0.5=%d  max|diff|=%s\n",
                d$exact, d$within_0.5, format(d$max_absdiff)))
    cat(sprintf("      non-integer values: new=%d  disk=%d\n", d$decimals_new, d$decimals_old))
    results[[s$id]] <- d
  }
}
cat("\n")
