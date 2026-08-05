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
for (f in c("dates.R", "http.R", "datasheet.R", "io.R", "labels.R", "hierarchy.R", "source_snb.R", "source_kof.R",
            "source_fso.R", "source_fso_excel.R", "source_fso_excel_sets.R",
            "source_fso_dam_csv.R", "source_fso_sdmx.R", "source_eurostat.R",
            "source_seco.R", "source_ffa.R", "source_adecco.R")) {
  source(file.path(root, f))
}

# Base-R URL connections (SECO reads its CSV/JSON straight off a URL via readr /
# jsonlite, which honor getOption("timeout")) default to a 60s window. Halve it so
# an unreachable admin.ch host fails fast instead of stalling the run. The httr2
# sources are bounded separately in http.R (connecttimeout + max_seconds).
options(timeout = 30)

# Curated NOGA slices of the CH1.KEU SDMX turnover flows (see datasheets):
# retail = division 47; production = industry B-E (+ B/C/D) and construction F (41-43).
.SDMX_RETAIL_NOGA <- c("47", "4711", "4711_472", "4719", "4719_474-479", "472",
                       "473", "474", "475", "476", "477", "478_479", "47P",
                       "47P_Bekl", "47P_Food", "47P_Treib", "47P_UW",
                       "47PxTreib", "47x473")
.SDMX_PRODUCTION_NOGA <- c("B-E", "B", "C", "D", "F", "41", "42", "43", "41_43")
# services = tertiary NOGA sections (same DF_KEU_Q1 flow as production, disjoint codes).
.SDMX_SERVICES_NOGA <- c("G-NxK", "G", "H", "I", "J", "L", "M", "N")

# Download an FSO Excel asset and run its bespoke parser, tagging the topic.
# The per-dataset parsers live in source_fso_excel_sets.R. The order number is
# DECLARED in the datasheet ## Access block (read_access); passing it explicitly
# is only for one-off scripts pinning a different asset.
fso_excel_dataset <- function(id, order_nr = NULL, topic = NULL) {
  order_nr <- order_nr %||% read_access(id, DATASHEET_DIR)$identifier
  if (is.null(order_nr)) stop(sprintf("%s: no order number in datasheet ## Access", id))
  dl <- fso_excel_download(order_nr)
  ds <- get(paste0("fso_excel_", id), mode = "function")(dl$path, dl$pubdate)
  if (!is.null(topic)) ds$meta$topic <- topic
  ds
}

DATA_DIR <- file.path(dirname(root), "data")

# Redundant transform levels: series the app already reproduces on the fly from
# the base series via its Level / %-change / YoY / Index toggle. Storing them as
# dimension levels just duplicates a button, so we drop them at build time. Keyed
# dataset -> dim -> codes to remove. When a drop leaves a dimension single-valued
# (e.g. an "Index/Change" pair reduced to just the index), the whole dimension is
# removed: its column drops out of the data and it disappears from dim_order,
# single_select and default. The base level is always kept.
REDUNDANT_LEVELS <- list(
  ch_fso_wage_idx    = list(measure      = "change"),                 # YoY % vs previous year
  ch_fso_production  = list(UNIT_MEASURE = c("VARQ-4", "VARQ-1")),    # YoY + quarter-on-quarter
  ch_fso_services    = list(UNIT_MEASURE = c("VARQ-4", "VARQ-1")),    # YoY + quarter-on-quarter
  ch_fso_retail      = list(UNIT_MEASURE = c("VARM-12", "VARM-1")),   # YoY + month-on-month
  ch_fso_pop         = list(item         = "change_abs"),             # absolute first difference (rarely used)
  ch_snb_devwkibiim  = list(D2           = "V"),                      # YoY % (Index/Change)
  ch_snb_devwkieffid = list(D2           = "V"),                      # day-on-day % (Index/Change)
  ch_snb_snbmonagg   = list(D0           = "VV"),                     # YoY % (Level/change)
  ch_snb_plkopr      = list(D0           = "VVP"),                    # YoY % = the CPI inflation rate
  # Trade by goods: D2 mixes the nominal value (WMF) with nominal (N) and real (R)
  # YoY %-change leaves. N is exactly the YoY of WMF -> redundant; R (real, deflated)
  # is genuine and kept, so D2 survives with {WMF value, R real change}.
  ch_snb_ausshawarm  = list(D2           = "N")                       # nominal YoY % = YoY of WMF
)

# Recursively drop the given codes (keys) from a nested hierarchy tree.
prune_hierarchy <- function(node, codes) {
  if (!length(node)) return(node)
  node <- node[!names(node) %in% codes]
  for (k in names(node)) node[[k]] <- prune_hierarchy(node[[k]], codes)
  node
}

