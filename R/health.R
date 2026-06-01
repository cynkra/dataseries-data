# Data-health dashboard ("green or not") for every dataset.
#
# Reads data/catalog.json and scores each dataset's freshness: how old its latest
# observation (`end`) is versus today, judged against the expected publication lag
# for its `frequency`. Writes two artifacts and refreshes a README summary block:
#
#   data/status.json : machine-readable per-dataset status (clients / website can read it)
#   STATUS.md        : human-readable traffic-light table (renders on GitHub)
#   README.md        : the <!-- DATA-HEALTH --> summary block (counts + link)
#
# Run: Rscript R/health.R    (after R/pipeline.R; the daily GitHub Action runs both).
# No network, no heavy deps -- just the catalog the pipeline already wrote.

suppressPackageStartupMessages(library(jsonlite))

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a

root <- tryCatch(
  dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))),
  error = function(e) "R"
)
REPO  <- dirname(root)
DATA  <- file.path(REPO, "data")

# Expected maximum age (days) of the latest observation before we worry, by
# frequency. Tuned to real Swiss publication lag so normal cadence reads green and
# only genuine staleness flags. Each datapoint is dated period-START, which adds
# roughly one period to its apparent age on top of the source's own lag:
#   monthly   ~110d : a monthly figure lands ~2 months late; March is the newest
#                     point through ~end of June -> ~3 months old is still normal.
#   quarterly ~290d : BoP/IIP & GDP lag ~2-3 quarters; ~9 months old is normal.
#   annual    ~550d : annual series publish the prior year in the following spring.
#   daily     ~14d  : business-day series; covers weekends/holidays/short outages.
# Genuinely laggy or genuinely fast datasets can override per-id below.
fresh_days <- c(daily = 14, weekly = 21, monthly = 110, quarterly = 290, annual = 550)
DEFAULT_THRESHOLD <- 120L
AMBER_FACTOR <- 1.5  # past `threshold` = ageing; past 1.5x = stale (likely broken)

# Second freshness signal: when a dataset carries a source publication date
# (`updated`), a source that republished within ~one period is being maintained,
# so it's fresh even if its latest *observation* is naturally old. This is what
# keeps slow annual series (e.g. population: data dated period-start lags ~1.5y but
# the file is republished yearly) green, while still flagging a source that has
# genuinely gone quiet (e.g. CPI, frozen since the Dec-2025 rebasing).
pub_fresh_days <- c(daily = 60, weekly = 60, monthly = 75, quarterly = 200, annual = 430)
DEFAULT_PUB <- 120L

# Per-dataset overrides of the observation-age threshold (id -> max fresh age in
# days), for datasets whose real cadence differs from their frequency label. The
# SNB effective-FX and spot-rate cubes are genuinely *daily* but SNB publishes a
# whole month of daily values at once, so the latest point is normally up to ~1
# month old -- not stale. Cleaner than relabelling them monthly (they aren't).
OVERRIDE <- c(
  ch_snb_devwkieffid = 50L,
  ch_snb_rendeiduebd = 50L
)

score <- function(id, end_chr, frequency, updated) {
  end <- suppressWarnings(as.Date(substr(end_chr %||% NA, 1, 10)))
  thr <- if (id %in% names(OVERRIDE)) as.integer(OVERRIDE[[id]])
         else as.integer(fresh_days[[frequency %||% ""]] %||% DEFAULT_THRESHOLD)
  if (is.na(end)) {
    return(list(age_days = NA_integer_, threshold_days = thr, status = "unknown"))
  }
  age <- as.integer(Sys.Date() - end)
  status <- if (age <= thr) "green" else if (age <= AMBER_FACTOR * thr) "amber" else "red"

  # Publication-date fallback: a recently republished source is fresh regardless
  # of how old its last observation is. Only ever upgrades toward green.
  pub <- suppressWarnings(as.Date(substr(updated %||% NA, 1, 10)))
  if (!is.na(pub) && status != "green") {
    pthr <- as.integer(pub_fresh_days[[frequency %||% ""]] %||% DEFAULT_PUB)
    if (as.integer(Sys.Date() - pub) <= pthr) status <- "green"
  }
  list(age_days = age, threshold_days = thr, status = status)
}

catalog <- fromJSON(file.path(DATA, "catalog.json"), simplifyVector = FALSE)

