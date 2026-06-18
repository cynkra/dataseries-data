# Two-metric uptime tracker for the daily ETL.
#
# Rolls the per-run / per-dataset detail up into two binary daily metrics and a
# one-row-per-day history we can plot for long-term uptime and incident fix-speed:
#
#   run_through      : did the scrape complete with zero HARD skips? (green/red)
#   recently_updated : is everything that's expected to update fresh? (green/red)
#
# A skip is the LEADING signal (a parser breaks the day a source changes format);
# staleness is the LAGGING one (a source goes quiet without erroring). Only a stale
# (red) dataset makes `recently_updated` red. The two are deliberately binary: an
# uptime metric wants a clean trip line, and the immediate skip alarm now covers
# early warning.
#
# Not every skip is OUR downtime: a transient upstream HTTP 5xx (the source is reachable
# but returns 503/502/504/429) is EXCUSED from run_through and routed to one grouped
# `etl-outage` issue, while a hard failure (4xx, transport failure, parse error, or a 5xx
# that persists >= ESCALATE_DAYS) breaks the streak and opens a per-source `etl-skip`
# alarm. See the classification block below; the routing is handed to skip_issues.sh via
# data/skips.json.
#
# Reads  : data/run.json (R/pipeline.R) + data/status.json (R/health.R)
# Writes : data/uptime.csv  (append/upsert one row per day -- the plottable history)
#          data/uptime.svg  (committed status-timeline chart, no extra deps)
#          data/badge.json  (shields.io endpoint badge: overall health, top of README)
#          data/skips.json   (per-id skip routing for skip_issues.sh: umbrella vs alarm)
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
# Collapse multi-line curl/httr2 messages to one line (and cap length) for tidy display
# in tables and issue bodies; the diagnostic phrases the classifier keys on survive.
oneline <- function(x) {
  x <- gsub("[[:space:]]+", " ", x %||% ""); x <- trimws(x)
  if (nchar(x) > 300) paste0(substr(x, 1, 297), "...") else x
}
skip_errors <- setNames(
  vapply(run$skipped %||% list(), function(s) oneline(s$error %||% ""), ""),
  skipped_ids
)
red_ids <- vapply(
  Filter(function(d) (d$status %||% "") == "red", status$datasets %||% list()),
  function(d) d$id %||% "?", ""
)
recently_updated <- if (length(red_ids)) RED else GREEN
n_datasets <- as.integer(status$counts$total %||% length(status$datasets %||% list()))

today <- format(Sys.Date())
CSV   <- file.path(DATA, "uptime.csv")

# --- classify skips: transient upstream outage vs hard ----------------------
# A skip is NOT automatically OUR downtime. The line is REACHABILITY: was the source host
# reachable but unable to serve usable data for a passing reason, or could we not reach /
# parse it at all?
#
#   TRANSIENT (excused from the streak, grouped into one auto-closing umbrella issue):
#     - an HTTP 429/5xx response (the host answered "temporarily unavailable / throttled" --
#       e.g. the 2026-06-18 BFS database outage: 503s across the FSO DAM API), or
#     - a read/body timeout AFTER the TCP connection was established ("Operation timed out
#       after N ms with M bytes received" -- an alive-but-overloaded host that hung past
#       req_timeout; same outage, just slower than a clean 503).
#   HARD (breaks the streak, opens a per-source `etl-skip` alarm):
#     - we could not REACH the host: DNS failure, connection refused/reset, or a *connect*-
#       phase timeout -- the admin.ch runner-IP-block signature, a silent TCP drop at the
#       connecttimeout (see dev/etl-reliability-log.md); or
#     - a 4xx (403 block / 404 moved), or the payload failed to parse (a format break).
# A server that owes us a response is a passing outage; a socket we can't open, or a
# changed payload, is a real problem.
#
# "Transient" has an expiry. A transient skip that persists for >= ESCALATE_DAYS consecutive
# days is no longer a passing blip (it could be a WAF/firewall answering 503, or a tarpit
# hanging the body, to mask a block), so it is PROMOTED to a hard skip. A genuinely
# persistent problem therefore always surfaces; the worst case is a <= 1-day delay.
TRANSIENT_RE      <- "HTTP (429|500|502|503|504)\\b|Operation timed out after"
HARD_TRANSPORT_RE <- "Could not resolve host|Failed to connect|Couldn't connect|Connection refused|Connection reset|Connection timed out"
ESCALATE_DAYS     <- 2L

# Consecutive prior days (strictly before today) an id appeared in uptime.csv's skips;
# today counts as +1, so a first-day skip has consecutive_days == 1. Reading the on-disk
# CSV (pre-upsert) keeps this idempotent on a same-day re-run.
prior_hist <- if (file.exists(CSV)) read.csv(CSV, colClasses = "character", check.names = FALSE) else NULL
prior_streak <- function(id) {
  if (is.null(prior_hist) || !nrow(prior_hist)) return(0L)
  h <- prior_hist[order(as.Date(prior_hist$date)), , drop = FALSE]
  h <- h[as.Date(h$date) < as.Date(today), , drop = FALSE]
  n <- 0L
  for (i in rev(seq_len(nrow(h)))) {
    ids <- strsplit(h$skipped_ids[i] %||% "", ";", fixed = TRUE)[[1]]
    if (id %in% ids) n <- n + 1L else break
  }
  n
}