# Apply REDUNDANT_LEVELS to one built dataset: filter the data rows and prune the
# matching meta levels (and any hierarchy entries pointing at them). A no-op for
# datasets not in the table. Collapsing a now single-valued dimension is left to
# drop_degenerate_dims (run right after), so the two concerns stay separate. Runs
# after the datasheet merge.
drop_redundant_levels <- function(ds) {
  spec <- REDUNDANT_LEVELS[[ds$id]]
  if (is.null(spec)) return(ds)
  for (dn in names(spec)) {
    if (!dn %in% names(ds$data)) next
    codes <- spec[[dn]]
    ds$data <- ds$data[!ds$data[[dn]] %in% codes, , drop = FALSE]
    for (cd in codes) ds$meta$dimensions[[dn]]$levels[[cd]] <- NULL
    if (!is.null(ds$meta$dimensions[[dn]]$hierarchy))
      ds$meta$dimensions[[dn]]$hierarchy <-
        prune_hierarchy(ds$meta$dimensions[[dn]]$hierarchy, codes)
  }
  ds
}

# Drop any dimension the data pins to a single value: a one-option picker carries
# no choice, so it is pure noise. Removes the column + its dim meta, then cleans
# up dangling split / single_select / default references. Catches both
# pre-existing degenerate dims (e.g. a gender column that only ever carries
# "total") and dims left single-valued after drop_redundant_levels collapses an
# index/change pair down to just the index.
drop_degenerate_dims <- function(ds) {
  for (dn in dim_cols(ds$data)) {
    if (length(unique(as.character(ds$data[[dn]]))) <= 1L) {
      ds$data[[dn]] <- NULL
      ds$meta$dimensions[[dn]] <- NULL
    }
  }
  keep <- dim_cols(ds$data)
  if (!is.null(ds$meta$split) && !ds$meta$split %in% keep) ds$meta$split <- NULL
  ds$meta$single_select <- intersect(ds$meta$single_select, keep)
  if (!is.null(ds$meta$default))
    ds$meta$default <- ds$meta$default[names(ds$meta$default) %in% keep]
  ds
}

# This run's skipped datasets (a transient fetch error skips one source and keeps
# going). Recorded so main() can append them to the skip history log.
.SKIPPED <- list()

# When non-NULL, .try_fetch runs ONLY these dataset ids and no-ops the rest. The
# retry pass (main()) sets it to the first pass's skipped ids so build() can be
# replayed for just those, reconstructing each fetch fresh (loop variables, query
# lists) rather than replaying a stale captured call. NULL = run everything.
.ONLY <- NULL

# Run one fetch, tag it with a topic, and keep going on failure (a transient
# network error on one source must not lose the whole run).
.try_fetch <- function(label, expr, topic = NULL) {
  # Retry-pass filter: if a subset is pinned and this isn't in it, return before
  # forcing `expr` -- the fetch is a lazy promise, so an excluded source makes no
  # network call. `label` is already evaluated (we matched on it); `expr` is not.
  if (!is.null(.ONLY) && !label %in% .ONLY) return(NULL)
  # force() the fetch AND validate it inside the same guard: a structural failure
  # (or a parser's own fail-closed value-anchor stop()) skips this one dataset and
  # is logged, rather than silently shipping a bad parse or halting the whole run.
  #
  # Wall-clock backstop: no single source may run away with the shared run budget.
  # Network hangs are bounded at the transport layer (http.R / options(timeout));
  # this catches the rest -- a pathological parse -- and is cleared on exit so the
  # cap never leaks into the next source. Together these stop one bad source from
  # eating the 30-min job budget (the cause of the cancelled 2026-06-05 run).
  setTimeLimit(elapsed = 240, transient = FALSE)
  on.exit(setTimeLimit(), add = TRUE)
  ds <- tryCatch({ d <- force(expr); validate_dataset(d); d }, error = function(e) {
    msg <- conditionMessage(e)
    cat(sprintf("  SKIP %-22s %s\n", label, msg))
    .SKIPPED[[length(.SKIPPED) + 1L]] <<- list(id = label, error = msg)
    NULL
  })
  if (!is.null(ds) && !is.null(topic)) ds$meta$topic <- topic
  ds
}

# Ids skipped this run because the source reports it is UNCHANGED since our last fetch
# (see .try_fetch_if_unchanged). Distinct from .SKIPPED (a failure): an unchanged source
# is a success we simply didn't re-download. main()/retry_skipped() reload these from disk
# so they still flow through the catalog. Accumulates across the build + retry passes
# (reset at each entrypoint, like .SKIPPED), never inside build().
.UNCHANGED <- character(0)