rows <- lapply(catalog, function(e) {
  s <- score(e$id, e$end, e$frequency, e$updated)
  list(
    id        = e$id,
    title     = e$title$en %||% e$id,
    source    = e$source %||% NA_character_,
    frequency = e$frequency %||% NA_character_,
    end       = e$end %||% NA_character_,
    updated   = e$updated %||% NA_character_,
    age_days  = s$age_days,
    threshold_days = s$threshold_days,
    status    = s$status
  )
})

status_of <- vapply(rows, `[[`, "", "status")
counts <- list(
  green   = sum(status_of == "green"),
  amber   = sum(status_of == "amber"),
  red     = sum(status_of == "red"),
  unknown = sum(status_of == "unknown"),
  total   = length(rows)
)

checked <- format(Sys.time(), tz = "UTC", "%Y-%m-%d %H:%M UTC")

# --- data/status.json (machine-readable) ------------------------------------
writeLines(
  toJSON(list(checked = checked, counts = counts, datasets = rows),
         auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null"),
  file.path(DATA, "status.json")
)

# --- STATUS.md (human-readable traffic-light table) -------------------------
emoji <- c(green = "\U0001F7E2", amber = "\U0001F7E1", red = "\U0001F534", unknown = "\U0026AA")
summary_line <- sprintf(
  "%s %d fresh · %s %d ageing · %s %d stale · %s %d unknown — %d datasets",
  emoji["green"], counts$green, emoji["amber"], counts$amber,
  emoji["red"], counts$red, emoji["unknown"], counts$unknown, counts$total
)

# Worst first: red, amber, unknown, green; within a group, oldest first.
rank <- c(red = 0L, amber = 1L, unknown = 2L, green = 3L)
ord <- order(rank[status_of], -(vapply(rows, function(r) r$age_days %||% -Inf, numeric(1))))

table_rows <- vapply(rows[ord], function(r) sprintf(
  "| %s | `%s` | %s | %s | %s | %s |",
  emoji[r$status], r$id, r$title, r$frequency %||% "?",
  r$end %||% "?", if (is.na(r$age_days)) "?" else format(r$age_days, big.mark = ",")
), "")

status_md <- c(
  "# Data health",
  "",
  sprintf("_Last checked: **%s**. Auto-generated by `R/health.R` (daily GitHub Action). Do not edit by hand._", checked),
  "",
  summary_line,
  "",
  "A dataset is **\U0001F7E2 fresh** when its latest observation is within the expected",
  "publication lag for its frequency, **\U0001F7E1 ageing** when moderately overdue, and",
  "**\U0001F534 stale** when well past it — a likely source or scraper problem worth a look.",
  "**\U0026AA unknown** means the catalog had no usable `end` date.",
  "",
  "| | Dataset | Title | Freq | Last obs | Age (days) |",
  "|---|---|---|---|---|---:|",
  table_rows
)
writeLines(status_md, file.path(REPO, "STATUS.md"))

# --- README.md summary block (between markers; created on first run) ---------
readme_path <- file.path(REPO, "README.md")
block <- c(
  "<!-- DATA-HEALTH:START -->",
  sprintf("**Data health** (updated %s): %s %d · %s %d · %s %d · %s %d of %d datasets — see [STATUS.md](STATUS.md).",
          format(Sys.Date()), emoji["green"], counts$green, emoji["amber"], counts$amber,
          emoji["red"], counts$red, emoji["unknown"], counts$unknown, counts$total),
  "<!-- DATA-HEALTH:END -->"
)
if (file.exists(readme_path)) {
  readme <- readLines(readme_path, warn = FALSE)
  s <- grep("<!-- DATA-HEALTH:START -->", readme, fixed = TRUE)
  e <- grep("<!-- DATA-HEALTH:END -->", readme, fixed = TRUE)
  if (length(s) && length(e)) {
    tail <- if (e < length(readme)) readme[(e + 1L):length(readme)] else character(0)
    readme <- c(readme[seq_len(s - 1L)], block, tail)
  } else {
    readme <- c(readme, "", "## Data health", "", block)
  }
  writeLines(readme, readme_path)
}

cat(sprintf("health: %s\n  %d green / %d amber / %d red / %d unknown (of %d)\n",
            checked, counts$green, counts$amber, counts$red, counts$unknown, counts$total))
