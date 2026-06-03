# Two-metric uptime tracker for the daily ETL.
#
# Rolls the per-run / per-dataset detail up into two binary daily metrics and a
# one-row-per-day history we can plot for long-term uptime and incident fix-speed:
#
#   run_through      : did the scrape complete with ZERO skips? (green/red)
#   recently_updated : is everything that's expected to update fresh? (green/red)
#
# A skip is the LEADING signal (a parser breaks the day a source changes format);
# staleness is the LAGGING one (a source goes quiet without erroring). amber on the
# per-dataset board does NOT make `recently_updated` red -- only a fully stale (red)
# dataset does. The two are deliberately binary: an uptime metric wants a clean trip
# line, and the immediate skip alarm now covers early warning.
#
# Reads  : data/run.json (R/pipeline.R) + data/status.json (R/health.R)
# Writes : data/uptime.csv  (append/upsert one row per day -- the plottable history)
#          data/uptime.svg  (committed status-timeline chart, no extra deps)
#          UPTIME.md         (rendered dashboard: verdicts, uptime %, recent table)
#          README.md         (the <!-- DATA-HEALTH --> summary block)
#
# Run: Rscript R/uptime.R   (after R/pipeline.R and R/health.R; the daily Action runs all three)

suppressPackageStartupMessages(library(jsonlite))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

root <- tryCatch(
  dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))),
  error = function(e) "R"
)
REPO <- dirname(root)
DATA <- file.path(REPO, "data")

GREEN <- "green"
RED   <- "red"

# --- read this run's inputs -------------------------------------------------
run    <- fromJSON(file.path(DATA, "run.json"),    simplifyVector = FALSE)
status <- fromJSON(file.path(DATA, "status.json"), simplifyVector = FALSE)

skipped_ids <- vapply(run$skipped %||% list(), function(s) s$id %||% "?", "")
skip_errors <- setNames(
  vapply(run$skipped %||% list(), function(s) s$error %||% "", ""),
  skipped_ids
)
run_through <- if (length(skipped_ids)) RED else GREEN

red_ids <- vapply(
  Filter(function(d) (d$status %||% "") == "red", status$datasets %||% list()),
  function(d) d$id %||% "?", ""
)
recently_updated <- if (length(red_ids)) RED else GREEN
n_datasets <- as.integer(status$counts$total %||% length(status$datasets %||% list()))

today <- format(Sys.Date())

# --- data/uptime.csv : upsert today's row -----------------------------------
# One row per day. Re-running on the same day replaces the row (idempotent, like the
# dedup commit in the workflow), so a manual re-run never double-counts.
CSV  <- file.path(DATA, "uptime.csv")
COLS <- c("date", "run_through", "n_skipped", "skipped_ids",
          "recently_updated", "n_stale", "stale_ids", "n_datasets")

today_row <- data.frame(
  date             = today,
  run_through      = run_through,
  n_skipped        = length(skipped_ids),
  skipped_ids      = paste(skipped_ids, collapse = ";"),
  recently_updated = recently_updated,
  n_stale          = length(red_ids),
  stale_ids        = paste(red_ids, collapse = ";"),
  n_datasets       = n_datasets,
  stringsAsFactors = FALSE
)

hist <- if (file.exists(CSV)) {
  read.csv(CSV, colClasses = "character", check.names = FALSE)
} else {
  today_row[0, , drop = FALSE]
}
hist <- hist[setdiff(hist$date %||% character(0), NA) != today, , drop = FALSE]
hist <- rbind(hist, today_row)
hist <- hist[order(as.Date(hist$date)), , drop = FALSE]
write.csv(hist[, COLS], CSV, row.names = FALSE, quote = TRUE)

# --- rolling stats (the "fix speed" read) -----------------------------------
hist$date <- as.Date(hist$date)

uptime_pct <- function(col, days) {
  recent <- hist[hist$date > (Sys.Date() - days), col]
  if (!length(recent)) return(NA_real_)
  round(100 * mean(recent == GREEN), 1)
}

# Length (in recorded days) of the trailing run of red rows for a metric: 0 when the
# latest day is green, else the current open-incident length.
current_incident <- function(col) {
  v <- hist[[col]]
  n <- length(v)
  i <- 0L
  while (i < n && v[n - i] == RED) i <- i + 1L
  i
}

# Longest red run anywhere in the history (worst incident, in recorded days).
longest_incident <- function(col) {
  r <- rle(hist[[col]] == RED)
  max(c(0L, r$lengths[r$values]))
}

stats <- lapply(c(run_through = "run_through", recently_updated = "recently_updated"),
  function(col) list(
    up30    = uptime_pct(col, 30),
    up90    = uptime_pct(col, 90),
    current = current_incident(col),
    longest = longest_incident(col)
  ))