# The `updated` token last written to disk for `id` (the source publish date), or NULL if
# there's no sidecar yet / no token stored. Compared against a fresh probe to decide
# whether a cube can be skipped.
.stored_updated <- function(id, dir) {
  p <- file.path(dir, paste0(id, ".json"))
  if (!file.exists(p)) return(NULL)
  m <- tryCatch(jsonlite::fromJSON(p, simplifyVector = FALSE), error = function(e) NULL)
  m$updated
}

# Reload an already-written dataset from disk into the in-memory {id, data, meta} shape,
# so an unchanged source can skip its (re-)fetch+parse yet still be catalogued exactly
# like a fresh one. The on-disk sidecar holds the FULLY finalized meta (datasheet merge,
# dropped levels, hierarchy) and the CSV the finalized data, so no re-finalize is needed
# -- catalog_entry() reads them straight. `fetched_utc` is intentionally NOT bumped: it
# means "when we last actually fetched", which an unchanged run did not. NULL if files
# are missing (caller drops it, falling back to a fetch next run).
load_dataset <- function(id, dir) {
  jp <- file.path(dir, paste0(id, ".json"))
  cp <- file.path(dir, paste0(id, ".csv"))
  if (!file.exists(jp) || !file.exists(cp)) return(NULL)
  meta <- tryCatch(jsonlite::fromJSON(jp, simplifyVector = FALSE), error = function(e) NULL)
  data <- tryCatch(readr::read_csv(cp, show_col_types = FALSE, progress = FALSE),
                   error = function(e) NULL)
  if (is.null(meta) || is.null(data)) return(NULL)
  if ("date" %in% names(data)) data$date <- as.Date(data$date)
  list(id = id, data = as.data.frame(data), meta = meta)
}