skip_transient <- vapply(skipped_ids, function(id) {
  e <- skip_errors[[id]] %||% ""
  grepl(TRANSIENT_RE, e) && !grepl(HARD_TRANSPORT_RE, e)   # a connect-phase failure is never transient
}, logical(1))
skip_consec    <- vapply(skipped_ids, function(id) prior_streak(id) + 1L, integer(1))
skip_escalated <- skip_transient & (skip_consec >= ESCALATE_DAYS)
skip_hard      <- (!skip_transient) | skip_escalated
names(skip_transient) <- names(skip_consec) <- names(skip_escalated) <- names(skip_hard) <- skipped_ids

hard_ids     <- skipped_ids[skip_hard]    # break the streak + per-source `etl-skip` alarm
upstream_ids <- skipped_ids[!skip_hard]   # transient & not escalated -> umbrella, excused

# Run-through measures OUR pipeline: a transient upstream 5xx does not count as downtime.
run_through <- if (length(hard_ids)) RED else GREEN

# Sidecar consumed by .github/scripts/skip_issues.sh (runs right after this in both
# etl.yml and etl-retry.yml): the routing decision per skipped id, so the issue script
# stays a thin presenter and the classification lives in one place.
writeLines(
  toJSON(list(
    ts = run$ts %||% format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    skips = lapply(skipped_ids, function(id) list(
      id               = id,
      error            = unname(skip_errors[[id]] %||% ""),
      route            = if (isTRUE(skip_hard[[id]])) "alarm" else "umbrella",
      transient        = unname(skip_transient[[id]]),
      escalated        = unname(skip_escalated[[id]]),
      consecutive_days = unname(skip_consec[[id]])
    ))
  ), auto_unbox = TRUE, pretty = TRUE),
  file.path(DATA, "skips.json")
)

# --- data/uptime.csv : upsert today's row -----------------------------------
# One row per day. Re-running on the same day replaces the row (idempotent, like the
# dedup commit in the workflow), so a manual re-run never double-counts.
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

# Fill calendar gaps before computing anything. A day with no recorded row sits
# BETWEEN two recorded days (the tracker ran before and after, but that day's ETL
# did not complete). The two metrics treat that gap differently:
#   run_through      : DOWN (red) -- a scheduled run that didn't complete is downtime.
#   recently_updated : carry the last known state forward -- freshness persists; a
#                      missed run is not a day the data silently went stale, so if the
#                      data was fresh either side of the gap it was fresh that day too.
# We fill across the RECORDED span only (first..last recorded date). Days before
# tracking began or after the last run stay "no data" (grey in the chart) and are
# never counted as downtime.
span <- if (nrow(hist)) seq(min(hist$date), max(hist$date), by = "day") else as.Date(character(0))

fill_daily <- function(col, gap) {
  by_date <- setNames(hist[[col]], as.character(hist$date))
  last <- NA_character_
  out <- vapply(span, function(d) {
    key <- as.character(d)
    v <- if (key %in% names(by_date)) by_date[[key]] else NA_character_
    if (!is.na(v)) { last <<- v; v }
    else if (identical(gap, "carry")) last
    else gap
  }, "")
  setNames(out, as.character(span))
}

daily <- list(
  run_through      = fill_daily("run_through", RED),
  recently_updated = fill_daily("recently_updated", "carry")
)

uptime_pct <- function(col, days) {
  v <- daily[[col]]
  v <- v[as.Date(names(v)) > (Sys.Date() - days)]
  v <- v[!is.na(v)]
  if (!length(v)) return(NA_real_)
  round(100 * mean(v == GREEN), 1)
}

# Length (in days) of the trailing run of red days for a metric, over the gap-filled
# series: 0 when the latest day is green, else the current open-incident length.
current_incident <- function(col) {
  v <- daily[[col]]; v <- v[!is.na(v)]
  n <- length(v)
  i <- 0L
  while (i < n && v[n - i] == RED) i <- i + 1L
  i
}

