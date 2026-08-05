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

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

# schema 1.1: curated catalog strings may be a bare string OR an i18n label
# object OR (source) an object carrying one. One tolerant read, same rule the
# website applies — see spec/multilingual/2-design.md §6.
.disp <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  if (is.character(x)) return(as.character(x)[1])
  if (is.list(x)) {
    if (!is.null(x$name)) return(.disp(x$name))
    return(as.character(x$en %||% x[[1]])[1])
  }
  as.character(x)[1]
}

root <- tryCatch(
  dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))),
  error = function(e) "R"
)
REPO  <- dirname(root)
DATA  <- file.path(REPO, "data")

# Maximum age (days) of the latest observation before a dataset is flagged STALE,
# by frequency. This number IS the alarm line: an `end` older than it trips red and
# opens a data-health issue. It bakes in ~1.5x headroom over real Swiss publication
# cadence, so normal lag stays green and only a genuine stall trips red -- there is
# no separate "ageing" tier, just one threshold per dataset and no hidden multiplier.
# Each datapoint is dated period-START, which adds roughly one period to its apparent
# age on top of the source's own lag (normal-cadence age -> alarm line):
#   monthly   165d : a monthly figure lands ~2 months late; ~3 months old is normal,
#                    so we only flag past ~5.5 months of silence.
#   quarterly 435d : BoP/IIP & GDP lag ~2-3 quarters; ~9 months normal, flag past ~14.
#   annual    825d : annual series publish the prior year in the following spring.
#   daily      21d : business-day series; covers weekends/holidays/short outages.
# Genuinely laggy or genuinely fast datasets can override per-id below.
fresh_days <- c(daily = 21, weekly = 32, monthly = 165, quarterly = 435,
                `semi-annual` = 600, annual = 825)
DEFAULT_THRESHOLD <- 180L

# Second freshness signal: when a dataset carries a source publication date
# (`updated`), a source that republished within ~one period is being maintained,
# so it's fresh even if its latest *observation* is naturally old. This is what
# keeps slow annual series (e.g. population: data dated period-start lags ~1.5y but
# the file is republished yearly) green, while still flagging a source that has
# genuinely gone quiet (e.g. CPI, frozen since the Dec-2025 rebasing).
pub_fresh_days <- c(daily = 60, weekly = 60, monthly = 75, quarterly = 200,
                    `semi-annual` = 300, annual = 430)
DEFAULT_PUB <- 120L

# Per-dataset overrides of the stale threshold (id -> alarm age in days), for
# datasets whose real cadence differs from their frequency label. Each value is the
# normal published age plus ~1.5x headroom (the same baked-in tolerance as above):
#   devwkieffid/rendeiduebd : genuinely *daily*, but SNB publishes a whole month of
#                             daily values at once -> latest point normally ~1mo old.
#   zikredlauf : regular monthly, but SNB releases new-business lending rates with a
#                ~3-4 month lag, so the latest month is normally ~4 months old.
#   capchstocki : daily stock-index cube SNB refreshes with a ~2-week internal lag.
#   gdp_region  : regional GDP is a slow product — FSO releases a reference year ~2-3y
#                 late and only every ~1-2y (latest published = 2022, dated 2022-01-01,
#                 released 2024-10; verified no newer EN/DE asset exists). So the latest
#                 observation is normally ~4y old by its (year-start) date stamp.
#   pop_detail  : STATPOP year-end population stock, but dated year-start (2024-01-01 =
#                 end-2024) and carries no SDMX publish date to rescue it; reference year
#                 Y publishes ~Aug Y+1, so the latest point is normally ~1.5-2.5y old.
#   hicp        : Eurostat serves the Swiss HICP with a long lag (CH is non-EU); the
#                 latest period available is normally ~3-6 months old (verified live:
#                 Eurostat's newest CH point is 2025-12).
#   seco_wwa    : weekly nowcast, but SECO publishes the latest week with a ~2-3 week
#                 lag (and revises), so the newest point is normally ~3 weeks old.
# All verified against the live source cadence -- not stale, just slow-published.
OVERRIDE <- c(
  ch_snb_devwkieffid = 75L,
  ch_snb_rendeiduebd = 75L,
  ch_snb_zikredlauf  = 225L,
  ch_snb_capchstocki = 53L,
  ch_fso_gdp_region  = 2550L,
  ch_fso_pop_detail  = 1425L,
  ch_fso_hicp        = 315L,
  ch_seco_wwa        = 53L
)

score <- function(id, end_chr, frequency, updated) {
  end <- suppressWarnings(as.Date(substr(end_chr %||% NA, 1, 10)))
  thr <- if (id %in% names(OVERRIDE)) as.integer(OVERRIDE[[id]])
         else as.integer(fresh_days[[frequency %||% ""]] %||% DEFAULT_THRESHOLD)
  if (is.na(end)) {
    return(list(age_days = NA_integer_, threshold_days = thr, status = "unknown"))
  }
  age <- as.integer(Sys.Date() - end)
  status <- if (age <= thr) "green" else "red"

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
    title     = .disp(e$title) %||% e$id,
    source    = .disp(e$source),
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
emoji <- c(green = "\U0001F7E2", red = "\U0001F534", unknown = "\U0026AA")
summary_line <- sprintf(
  "%s %d fresh · %s %d stale · %s %d unknown — %d datasets",
  emoji["green"], counts$green,
  emoji["red"], counts$red, emoji["unknown"], counts$unknown, counts$total
)

# Worst first: red, unknown, green; within a group, oldest first.
rank <- c(red = 0L, unknown = 1L, green = 2L)
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
  "publication lag for its frequency, and **\U0001F534 stale** when past it — a likely",
  "source or scraper problem worth a look.",
  "**\U0026AA unknown** means the catalog had no usable `end` date.",
  "",
  "| | Dataset | Title | Freq | Last obs | Age (days) |",
  "|---|---|---|---|---|---:|",
  table_rows
)
writeLines(status_md, file.path(REPO, "STATUS.md"))

# Note: the fetch-skip log and the README <!-- DATA-HEALTH --> summary block are no
# longer written here. R/uptime.R (run right after this) rolls the per-dataset board
# and this run's skip outcome up into the two daily uptime metrics, owns UPTIME.md +
# data/uptime.csv, and is the single writer of the README block. This script's job is
# just the per-dataset freshness detail: status.json + STATUS.md.

cat(sprintf("health: %s\n  %d green / %d red / %d unknown (of %d)\n",
            checked, counts$green, counts$red, counts$unknown, counts$total))