# Conditional fetch (pilot: SNB). `probe` returns a cheap version token; when it equals
# the token stored in the on-disk sidecar AND a disk copy exists, record `label` as
# unchanged and SKIP the full fetch+parse (the caller reloads it from disk). A missing or
# failed probe (NA), no disk copy, no stored token, or a changed token all fall through to
# the normal .try_fetch -- so first-ever runs and genuine updates always fetch, and a probe
# outage degrades safely to current behavior. Honors .ONLY like .try_fetch.
.try_fetch_if_unchanged <- function(label, probe, expr, topic = NULL) {
  if (!is.null(.ONLY) && !label %in% .ONLY) return(NULL)
  # ETL_FORCE_REFETCH=1 bypasses the unchanged-skip: needed when the PIPELINE's
  # output changed while the source did not (e.g. labels now fetched in more
  # languages) — a plain run would keep the stale-shaped sidecar until the
  # source's next edition.
  if (nzchar(Sys.getenv("ETL_FORCE_REFETCH"))) return(.try_fetch(label, expr, topic))
  token  <- tryCatch(probe(), error = function(e) NA_character_)
  stored <- .stored_updated(label, DATA_DIR)
  unchanged <- !is.na(token) && !is.null(stored) &&
    identical(as.character(token), as.character(stored)) &&
    file.exists(file.path(DATA_DIR, paste0(label, ".csv")))
  if (unchanged) {
    cat(sprintf("  KEEP %-22s unchanged since %s -- skipping fetch+parse\n", label, token))
    .UNCHANGED[[length(.UNCHANGED) + 1L]] <<- label
    return(NULL)
  }
  .try_fetch(label, expr, topic)
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

build <- function(only = NULL) {
  # `only` pins the run to a subset of ids (used by the retry pass). It is read by
  # .try_fetch via the .ONLY global; cleared on exit so a plain build() runs all.
  .ONLY <<- only
  on.exit(.ONLY <<- NULL, add = TRUE)
  datasets <- list()
  add <- function(ds) if (!is.null(ds)) datasets[[length(datasets) + 1L]] <<- ds

  # SNB: the macro cube set (each cube = one dataset), read from snb_cubes.tsv.
  # Conditional fetch: SNB's cheap `lastUpdate` (~65 B) lets us skip the 0.2-1.1 MB
  # download + parse of a cube unchanged since our last run (most days, for monthly /
  # quarterly cubes). `local()` pins this iteration's cube_id into the probe closure.
  for (cu in read_snb_cubes()) {
    cube <- cu$cube_id
    add(.try_fetch_if_unchanged(
      paste0("ch_snb_", cube),
      local({ id <- cube; function() snb_last_update(id) }),
      snb_fetch(cube), cu$topic))
  }

  # SECO: full GDP, swissdata format at source (rich multilingual + deep
  # production/expenditure/income hierarchy; the hardest UI case, ~107k rows).
  add(.try_fetch("ch_seco_gdp", seco_fetch("ch_seco_gdp"), "National accounts"))

  # SECO: consumer sentiment survey, swissdata at source (back to 1972-Q4). This
  # is the TRUE producer — it replaces the retired SNB re-export ch_snb_concon —
  # and adds the seasonally-adjusted track SECO publishes alongside the raw balances.
  add(.try_fetch("ch_seco_concon",
                 seco_fetch("ch_seco_concon",
                            data_url = "https://scheduler.swissdatas.ch/scheduled/ks-q.csv",
                            meta_url = "https://scheduler.swissdatas.ch/scheduled/ch-seco-ks-q.json"),
                 "Business surveys"))

  # FSO SDMX (CH1.KEU): turnover flows migrated off the dead PX-Web onto
  # disseminate.stats.swiss. Retail = monthly DF_KEU_M1 (NOGA division 47);
  # industry + construction = quarterly DF_KEU_Q1 (NOGA B-E + F, divisions 41-43).
  add(.try_fetch("ch_fso_retail",
                 fso_sdmx_fetch("ch_fso_retail", "CH1.KEU", "DF_KEU_M1", "1.0.0",
                                noga_keep = .SDMX_RETAIL_NOGA),
                 "Domestic economy"))
  add(.try_fetch("ch_fso_production",
                 fso_sdmx_fetch("ch_fso_production", "CH1.KEU", "DF_KEU_Q1", "1.0.0",
                                noga_keep = .SDMX_PRODUCTION_NOGA),
                 "Domestic economy"))
  add(.try_fetch("ch_fso_services",
                 fso_sdmx_fetch("ch_fso_services", "CH1.KEU", "DF_KEU_Q1", "1.0.0",
                                noga_keep = .SDMX_SERVICES_NOGA),
                 "Domestic economy"))

  # FSO SDMX, sliced to the national total (cubes too large to pull whole):
  # new car registrations by fuel (the EV-transition read) and vacant dwellings.
  add(.try_fetch("ch_fso_new_vehicles",     fso_sdmx_new_vehicles(),     "Mobility"))
  add(.try_fetch("ch_fso_vacant_dwellings", fso_sdmx_vacant_dwellings(), "Construction and housing"))
  # FSO SDMX, sliced national: foreign cross-border commuters by canton (quarterly,
  # model-based estimate) + permanent resident population by nationality x sex (annual).
  add(.try_fetch("ch_fso_cross_border_commuters", fso_sdmx_cross_border_commuters(), "Labour"))
  add(.try_fetch("ch_fso_pop_detail",             fso_sdmx_pop_detail(),             "Population"))

  # FFA / EFV: general-government public finances (FS + GFS model headline
  # aggregates — revenue, expenditure, balance, gross/net debt, debt-to-GDP), annual,
  # by government level. From opendata.swiss (CKAN) -> data.finance.admin.ch CSV.
  add(.try_fetch("ch_ffa_finances",
                 ffa_fetch("ch_ffa_finances"),
                 "Public finances"))

  # KOF: the Economic Barometer (single monthly series).
  add(.try_fetch("ch_kof_barometer",
                 kof_fetch("ch.kof.barometer"),
                 "Business cycle"))
  # KOF Economic Sentiment Index (ESI), monthly, via the open OGD /sets endpoint
  # (two methodology versions: pre-Brexit + standard 2018).
  add(.try_fetch("ch_kof_esi",
                 kof_set_fetch("ogd_ch.kof.esi",
                               source_url = "https://kof.ethz.ch/en/forecasts-and-indicators/indicators/kof-economic-sentiment-indicator.html"),
                 "Business cycle"))

  # University of Zurich / Adecco Group Swiss Job Market Index — a non-government
  # provider; quarterly index of advertised job openings (leading labour indicator).
  add(.try_fetch("ch_adecco_sjmi", adecco_fetch("ch_adecco_sjmi"), "Labour"))

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
                           ),
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
                           quarter_col = "Quartal", chunk_by = "Quartal", chunk_size = 40L),
                 "Labour"))

  # FSO labour depth: job vacancies (leading indicator) + jobs by sex.
  add(.try_fetch("ch_fso_vacancies",
                 fso_fetch_auto("ch_fso_vacancies", "px-x-0602000000_103",
                                ),
                 "Labour"))
  add(.try_fetch("ch_fso_jobs_sex",
                 fso_fetch_auto("ch_fso_jobs_sex", "px-x-0602000000_102",
                                ),
                 "Labour"))
  # FSO BESTA employment-outlook index (forward-looking labour indicator), quarterly.
  # The composite index (code 5), weighted by jobs (code 1); the two pinned dims drop
  # out as degenerate, leaving Wirtschaftsabteilung (20 NOGA divisions).
  besta_outlook_query <- list(
    list(code = "Wirtschaftsabteilung", selection = list(filter = "all", values = list("*"))),
    list(code = "Voraussichtliche Beschäftigungsentwicklung",
         selection = list(filter = "item", values = list("5"))),
    list(code = "Gewichtung", selection = list(filter = "item", values = list("1"))),
    list(code = "Quartal", selection = list(filter = "all", values = list("*")))
  )
  add(.try_fetch("ch_fso_besta_outlook",
                 fso_fetch("ch_fso_besta_outlook", "px-x-0602000000_105", besta_outlook_query,
                           quarter_col = "Quartal"),
                 "Labour"))

  # FSO Excel-asset datasets (not in PX-Web): the macro depth — CPI, producer/
  # import prices, wages, population, unemployment, GDP by expenditure. Each is a
  # DAM xlsx download parsed by a bespoke fso_excel_<id>() in source_fso_excel_sets.R.
  # su-d-05.02.66 = LIK on the Dec-2025=100 base (full history since 1982). It
  # superseded su-d-05.02.67 (Dec-2020=100), which FSO froze at the Dec-2025 rebasing.
  add(.try_fetch("ch_fso_cpi",        fso_excel_dataset("ch_fso_cpi")))
  add(.try_fetch("ch_fso_ppi",        fso_excel_dataset("ch_fso_ppi")))
  add(.try_fetch("ch_fso_wage_idx",   fso_excel_dataset("ch_fso_wage_idx")))
  add(.try_fetch("ch_fso_pop",        fso_excel_dataset("ch_fso_pop")))
  add(.try_fetch("ch_fso_unemp_rate", fso_excel_dataset("ch_fso_unemp_rate")))

  # FSO DAM CSV-master assets (already-long CSVs, no sheet reshaping):
  # labour productivity (index), employed persons (ETS), GFCF by sector/asset,
  # actual hours worked (AVOL).
  add(.try_fetch("ch_fso_labour_productivity", fso_labour_productivity(), "National accounts"))
  add(.try_fetch("ch_fso_ets",                 fso_ets(),                 "Labour"))
  add(.try_fetch("ch_fso_gfcf_detail",         fso_gfcf_detail(),         "National accounts"))
  add(.try_fetch("ch_fso_hours_worked",        fso_hours_worked(),        "Labour"))

  # FSO DAM Excel (bespoke sheet parsers): regional GDP (hierarchical CH → greater
  # region → canton tree), the construction price index, and foreign trade by
  # partner country (self-contained, pins the English-master asset ids).
  add(.try_fetch("ch_fso_gdp_region",
                 fso_excel_dataset("ch_fso_gdp_region"), "National accounts"))
  add(.try_fetch("ch_fso_construction_prices",
                 fso_excel_dataset("ch_fso_construction_prices"), "Prices"))
  add(.try_fetch("ch_fso_trade_partner", fso_excel_ch_fso_trade_partner(), "External sector"))

  # Eurostat (NOT FSO): Swiss HICP, the EU-harmonised CPI (2015=100), all-items +
  # 12 COICOP divisions. Concept-distinct from the national LIK (ch_fso_cpi).
  add(.try_fetch("ch_fso_hicp", eurostat_hicp_fetch("ch_fso_hicp"), "Prices"))

  # SECO Weekly Economic Activity index (WEA/WWA) — the catalog's first weekly series.
  add(.try_fetch("ch_seco_wwa", seco_wwa_fetch("ch_seco_wwa"), "Business cycle"))

  datasets
}