# Longest red run anywhere in the history (worst incident, in days).
longest_incident <- function(col) {
  v <- daily[[col]]; v <- v[!is.na(v)]
  r <- rle(v == RED)
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
# Last 90 calendar days, two rows of cells (run-through / recently-updated). Cells
# are gap-filled the same way the percentages are (see `daily` above): a missed day
# inside the tracked span is red on run-through (downtime) and carries the last known
# freshness on recently-updated. Days outside the tracked span render grey (no data).
write_svg <- function(path) {
  col_green <- "#2ea44f"; col_red <- "#cf222e"; col_grey <- "#d0d7de"
  ndays <- 90L
  days  <- seq(Sys.Date() - (ndays - 1L), Sys.Date(), by = "day")
  lookup <- function(col) {
    d <- daily[[col]]
    vapply(days, function(dt) {
      key <- as.character(dt)
      v <- if (key %in% names(d)) d[[key]] else NA_character_
      if (is.na(v)) col_grey else if (v == GREEN) col_green else col_red
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
  legend <- list(c(col_green, "green"), c(col_red, "red"), c(col_grey, "no data"))
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
          if (run_through == GREEN) {
            if (length(upstream_ids))
              sprintf("no blocking skips (%d transient upstream skip(s), HTTP 5xx — excused)", length(upstream_ids))
            else "zero skips"
          } else {
            sprintf("%d blocking skip(s)%s", length(hard_ids),
                    if (length(upstream_ids)) sprintf(" + %d upstream (excused)", length(upstream_ids)) else "")
          },
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

# Current-run skip detail (this replaces the old SKIPS.md). A HARD skip opens a per-source
# `etl-skip` issue (the earliest sign a source changed format / is blocked); transient
# upstream 5xx skips are grouped into one auto-closing `etl-outage` issue and excused.
md <- c(md, "## Current run-through")
if (!length(skipped_ids)) {
  md <- c(md, "", "\U00002705 Clean run-through — every source fetched and validated.")
} else {
  if (length(hard_ids)) {
    md <- c(md, "",
      sprintf("\U0001F534 %d source(s) hard-failed this run — each opens an `etl-skip` issue:", length(hard_ids)),
      "")
    for (id in hard_ids) md <- c(md, sprintf("- `%s` — %s%s", id, skip_errors[[id]] %||% "",
      if (isTRUE(skip_escalated[[id]])) sprintf(" *(escalated: %d consecutive days)*", skip_consec[[id]]) else ""))
  }
  if (length(upstream_ids)) {
    md <- c(md, "",
      sprintf("\U000023F3 %d source(s) hit a transient upstream error (HTTP 5xx) — data preserved, grouped into one auto-closing `etl-outage` issue, NOT counted as downtime:", length(upstream_ids)),
      "")
    for (id in upstream_ids) md <- c(md, sprintf("- `%s` — %s", id, skip_errors[[id]] %||% ""))
  }
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

# Recent history table (newest first, last 30 days). Built from the gap-filled daily
# calendar, so a missed day shows up as its own row (run-through red, recently-updated
# carried forward) instead of silently vanishing. Skip/stale counts are "·" on a day
# with no recorded run.
md <- c(md, "", "## Recent history", "",
  "| Date | Run-through | Recently updated | Skips | Stale |",
  "|---|---|---|---:|---:|")
cal <- data.frame(date = span, stringsAsFactors = FALSE)
cal$run_through      <- unname(daily$run_through)
cal$recently_updated <- unname(daily$recently_updated)
m <- match(cal$date, hist$date)
cal$n_skipped <- hist$n_skipped[m]
cal$n_stale   <- hist$n_stale[m]
recent <- tail(cal, 30L)
recent <- recent[order(recent$date, decreasing = TRUE), , drop = FALSE]
for (i in seq_len(nrow(recent))) {
  r <- recent[i, ]
  md <- c(md, sprintf("| %s | %s | %s | %s | %s |",
    format(r$date), emoji(r$run_through), emoji(r$recently_updated),
    if (is.na(r$n_skipped)) "\U000000B7" else r$n_skipped,
    if (is.na(r$n_stale))   "\U000000B7" else r$n_stale))
}
writeLines(md, file.path(REPO, "UPTIME.md"))

# --- data/badge.json : shields.io endpoint badge (overall health, top of README) ---
# One green-or-red verdict over BOTH metrics: green only when the scrape ran clean
# AND nothing is stale. Read live by the shields badge at the top of the README.
overall_green <- run_through == GREEN && recently_updated == GREEN
badge_msg <- if (overall_green) {
  if (length(upstream_ids)) sprintf("all green (%d upstream skip(s))", length(upstream_ids)) else "all green"
} else paste(c(
  if (recently_updated == RED) sprintf("%d stale", length(red_ids)),
  if (run_through == RED)      sprintf("%d skip(s)", length(hard_ids))
), collapse = ", ")
writeLines(
  toJSON(list(schemaVersion = 1L, label = "data health",
              message = badge_msg, color = if (overall_green) "brightgreen" else "red"),
          auto_unbox = TRUE),
  file.path(DATA, "badge.json")
)

# --- README.md <!-- DATA-HEALTH --> block (uptime.R now owns it) -------------
readme_path <- file.path(REPO, "README.md")
block <- c(
  "<!-- DATA-HEALTH:START -->",
  sprintf("**ETL uptime** (run %s):", format(Sys.Date())),
  sprintf("- %s **Run-through** — %s", emoji(run_through),
          if (run_through == GREEN) {
            if (length(upstream_ids)) sprintf("clean (%d upstream skip(s) excused)", length(upstream_ids)) else "clean (0 skips)"
          } else sprintf("%d blocking skip(s)", length(hard_ids))),
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

cat(sprintf("uptime: run-through %s (%d hard / %d upstream skip(s)) / recently-updated %s — %d datasets (30d: %s%% / %s%%)\n",
            run_through, length(hard_ids), length(upstream_ids), recently_updated, n_datasets,
            format(stats$run_through$up30 %||% "—"),
            format(stats$recently_updated$up30 %||% "—")))
