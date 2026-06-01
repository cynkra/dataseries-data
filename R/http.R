# Thin HTTP helpers over httr2. Backoff/retry is centralized here: BFS PX-Web and
# the DAM asset API both throttle (HTTP 429) under burst load, and the FSO
# chunking multiplies call volume, so every request retries with backoff.

suppressPackageStartupMessages(library(httr2))

# Retry on 429 + transient 5xx, honoring Retry-After, with exponential backoff.
.with_retry <- function(req) {
  req |>
    req_retry(
      max_tries = 6,
      retry_on_failure = TRUE,
      is_transient = function(resp) resp_status(resp) %in% c(429, 500, 502, 503, 504),
      backoff = function(i) min(60, 2^i)
    )
}

get_json <- function(url) {
  request(url) |>
    req_timeout(60) |>
    .with_retry() |>
    req_perform() |>
    resp_body_json(simplifyVector = FALSE)
}

get_text <- function(url) {
  request(url) |>
    req_timeout(60) |>
    .with_retry() |>
    req_perform() |>
    resp_body_string()
}

post_json <- function(url, body) {
  request(url) |>
    req_timeout(90) |>
    req_body_json(body) |>
    .with_retry() |>
    req_perform() |>
    resp_body_json(simplifyVector = FALSE)
}

# Download a binary asset (FSO DAM master files: xlsx) to a path. Same retry.
download_binary <- function(url, target_file) {
  request(url) |>
    req_timeout(120) |>
    .with_retry() |>
    req_perform(path = target_file)
  target_file
}