DATASHEET_DIR <- file.path(dirname(root), "datasets")

# Retry-pass wait. A source that timed out this run gets one more attempt before we
# write the catalog or open any skip issue -- enough to ride out a brief host
# outage (the failure that opened the ch_adecco_sjmi etl-skip issue was a transient
# uzh.ch connect timeout). Overridable via env for fast local runs / tests.
RETRY_SLEEP <- as.integer(Sys.getenv("ETL_RETRY_SLEEP", "180"))

# Cap on how many skips still trigger the in-process retry pass. That pass re-fetches
# on the SAME runner IP, so it can rescue a handful of independent transient blips but
# is futile -- and wastes ~RETRY_SLEEP + Nx15s of the run budget -- against a broad
# outage (e.g. the admin.ch runner-IP block skips ~12 sources at once; the same IP
# can't reach them on a retry). Above this count we skip the in-run retry and leave the
# skips for the targeted lunch/afternoon retries, which run as SEPARATE jobs => fresh
# egress IPs. Overridable via env.
RETRY_MAX_INPROCESS <- as.integer(Sys.getenv("ETL_RETRY_MAX_INPROCESS", "3"))

# Curate + persist ONE built dataset: merge its datasheet (concept/canonical/featured
# + display defaults), drop the levels/dims the app reproduces on the fly via its
# transform toggle, nest any declared hierarchy, then write <id>.{csv,parquet,json}.
# Returns the dataset with meta$fetched_utc stamped (write_catalog / merge_into_catalog
# read it). Shared by the full run (main) and the afternoon retry (retry_skipped) so
# both finalize identically.
finalize_dataset <- function(ds) {
  # Guard source-derived labels before anything curated is layered on top.
  ds$meta$dimensions <- drop_lang_echo(ds$meta$dimensions)
  sheet <- ds_read(ds$id, DATASHEET_DIR)   # one read; every consumer shares the lines
  ds$meta <- modifyList(ds$meta, read_datasheet_meta(ds$id, DATASHEET_DIR, lines = sheet))
  ds <- drop_redundant_levels(ds)
  ds <- drop_degenerate_dims(ds)
  ds <- attach_labels(ds, DATASHEET_DIR, lines = sheet)     # curated text first …
  ds <- attach_hierarchy(ds, DATASHEET_DIR, lines = sheet)  # … then structure
  if (!is.null(sheet)) ds$meta <- apply_vocab(ds$meta, sheet, DATA_DIR)
  ds <- write_dataset(ds, DATA_DIR)
  cat(sprintf("wrote %-22s %7d rows, %4d series  [%s]\n",
              ds$id, nrow(ds$data), n_series(ds$data),
              ds$meta$concept %||% "no datasheet"))
  ds
}

