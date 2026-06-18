# Two-metric uptime tracker for the daily ETL.
#
# Rolls the per-run / per-dataset detail up into two binary daily metrics and a
# one-row-per-day history we can plot for long-term uptime and incident fix-speed:
#
#   pipeline         : did OUR ETL run to completion today? (green/red) -- stays green
#                      through a provider outage; red only when a run cancels/crashes.
#   run_through      : did every source fetch cleanly this run? (green/red) -- the honest
#                      upstream-delivery signal; ANY skip (503 or IP block) reddens it.
#   recently_updated : is everything that's expected to update fresh? (green/red)
#
# The three answer three different questions: pipeline = "is our automation healthy",
# run_through = "did upstream deliver", recently_updated = "is the data current". A
# provider outage reddens run_through but NOT pipeline -- our workflow did its job (kept
# previous data, reported), the source just didn't deliver.
#
# Issues are separate from metrics. Most fetch failures are NOT ours to fix: a
# network/provider error (5xx / timeout / connection failure) is shown on the dashboard and
# opens a grouped `etl-outage` issue ONLY after it persists >= ALERT_AFTER_DAYS; an
# actionable break (a 4xx or a parse error) opens a per-source `etl-skip` issue immediately.
# The routing is handed to skip_issues.sh via data/skips.json.
#
# Reads  : data/run.json (R/pipeline.R) + data/status.json (R/health.R)
# Writes : data/uptime.csv          (append/upsert one row per day -- the plottable history)
#          data/uptime.svg          (committed status-timeline chart, no extra deps)
#          data/badge-{pipeline,upstream,fresh}.json  (the 3 shields badges atop the README)
#          data/badge.json          (legacy overall badge, kept for external references)
#          data/skips.json          (per-id skip routing for skip_issues.sh: alarm vs outage)
#          UPTIME.md                (rendered dashboard: verdicts, uptime %, recent table)
#          README.md                (the <!-- DATA-HEALTH --> summary block)
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

# --- three daily metrics ----------------------------------------------------
#   pipeline         : did OUR ETL run to completion today? GREEN whenever a run writes a
#                      row (if this script is executing, the pipeline processed); a missing
#                      day (cancel / crash) is RED via gap-fill. This is independent of
#                      whether upstream delivered -- the streak that does NOT break for a
#                      provider outage or an IP block.
#   run_through      : did every source fetch cleanly THIS run? RED on ANY skip. The honest
#                      upstream-delivery signal (a 503 outage and a runner-IP block both
#                      redden it -- it means "we did not get fresh data this run").
#   recently_updated : is everything expected to update fresh? RED on stale data (lagging).
pipeline         <- GREEN
run_through      <- if (length(skipped_ids)) RED else GREEN
# recently_updated is computed above from the health board.

# --- classify skips for ALERTING (not for the metrics) ----------------------
# The metrics above don't care WHY a source failed. Classification only decides what, if
# anything, to file an ISSUE about -- because most fetch failures are not ours to fix:
#   network/provider error (HTTP 429/5xx, a timeout, a connection failure -- a provider
#     outage like the 2026-06-18 BFS DB outage, or the admin.ch runner-IP block): NOTHING to
#     do on our side. It shows on the dashboard (red "upstream" badge -> the current-run
#     list) and opens an issue ONLY if it persists >= ALERT_AFTER_DAYS, grouped into one
#     `etl-outage` issue. A short outage never files an issue.
#   actionable break (a 4xx, or a parse / validation error -- the source changed in a way
#     OUR parser must adapt to): opens a per-source `etl-skip` issue immediately.
NETWORK_RE       <- "HTTP (429|5[0-9][0-9])|Operation timed out|Timeout was reached|Failed to perform HTTP request|Could not resolve host|Failed to connect|Couldn't connect|Connection (refused|reset|timed out)"
ALERT_AFTER_DAYS <- 3L

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

