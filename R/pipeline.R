# Tracer-bullet pipeline (R): one dataset per source -> files + catalog.
#
# Run: Rscript R/pipeline.R
# Writes into ./data: <id>.csv + <id>.json + <id>.parquet per dataset, plus
# catalog.json. The v0 proof that source -> CSV+JSON+catalog works end to end in
# R, on a representative dataset from each of SNB, KOF, FSO.

here <- function(...) file.path(dirname(sys.frame(1)$ofile %||% "."), ...)
`%||%` <- function(a, b) if (is.null(a)) b else a

# source the modules relative to this file
root <- tryCatch(
  dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))),
  error = function(e) "R"
)
for (f in c("dates.R", "http.R", "io.R", "source_snb.R", "source_kof.R",
            "source_fso.R", "source_fso_excel.R", "source_fso_excel_sets.R",
            "source_seco.R")) {
  source(file.path(root, f))
}

# Download an FSO Excel asset and run its bespoke parser, tagging the topic.
# The per-dataset parsers live in source_fso_excel_sets.R.
fso_excel_dataset <- function(id, order_nr, topic = NULL) {
  dl <- fso_excel_download(order_nr)
  ds <- get(paste0("fso_excel_", id), mode = "function")(dl$path, dl$pubdate)
  if (!is.null(topic)) ds$meta$topic <- topic
  ds
}

DATA_DIR <- file.path(dirname(root), "data")

# This run's skipped datasets (a transient fetch error skips one source and keeps
# going). Recorded so main() can append them to the skip history log.
.SKIPPED <- list()

# Run one fetch, tag it with a topic, and keep going on failure (a transient
# network error on one source must not lose the whole run).
.try_fetch <- function(label, expr, topic = NULL) {
  ds <- tryCatch(force(expr), error = function(e) {
    msg <- conditionMessage(e)
    cat(sprintf("  SKIP %-22s %s\n", label, msg))
    .SKIPPED[[length(.SKIPPED) + 1L]] <<- list(id = label, error = msg)
    NULL
  })
  if (!is.null(ds) && !is.null(topic)) ds$meta$topic <- topic
  ds
}

# The SNB cube API re-exports most of the Swiss macro economy through one
# uniform interface, so one fetcher covers GDP, prices, labour, money, rates,
# FX, balance of payments, banking and payments. The cube list (id/topic/title)
# lives in R/snb_cubes.tsv — the set the previous dataseries generation ingested,
# re-verified live. To add/remove a cube, edit that file, not this code.
read_snb_cubes <- function() {
  tsv <- read.delim(file.path(root, "snb_cubes.tsv"),
                    stringsAsFactors = FALSE, quote = "", encoding = "UTF-8")
  lapply(seq_len(nrow(tsv)), function(i) as.list(tsv[i, ]))
}