# Splice freshly-recovered datasets into the existing catalog.json without rebuilding
# the rest. The morning run drops a skipped id from the catalog entirely (build() only
# serializes successes), so a recovered id is normally re-ADDED here; the replace-by-id
# keeps it idempotent if an entry already exists. Used only by the retry pass, which
# rebuilds just the morning's failures and must not clobber the entries the morning
# already wrote.
merge_into_catalog <- function(recovered, out_dir) {
  path     <- file.path(out_dir, "catalog.json")
  existing <- if (file.exists(path)) jsonlite::fromJSON(path, simplifyVector = FALSE) else list()
  rec_ids  <- vapply(recovered, `[[`, character(1), "id")
  kept     <- Filter(function(e) !((e$id %||% "") %in% rec_ids), existing)
  merged   <- c(kept, lapply(recovered, catalog_entry))
  writeLines(
    jsonlite::toJSON(merged, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    path
  )
  cat(sprintf("merged %d recovered dataset(s) into catalog.json (%d total)\n",
              length(recovered), length(merged)))
}

main <- function() {
  .SKIPPED   <<- list()        # reset module accumulators at the entrypoint, so a
  .UNCHANGED <<- character(0)   # second main() call in one session starts clean
  datasets <- build()

  # Retry pass: give the skipped sources ONE more attempt after a short wait, by which
  # point the other fetches have bought the host minutes of recovery -- enough for a
  # genuine transient blip. We replay build() pinned to the skipped ids (each fetch
  # reconstructed fresh) and fold any successes back in. SKIPPED when many sources fail
  # at once (> RETRY_MAX_INPROCESS): that's a broad outage (e.g. an IP block), which a
  # same-IP retry can't fix -- those are left for the fresh-IP lunch/afternoon retries,
  # saving ~RETRY_SLEEP + Nx15s of run budget on a blocked day.
  if (length(.SKIPPED) && length(.SKIPPED) > RETRY_MAX_INPROCESS) {
    cat(sprintf("retry: %d skipped (> %d) -- broad outage, skipping same-IP in-run retry; leaving for fresh-IP retries\n",
                length(.SKIPPED), RETRY_MAX_INPROCESS))
  } else if (length(.SKIPPED)) {
    retry_ids <- vapply(.SKIPPED, `[[`, character(1), "id")
    cat(sprintf("retry: %d skipped (%s); waiting %ds then retrying\n",
                length(retry_ids), paste(retry_ids, collapse = ", "), RETRY_SLEEP))
    .SKIPPED <<- list()          # reset; the retry pass recomputes the survivors
    Sys.sleep(RETRY_SLEEP)
    recovered <- build(only = retry_ids)
    if (length(recovered)) {
      cat(sprintf("retry: %d recovered (%s)\n", length(recovered),
                  paste(vapply(recovered, `[[`, character(1), "id"), collapse = ", ")))
      datasets <- c(datasets, recovered)
    }
    if (length(.SKIPPED))
      cat(sprintf("retry: %d still failing after retry\n", length(.SKIPPED)))
  }

  # Index-loop write-back: finalize_dataset() returns the curated + persisted dataset,
  # which must land BACK in `datasets` so write_catalog() serializes the merged version
  # (else concept/canonical/featured come out null in catalog.json).
  n_fetched <- length(datasets)
  for (i in seq_along(datasets)) datasets[[i]] <- finalize_dataset(datasets[[i]])

  # Unchanged cubes: reload the already-curated files from disk (no re-fetch, no
  # re-write) so they still appear in the catalog. .UNCHANGED accumulated across the
  # build + retry passes; unique() guards against a cube appearing in both.
  unchanged_ids <- unique(.UNCHANGED)
  kept <- Filter(Negate(is.null), lapply(unchanged_ids, load_dataset, DATA_DIR))
  if (length(kept))
    cat(sprintf("kept %d unchanged dataset(s) from disk (skipped fetch+parse)\n", length(kept)))

  # Skipped sources keep their PREVIOUS catalog entry, served from the existing on-disk
  # files (shown stale, with the old `fetched` date). Without this, completing-with-skips
  # would DROP a failed dataset from catalog.json entirely -- making it vanish from the
  # API until a retry refetches it. A skip must keep the previous data (the documented
  # intent), not erase it. New sources that never succeeded have no disk copy -> correctly
  # absent. The id stays in run.json `skipped` so the retries + alarm still act on it.
  skipped_ids <- vapply(.SKIPPED, `[[`, character(1), "id")
  stale_kept  <- Filter(Negate(is.null), lapply(skipped_ids, load_dataset, DATA_DIR))
  if (length(stale_kept))
    cat(sprintf("retained %d skipped dataset(s) from disk (stale, pending retry)\n", length(stale_kept)))

  datasets <- c(datasets, kept, stale_kept)

  write_catalog(datasets, DATA_DIR)
  cat(sprintf("wrote catalog.json (%d datasets: %d fetched, %d unchanged, %d stale-kept) -> %s\n",
              length(datasets), n_fetched, length(kept), length(stale_kept), DATA_DIR))
  write_run_json(ok = n_fetched, skipped = .SKIPPED, unchanged = unchanged_ids,
                 out_dir = DATA_DIR)
}

# Write this run's fetch outcome to data/run.json (overwritten every run -- it is
# the authoritative snapshot of the latest scrape). `ok` = datasets freshly fetched and
# validated; `unchanged` = ids the source reported unchanged, served from disk without a
# re-download (conditional fetch); `skipped` = the per-source failures captured by
# .try_fetch (each a {id, error}); `attempted` = ok + unchanged + skipped. R/uptime.R
# reads `skipped` for the "run-through" metric and .github/scripts/skip_issues.sh opens an
# issue per skip; `unchanged` is informational (how much the freshness check saved).
write_run_json <- function(ok, skipped, unchanged = character(0), out_dir) {
  rec <- list(
    ts        = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    attempted = ok + length(unchanged) + length(skipped),
    ok        = ok,
    unchanged = as.list(unchanged),
    skipped   = skipped
  )
  writeLines(
    jsonlite::toJSON(rec, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    file.path(out_dir, "run.json")
  )
  cat(sprintf("wrote run.json (%d ok, %d unchanged, %d skipped) -> %s\n",
              ok, length(unchanged), length(skipped), out_dir))
}

# Append one row to data/retry.csv per afternoon retry that actually ran (i.e. the
# morning left skips). This is the "how often do we lean on the second run" ledger:
# rows accrue ONLY on days a retry was needed, so counting rows over a window against
# the one-row-per-day history in data/uptime.csv gives the usage rate. `recovered` =
# fixed by the afternoon (no issue); `still_failing` = a real format break that
# survived the retry and opened an etl-skip issue. Upsert per UTC day (a manual re-run
# replaces the day's row), matching uptime.csv's idempotence.
append_retry_log <- function(retried_ids, recovered_ids, still_failing_ids, out_dir) {
  path <- file.path(out_dir, "retry.csv")
  ID_COLS <- c("date", "ts", "retried_ids", "recovered_ids", "still_failing_ids")
  row <- data.frame(
    date              = format(Sys.time(), tz = "UTC", "%Y-%m-%d"),
    ts                = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"),
    n_retried         = length(retried_ids),
    retried_ids       = paste(retried_ids, collapse = ";"),
    n_recovered       = length(recovered_ids),
    recovered_ids     = paste(recovered_ids, collapse = ";"),
    n_still_failing   = length(still_failing_ids),
    still_failing_ids = paste(still_failing_ids, collapse = ";"),
    stringsAsFactors  = FALSE
  )
  hist <- if (file.exists(path)) {
    # Force id/date columns to character so an all-empty column isn't read as logical.
    utils::read.csv(path, colClasses = setNames(rep("character", length(ID_COLS)), ID_COLS))
  } else {
    row[0, , drop = FALSE]
  }
  hist <- hist[hist$date != row$date, , drop = FALSE]
  hist <- rbind(hist, row)
  utils::write.csv(hist, path, row.names = FALSE)
  cat(sprintf("retry.csv: %d retried, %d recovered, %d still failing\n",
              length(retried_ids), length(recovered_ids), length(still_failing_ids)))
}

# Afternoon targeted-retry entrypoint (ETL_MODE=retry). Re-fetches ONLY the sources the
# morning run skipped (read from data/run.json), folds any recoveries back into the data
# files + catalog, rewrites run.json to the post-retry skip state, and logs the retry to
# data/retry.csv. The skip alarm (.github/scripts/skip_issues.sh) then runs in the SAME
# afternoon workflow off the rewritten run.json -- so a transient morning outage that
# clears by afternoon never opens an issue, and only a genuine break survives to alarm.
# A no-skip morning is a no-op here (the workflow gate skips this run entirely).
retry_skipped <- function() {
  run_path <- file.path(DATA_DIR, "run.json")
  if (!file.exists(run_path)) {
    cat("retry: no data/run.json -- nothing to retry.\n"); return(invisible())
  }
  run       <- jsonlite::fromJSON(run_path, simplifyVector = FALSE)
  retry_ids <- vapply(run$skipped %||% list(), `[[`, character(1), "id")
  if (!length(retry_ids)) {
    cat("retry: morning run had no skips -- nothing to retry.\n"); return(invisible())
  }
  cat(sprintf("retry: re-fetching %d morning skip(s): %s\n",
              length(retry_ids), paste(retry_ids, collapse = ", ")))

  .SKIPPED   <<- list()                # reset; the retry build recomputes the survivors
  .UNCHANGED <<- character(0)           # a retried cube may now probe as unchanged
  recovered <- build(only = retry_ids)
  recovered_ids <- vapply(recovered, `[[`, character(1), "id")
  still_failing <- vapply(.SKIPPED, `[[`, character(1), "id")

  # A morning-skipped cube whose source is now reachable but reports unchanged: serve it
  # from disk (no longer a skip), exactly like the full run does.
  retry_unchanged <- unique(.UNCHANGED)
  kept <- Filter(Negate(is.null), lapply(retry_unchanged, load_dataset, DATA_DIR))
  kept_ids <- vapply(kept, `[[`, character(1), "id")

  for (i in seq_along(recovered)) recovered[[i]] <- finalize_dataset(recovered[[i]])
  merged <- c(recovered, kept)
  if (length(merged)) merge_into_catalog(merged, DATA_DIR)

  # Rewrite run.json to post-retry reality: the still-failing set drives the skip alarm,
  # ok rises by the recoveries so uptime.R's run-through metric goes green when the
  # afternoon clears everything, and the unchanged set carries the morning's forward plus
  # any cube the retry resolved as unchanged. attempted stays constant.
  new_ok          <- (run$ok %||% 0L) + length(recovered)
  morning_unchanged <- as.character(unlist(run$unchanged %||% list()))
  all_unchanged   <- union(morning_unchanged, kept_ids)
  write_run_json(ok = new_ok, skipped = .SKIPPED, unchanged = all_unchanged,
                 out_dir = DATA_DIR)

  # `recovered` for the retry ledger = both genuinely re-fetched and unchanged-on-disk:
  # either way the morning skip is resolved without opening an issue.
  append_retry_log(retry_ids, c(recovered_ids, kept_ids), still_failing, DATA_DIR)

  if (length(recovered))
    cat(sprintf("retry: recovered %s\n", paste(recovered_ids, collapse = ", ")))
  if (length(still_failing))
    cat(sprintf("retry: still failing %s\n", paste(still_failing, collapse = ", ")))
}

# Mode dispatch: the afternoon workflow sets ETL_MODE=retry to re-fetch just the
# morning's skips; the default daily run does the full scrape.
if (identical(Sys.getenv("ETL_MODE"), "retry")) retry_skipped() else main()