skip_network   <- vapply(skipped_ids, function(id) grepl(NETWORK_RE, skip_errors[[id]] %||% ""), logical(1))
skip_consec    <- vapply(skipped_ids, function(id) prior_streak(id) + 1L, integer(1))
skip_escalated <- skip_network & (skip_consec >= ALERT_AFTER_DAYS)   # a network outage stuck too long
names(skip_network) <- names(skip_consec) <- names(skip_escalated) <- skipped_ids

actionable_ids <- skipped_ids[!skip_network]   # per-source `etl-skip` issue NOW
network_ids    <- skipped_ids[skip_network]    # dashboard-only unless escalated
escalated_ids  <- skipped_ids[skip_escalated]  # network skips that have crossed ALERT_AFTER_DAYS

# Sidecar consumed by .github/scripts/skip_issues.sh (runs right after this in both
# etl.yml and etl-retry.yml). route="alarm" -> per-source issue now (actionable break);
# route="outage" -> dashboard-only, grouped issue ONLY once escalated (>= ALERT_AFTER_DAYS).
writeLines(
  toJSON(list(
    ts               = run$ts %||% format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    alert_after_days = ALERT_AFTER_DAYS,
    skips = lapply(skipped_ids, function(id) list(
      id               = id,
      error            = unname(skip_errors[[id]] %||% ""),
      route            = if (isTRUE(skip_network[[id]])) "outage" else "alarm",
      escalated        = unname(skip_escalated[[id]]),
      consecutive_days = unname(skip_consec[[id]])
    ))
  ), auto_unbox = TRUE, pretty = TRUE),
  file.path(DATA, "skips.json")
)

# --- data/uptime.csv : upsert today's row -----------------------------------
# One row per day. Re-running on the same day replaces the row (idempotent, like the
# dedup commit in the workflow), so a manual re-run never double-counts.
COLS <- c("date", "pipeline", "run_through", "n_skipped", "skipped_ids",
          "recently_updated", "n_stale", "stale_ids", "n_datasets")

