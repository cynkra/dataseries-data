# Normalize source period strings to ISO first-of-period dates + a frequency.
#
# Sources speak different period dialects:
#   "1990-Q1" (SNB quarterly), "1984-12" (monthly), "2024" (annual),
#   "2024-03-01" (already ISO). We map all to the first day of the period.

to_iso <- function(period) {
  period <- trimws(period)
  out <- rep(NA_character_, length(period))

  is_iso <- grepl("^\\d{4}-\\d{2}-\\d{2}$", period)
  out[is_iso] <- period[is_iso]

  is_q <- grepl("^\\d{4}-?Q[1-4]$", period)
  if (any(is_q)) {
    yr <- as.integer(sub("^(\\d{4}).*", "\\1", period[is_q]))
    q <- as.integer(sub("^.*Q([1-4])$", "\\1", period[is_q]))
    out[is_q] <- sprintf("%04d-%02d-01", yr, (q - 1L) * 3L + 1L)
  }

  is_m <- grepl("^\\d{4}-\\d{2}$", period)
  out[is_m] <- paste0(period[is_m], "-01")

  is_y <- grepl("^\\d{4}$", period)
  out[is_y] <- paste0(period[is_y], "-01-01")

  if (anyNA(out)) {
    stop("unrecognized period format: ", period[which(is.na(out))[1]])
  }
  out
}

infer_frequency <- function(periods) {
  s <- if (length(periods)) trimws(periods[1]) else ""
  if (grepl("^\\d{4}-?Q[1-4]$", s)) return("quarterly")
  if (grepl("^\\d{4}-\\d{2}$", s)) return("monthly")
  if (grepl("^\\d{4}$", s)) return("annual")
  if (grepl("^\\d{4}-\\d{2}-\\d{2}$", s)) {
    # ISO dates carry no period granularity, so quarterly GDP and daily yields
    # look identical by format. Infer from the typical spacing between distinct
    # dates instead (median gap in days).
    d <- sort(unique(as.Date(periods)))
    if (length(d) < 2) return("unknown")
    g <- as.numeric(stats::median(diff(d)))
    if (g <= 3)   return("daily")
    if (g <= 10)  return("weekly")
    if (g <= 45)  return("monthly")
    if (g <= 135) return("quarterly")
    return("annual")
  }
  "unknown"
}