# --- data/uptime.svg : hand-rolled status timeline (no plotting deps) --------
# Last 90 calendar days, two rows of cells (run-through / recently-updated). A day
# with no recorded row renders grey (the ETL did not complete that day = outage),
# which is exactly what we want the long-term picture to show.
write_svg <- function(path) {
  col_green <- "#2ea44f"; col_red <- "#cf222e"; col_grey <- "#d0d7de"
  ndays <- 90L
  days  <- seq(Sys.Date() - (ndays - 1L), Sys.Date(), by = "day")
  lookup <- function(col) {
    vapply(days, function(d) {
      row <- hist[hist$date == d, col]
      if (!length(row)) col_grey else if (row[1] == GREEN) col_green else col_red
    }, "")
  }
  rows <- list(
    list(label = "Run-through",      colors = lookup("run_through")),
    list(label = "Recently updated", colors = lookup("recently_updated"))
  )

  pad_l <- 150L; pad_t <- 70L
  cw <- 8L; ch <- 22L; gap <- 2L; rgap <- 14L
  width  <- pad_l + ndays * (cw + gap) + 20L
  height <- pad_t + length(rows) * (ch + rgap) + 40L

  esc <- function(x) gsub("&", "&amp;", x, fixed = TRUE)
  parts <- c(sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="-apple-system,Segoe UI,Helvetica,Arial,sans-serif">',
    width, height))
  parts <- c(parts, sprintf('<rect width="%d" height="%d" fill="#ffffff"/>', width, height))
  parts <- c(parts, sprintf(
    '<text x="20" y="30" font-size="18" font-weight="600" fill="#1f2328">Uptime — last %d days</text>', ndays))
  parts <- c(parts, sprintf(
    '<text x="20" y="50" font-size="12" fill="#656d76">Run-through %s%% (30d) · Recently updated %s%% (30d) · generated %s</text>',
    esc(format(stats$run_through$up30 %||% "—")),
    esc(format(stats$recently_updated$up30 %||% "—")), today))

  for (ri in seq_along(rows)) {
    y <- pad_t + (ri - 1L) * (ch + rgap)
    parts <- c(parts, sprintf(
      '<text x="%d" y="%d" font-size="13" fill="#1f2328" text-anchor="end">%s</text>',
      pad_l - 12L, y + ch - 6L, esc(rows[[ri]]$label)))
    for (di in seq_len(ndays)) {
      x <- pad_l + (di - 1L) * (cw + gap)
      parts <- c(parts, sprintf(
        '<rect x="%d" y="%d" width="%d" height="%d" rx="1.5" fill="%s"/>',
        x, y, cw, ch, rows[[ri]]$colors[di]))
    }
  }

  # x-axis end labels (oldest / newest date shown)
  axis_y <- pad_t + length(rows) * (ch + rgap) + 16L
  parts <- c(parts, sprintf(
    '<text x="%d" y="%d" font-size="11" fill="#656d76">%s</text>',
    pad_l, axis_y, format(days[1])))
  parts <- c(parts, sprintf(
    '<text x="%d" y="%d" font-size="11" fill="#656d76" text-anchor="end">%s</text>',
    width - 20L, axis_y, format(days[ndays])))

  # legend
  ly <- axis_y + 22L
  legend <- list(c(col_green, "green"), c(col_red, "red"), c(col_grey, "no run"))
  lx <- pad_l
  for (lg in legend) {
    parts <- c(parts, sprintf('<rect x="%d" y="%d" width="12" height="12" rx="1.5" fill="%s"/>', lx, ly - 10L, lg[1]))
    parts <- c(parts, sprintf('<text x="%d" y="%d" font-size="11" fill="#656d76">%s</text>', lx + 16L, ly, lg[2]))
    lx <- lx + 80L
  }

  parts <- c(parts, "</svg>")
  writeLines(parts, path)
}
write_svg(file.path(DATA, "uptime.svg"))

# --- UPTIME.md : the rendered dashboard -------------------------------------
emoji <- function(s) if (s == GREEN) "\U0001F7E2" else "\U0001F534"
checked <- run$ts %||% format(Sys.time(), tz = "UTC", "%Y-%m-%d %H:%M UTC")

incident_note <- function(st) {
  if (st$current > 0) sprintf(" — **open incident: %d day(s)**", st$current) else ""
}