today_row <- data.frame(
  date             = today,
  pipeline         = pipeline,
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
# Back-fill the pipeline column for rows written before it existed: a recorded row means a
# run completed that day, so pipeline was green. Then pin to the canonical column set.
if (!"pipeline" %in% names(hist)) hist$pipeline <- GREEN
hist <- hist[, COLS, drop = FALSE]
hist <- hist[setdiff(hist$date %||% character(0), NA) != today, , drop = FALSE]
hist <- rbind(hist, today_row)
hist <- hist[order(as.Date(hist$date)), , drop = FALSE]
write.csv(hist[, COLS], CSV, row.names = FALSE, quote = TRUE)

# --- rolling stats (the "fix speed" read) -----------------------------------
hist$date <- as.Date(hist$date)

# Fill calendar gaps before computing anything. A day with no recorded row sits
# BETWEEN two recorded days (the tracker ran before and after, but that day's ETL
# did not complete). The metrics treat that gap differently:
#   pipeline         : DOWN (red) -- the whole point of this metric is "did the run happen";
#                      a missing row IS a run that did not complete.
#   run_through      : DOWN (red) -- a scheduled run that didn't complete fetched nothing.
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
  pipeline         = fill_daily("pipeline", RED),
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

stats <- lapply(c(pipeline = "pipeline", run_through = "run_through", recently_updated = "recently_updated"),
  function(col) list(
    up30    = uptime_pct(col, 30),
    up90    = uptime_pct(col, 90),
    current = current_incident(col),
    longest = longest_incident(col)
  ))

# --- data/uptime.svg : hand-rolled status timeline (no plotting deps) --------
# Last 90 calendar days, three rows of cells (pipeline / run-through / recently-updated).
# Cells are gap-filled the same way the percentages are (see `daily` above): a missed day
# inside the tracked span is red on pipeline + run-through (the run didn't happen) and
# carries the last known freshness on recently-updated. Days outside the tracked span
# render grey (no data).
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
    list(label = "Pipeline",         colors = lookup("pipeline")),
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
    '<text x="20" y="50" font-size="12" fill="#656d76">Pipeline %s%% · Run-through %s%% · Recently updated %s%% (30d) · generated %s</text>',
    esc(format(stats$pipeline$up30 %||% "—")),
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
  "Three binary daily metrics, one row per day (history in [`data/uptime.csv`](data/uptime.csv)):",
  "",
  sprintf("- %s **Pipeline** — %s.%s",
          emoji(pipeline),
          if (pipeline == GREEN) "the daily ETL ran to completion (this is **our** automation; it stays green even when a source is down)"
          else "the run did not complete",
          incident_note(stats$pipeline)),
  sprintf("- %s **Run-through (upstream)** — %s.%s",
          emoji(run_through),
          if (run_through == GREEN) "every source fetched cleanly this run"
          else sprintf("%d source(s) failed to fetch — **upstream did not deliver** (previous data kept)", length(skipped_ids)),
          incident_note(stats$run_through)),
  sprintf("- %s **Recently updated** — %s.%s",
          emoji(recently_updated),
          if (recently_updated == GREEN) "every dataset expected to update is fresh"
          else sprintf("%d dataset(s) stale", length(red_ids)),
          incident_note(stats$recently_updated)),
  "",
  "| Metric | Uptime 30d | Uptime 90d | Worst incident |",
  "|---|---:|---:|---:|",
  sprintf("| Pipeline | %s%% | %s%% | %d d |",
          format(stats$pipeline$up30 %||% "—"), format(stats$pipeline$up90 %||% "—"),
          stats$pipeline$longest),
  sprintf("| Run-through (upstream) | %s%% | %s%% | %d d |",
          format(stats$run_through$up30 %||% "—"), format(stats$run_through$up90 %||% "—"),
          stats$run_through$longest),
  sprintf("| Recently updated | %s%% | %s%% | %d d |",
          format(stats$recently_updated$up30 %||% "—"), format(stats$recently_updated$up90 %||% "—"),
          stats$recently_updated$longest),
  "",
  "![Uptime timeline](data/uptime.svg)",
  ""
)