build <- function() {
  datasets <- list()
  add <- function(ds) if (!is.null(ds)) datasets[[length(datasets) + 1L]] <<- ds

  # SNB: the macro cube set (each cube = one dataset), read from snb_cubes.tsv.
  for (cu in read_snb_cubes()) {
    add(.try_fetch(paste0("ch_snb_", cu$cube_id),
                   snb_fetch(cu$cube_id, title = list(en = cu$title)), cu$topic))
  }

  # SECO: full GDP, swissdata format at source (rich multilingual + deep
  # production/expenditure/income hierarchy; the hardest UI case, ~107k rows).
  add(.try_fetch("ch_seco_gdp", seco_fetch("ch_seco_gdp"), "National accounts"))

  # KOF: the Economic Barometer (single monthly series).
  add(.try_fetch("ch_kof_barometer",
                 kof_fetch("ch.kof.barometer", title = list(en = "KOF Economic Barometer")),
                 "Business cycle"))

  # FSO: hotel overnight stays by tourism region, monthly.
  fso_query <- list(
    list(code = "Jahr", selection = list(filter = "all", values = list("*"))),
    list(code = "Monat", selection = list(filter = "item",
                                          values = as.list(as.character(1:12)))),
    list(code = "Tourismusregion", selection = list(filter = "all", values = list("*"))),
    list(code = "Indikator", selection = list(filter = "item", values = list("2")))
  )
  add(.try_fetch("ch_fso_hesta",
                 fso_fetch("ch_fso_hesta", "px-x-1003020000_103", fso_query,
                           title = list(en = "Hotel sector: overnight stays by tourism region")),
                 "Tourism"))

  # FSO: jobs by economic division, quarterly (the BESTA employment headline).
  # Full cube is 60 divisions x 10 levels x 3 sexes x 139 quarters (~250k cells),
  # so we take the headline slice (all divisions, level/sex = Total) and chunk by
  # quarter to stay under PX-Web's 5000-cell cap.
  besta_query <- list(
    list(code = "Wirtschaftsabteilung", selection = list(filter = "all", values = list("*"))),
    list(code = "Beschäftigungsgrad", selection = list(filter = "item", values = list("TOT"))),
    list(code = "Geschlecht", selection = list(filter = "item", values = list("TOT"))),
    list(code = "Quartal", selection = list(filter = "all", values = list("*")))
  )
  add(.try_fetch("ch_fso_besta",
                 fso_fetch("ch_fso_besta", "px-x-0602000000_101", besta_query,
                           title = list(en = "Jobs by economic division (quarterly)"),
                           quarter_col = "Quartal", chunk_by = "Quartal", chunk_size = 40L),
                 "Labour"))

  # FSO labour depth: job vacancies (leading indicator) + jobs by sex.
  add(.try_fetch("ch_fso_vacancies",
                 fso_fetch_auto("ch_fso_vacancies", "px-x-0602000000_103",
                                title = list(en = "Job vacancies by economic division")),
                 "Labour"))
  add(.try_fetch("ch_fso_jobs_sex",
                 fso_fetch_auto("ch_fso_jobs_sex", "px-x-0602000000_102",
                                title = list(en = "Jobs by economic division and sex")),
                 "Labour"))

  # FSO Excel-asset datasets (not in PX-Web): the macro depth — CPI, producer/
  # import prices, wages, population, unemployment, GDP by expenditure. Each is a
  # DAM xlsx download parsed by a bespoke fso_excel_<id>() in source_fso_excel_sets.R.
  # su-d-05.02.66 = LIK on the Dec-2025=100 base (full history since 1982). It
  # superseded su-d-05.02.67 (Dec-2020=100), which FSO froze at the Dec-2025 rebasing.
  add(.try_fetch("ch_fso_cpi",        fso_excel_dataset("ch_fso_cpi",        "su-d-05.02.66")))
  add(.try_fetch("ch_fso_ppi",        fso_excel_dataset("ch_fso_ppi",        "su-q-05.04.03.01-ppi-ipp")))
  add(.try_fetch("ch_fso_wage_idx",   fso_excel_dataset("ch_fso_wage_idx",   "je-e-03.04.03.00.04")))
  add(.try_fetch("ch_fso_pop",        fso_excel_dataset("ch_fso_pop",        "su-d-01.02.04.05")))
  add(.try_fetch("ch_fso_unemp_rate", fso_excel_dataset("ch_fso_unemp_rate", "je-d-03.03.01.03")))

  datasets
}

DATASHEET_DIR <- file.path(dirname(root), "datasets")

main <- function() {
  datasets <- build()
  # Index loop (not `for (ds in datasets)`): the datasheet merge must be written
  # BACK into `datasets`, else write_catalog() below serializes the un-merged
  # originals and concept/canonical/featured come out null in catalog.json.
  for (i in seq_along(datasets)) {
    # Curation (concept + canonical + featured) is derived from the datasheet, the source of truth.
    datasets[[i]]$meta <- modifyList(datasets[[i]]$meta,
                                     read_datasheet_meta(datasets[[i]]$id, DATASHEET_DIR))
    write_dataset(datasets[[i]], DATA_DIR)
    cat(sprintf("wrote %-22s %7d rows, %4d series  [%s]\n",
                datasets[[i]]$id, nrow(datasets[[i]]$data), n_series(datasets[[i]]$data),
                datasets[[i]]$meta$concept %||% "no datasheet"))
  }
  write_catalog(datasets, DATA_DIR)
  cat(sprintf("wrote catalog.json (%d datasets) -> %s\n", length(datasets), DATA_DIR))
  append_skip_log(.SKIPPED, DATA_DIR)
}

# Append this run's skips to data/skips.jsonl (one JSON object per run that had at
# least one skip; clean runs add nothing, so the file is a history of incident
# days). R/health.R renders the recent tail into SKIPS.md. We deliberately do NOT
# alarm on a skip -- a one-off fetch failure that fixes itself the next day is just
# logged; only a dataset that STAYS stale crosses the health threshold and opens an
# issue.
append_skip_log <- function(skipped, out_dir) {
  if (!length(skipped)) {
    cat("no skips this run\n")
    return(invisible())
  }
  rec <- list(
    ts = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    skipped = skipped
  )
  line <- jsonlite::toJSON(rec, auto_unbox = TRUE, null = "null")
  cat(line, "\n", file = file.path(out_dir, "skips.jsonl"), append = TRUE, sep = "")
  cat(sprintf("logged %d skip(s) -> skips.jsonl\n", length(skipped)))
}

main()