md <- c(
  "# Uptime",
  "",
  sprintf("_Last run: **%s**. Auto-generated by `R/uptime.R` (daily GitHub Action). Do not edit by hand._", checked),
  "",
  "Two binary daily metrics, one row per day (history in [`data/uptime.csv`](data/uptime.csv)):",
  "",
  sprintf("- %s **Run-through** — the scrape completed with %s.%s",
          emoji(run_through),
          if (run_through == GREEN) "zero skips" else sprintf("%d skip(s)", length(skipped_ids)),
          incident_note(stats$run_through)),
  sprintf("- %s **Recently updated** — %s.%s",
          emoji(recently_updated),
          if (recently_updated == GREEN) "every dataset expected to update is fresh"
          else sprintf("%d dataset(s) stale", length(red_ids)),
          incident_note(stats$recently_updated)),
  "",
  "| Metric | Uptime 30d | Uptime 90d | Worst incident |",
  "|---|---:|---:|---:|",
  sprintf("| Run-through | %s%% | %s%% | %d d |",
          format(stats$run_through$up30 %||% "—"), format(stats$run_through$up90 %||% "—"),
          stats$run_through$longest),
  sprintf("| Recently updated | %s%% | %s%% | %d d |",
          format(stats$recently_updated$up30 %||% "—"), format(stats$recently_updated$up90 %||% "—"),
          stats$recently_updated$longest),
  "",
  "![Uptime timeline](data/uptime.svg)",
  ""
)

# Current-run skip detail (this replaces the old SKIPS.md). A skip opens an
# `etl-skip` issue immediately and is the earliest sign a source changed format.
md <- c(md, "## Current run-through")
if (!length(skipped_ids)) {
  md <- c(md, "", "\U00002705 Clean run-through — every source fetched and validated.")
} else {
  md <- c(md, "",
    sprintf("\U0001F534 %d source(s) failed to fetch this run — each opens an `etl-skip` issue:", length(skipped_ids)),
    "")
  for (id in skipped_ids) md <- c(md, sprintf("- `%s` — %s", id, skip_errors[[id]] %||% ""))
}

# Stale detail mirrors the per-dataset health board.
md <- c(md, "", "## Stale datasets")
if (!length(red_ids)) {
  md <- c(md, "", "\U00002705 Nothing stale — see the full board in [STATUS.md](STATUS.md).")
} else {
  md <- c(md, "",
    sprintf("\U0001F534 %d dataset(s) past their freshness threshold (detail in [STATUS.md](STATUS.md)):", length(red_ids)),
    "")
  for (id in red_ids) md <- c(md, sprintf("- `%s`", id))
}

# Recent history table (newest first, last 30 rows).
md <- c(md, "", "## Recent history", "",
  "| Date | Run-through | Recently updated | Skips | Stale |",
  "|---|---|---|---:|---:|")
recent <- tail(hist, 30L)
recent <- recent[order(recent$date, decreasing = TRUE), , drop = FALSE]
for (i in seq_len(nrow(recent))) {
  r <- recent[i, ]
  md <- c(md, sprintf("| %s | %s | %s | %s | %s |",
    format(r$date), emoji(r$run_through), emoji(r$recently_updated),
    r$n_skipped, r$n_stale))
}
writeLines(md, file.path(REPO, "UPTIME.md"))

# --- README.md <!-- DATA-HEALTH --> block (uptime.R now owns it) -------------
readme_path <- file.path(REPO, "README.md")
block <- c(
  "<!-- DATA-HEALTH:START -->",
  sprintf("**ETL uptime** (run %s):", format(Sys.Date())),
  sprintf("- %s **Run-through** — %s", emoji(run_through),
          if (run_through == GREEN) "clean (0 skips)" else sprintf("%d skip(s)", length(skipped_ids))),
  sprintf("- %s **Recently updated** — %s of %d datasets fresh", emoji(recently_updated),
          n_datasets - length(red_ids), n_datasets),
  "",
  "See [UPTIME.md](UPTIME.md) for the trend and [STATUS.md](STATUS.md) for the per-dataset board.",
  "<!-- DATA-HEALTH:END -->"
)
if (file.exists(readme_path)) {
  readme <- readLines(readme_path, warn = FALSE)
  s <- grep("<!-- DATA-HEALTH:START -->", readme, fixed = TRUE)
  e <- grep("<!-- DATA-HEALTH:END -->", readme, fixed = TRUE)
  if (length(s) && length(e)) {
    tail_lines <- if (e < length(readme)) readme[(e + 1L):length(readme)] else character(0)
    readme <- c(readme[seq_len(s - 1L)], block, tail_lines)
  } else {
    readme <- c(readme, "", "## Data health", "", block)
  }
  writeLines(readme, readme_path)
}

cat(sprintf("uptime: run-through %s / recently-updated %s — %d datasets (30d: %s%% / %s%%)\n",
            run_through, recently_updated, n_datasets,
            format(stats$run_through$up30 %||% "—"),
            format(stats$recently_updated$up30 %||% "—")))