# Current-run skip detail. Most fetch failures are NOT ours to fix: a network/provider
# error (5xx, timeout, connection failure) is shown here and only opens a grouped
# `etl-outage` issue after it persists >= ALERT_AFTER_DAYS. An actionable break (a 4xx, or
# a parse/validation error) opens a per-source `etl-skip` issue immediately.
md <- c(md, "## Current run-through")
if (!length(skipped_ids)) {
  md <- c(md, "", "\U00002705 Clean run-through — every source fetched and validated.")
} else {
  if (length(network_ids)) {
    md <- c(md, "",
      sprintf("\U000023F3 %d source(s) hit a network/provider error this run — **nothing to do on our side** (data preserved). An issue opens only if this persists ≥ %d days:",
              length(network_ids), ALERT_AFTER_DAYS),
      "")
    for (id in network_ids) md <- c(md, sprintf("- `%s` — %s%s", id, skip_errors[[id]] %||% "",
      if (isTRUE(skip_escalated[[id]])) sprintf(" **— escalated: %d consecutive days, see `etl-outage` issue**", skip_consec[[id]])
      else sprintf(" *(day %d)*", skip_consec[[id]])))
  }
  if (length(actionable_ids)) {
    md <- c(md, "",
      sprintf("\U0001F534 %d source(s) failed in a way **we must fix** (4xx / parse error) — each opens an `etl-skip` issue:", length(actionable_ids)),
      "")
    for (id in actionable_ids) md <- c(md, sprintf("- `%s` — %s", id, skip_errors[[id]] %||% ""))
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
  "| Date | Pipeline | Run-through | Recently updated | Skips | Stale |",
  "|---|---|---|---|---:|---:|")
cal <- data.frame(date = span, stringsAsFactors = FALSE)
cal$pipeline         <- unname(daily$pipeline)
cal$run_through      <- unname(daily$run_through)
cal$recently_updated <- unname(daily$recently_updated)
m <- match(cal$date, hist$date)
cal$n_skipped <- hist$n_skipped[m]
cal$n_stale   <- hist$n_stale[m]
recent <- tail(cal, 30L)
recent <- recent[order(recent$date, decreasing = TRUE), , drop = FALSE]
for (i in seq_len(nrow(recent))) {
  r <- recent[i, ]
  md <- c(md, sprintf("| %s | %s | %s | %s | %s | %s |",
    format(r$date), emoji(r$pipeline), emoji(r$run_through), emoji(r$recently_updated),
    if (is.na(r$n_skipped)) "\U000000B7" else r$n_skipped,
    if (is.na(r$n_stale))   "\U000000B7" else r$n_stale))
}
writeLines(md, file.path(REPO, "UPTIME.md"))

# --- shields.io endpoint badges (the three badges at the top of the README) ----------
# One verdict per metric, written independently so a provider outage reddens only
# "upstream" while "pipeline" stays green. The README badges link each to its overview
# (a red one lands you on the list of what's wrong).
write_badge <- function(file, label, ok, msg_ok, msg_bad) {
  writeLines(
    toJSON(list(schemaVersion = 1L, label = label,
                message = if (ok) msg_ok else msg_bad,
                color   = if (ok) "brightgreen" else "red"),
            auto_unbox = TRUE),
    file.path(DATA, file))
}
write_badge("badge-pipeline.json", "pipeline", pipeline == GREEN,
            "ok", sprintf("down %dd", stats$pipeline$current))
write_badge("badge-upstream.json", "upstream", run_through == GREEN,
            "all fetched", sprintf("%d not fetched", length(skipped_ids)))
write_badge("badge-fresh.json", "data freshness", recently_updated == GREEN,
            "all fresh", sprintf("%d stale", length(red_ids)))

# Legacy single "data health" badge kept for any external reference. Headline stays green
# while OUR pipeline runs and data is fresh; a passing upstream blip is not a product fault.
overall_green <- pipeline == GREEN && recently_updated == GREEN
writeLines(
  toJSON(list(schemaVersion = 1L, label = "data health",
              message = if (overall_green) {
                if (run_through == RED) sprintf("ok (%d upstream)", length(skipped_ids)) else "all green"
              } else paste(c(
                if (pipeline == RED)         "pipeline down",
                if (recently_updated == RED) sprintf("%d stale", length(red_ids))
              ), collapse = ", "),
              color = if (overall_green) "brightgreen" else "red"),
          auto_unbox = TRUE),
  file.path(DATA, "badge.json")
)

# --- README.md <!-- DATA-HEALTH --> block (uptime.R now owns it) -------------
readme_path <- file.path(REPO, "README.md")
block <- c(
  "<!-- DATA-HEALTH:START -->",
  sprintf("**ETL health** (run %s):", format(Sys.Date())),
  sprintf("- %s **Pipeline** — %s", emoji(pipeline),
          if (pipeline == GREEN) "our ETL ran to completion" else "the run did not complete"),
  sprintf("- %s **Run-through (upstream)** — %s", emoji(run_through),
          if (run_through == GREEN) "all sources fetched"
          else sprintf("%d source(s) not fetched (provider-side; data kept)", length(skipped_ids))),
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

cat(sprintf("uptime: pipeline %s / run-through %s (%d skip: %d network / %d actionable, %d escalated) / recently-updated %s — %d datasets\n",
            pipeline, run_through, length(skipped_ids),
            length(network_ids), length(actionable_ids), length(escalated_ids),
            recently_updated, n_datasets))
