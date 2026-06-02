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
            "source_fso_dam_csv.R", "source_fso_sdmx.R", "source_eurostat.R",
            "source_seco.R", "source_ffa.R", "source_adecco.R")) {
  source(file.path(root, f))
}

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
# The per-dataset parsers live in source_fso_excel_sets.R.
fso_excel_dataset <- function(id, order_nr, topic = NULL) {
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

# Run one fetch, tag it with a topic, and keep going on failure (a transient
# network error on one source must not lose the whole run).
.try_fetch <- function(label, expr, topic = NULL) {
  # force() the fetch AND validate it inside the same guard: a structural failure
  # (or a parser's own fail-closed value-anchor stop()) skips this one dataset and
  # is logged, rather than silently shipping a bad parse or halting the whole run.
  ds <- tryCatch({ d <- force(expr); validate_dataset(d); d }, error = function(e) {
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

  # SECO: consumer sentiment survey, swissdata at source (back to 1972-Q4). This
  # is the TRUE producer — it replaces the retired SNB re-export ch_snb_concon —
  # and adds the seasonally-adjusted track SECO publishes alongside the raw balances.
  ks_base <- paste0("https://www.seco.admin.ch/dam/seco/en/dokumente/",
                    "Wirtschaft/Wirtschaftslage/Konsumentenstimmung/")
  add(.try_fetch("ch_seco_concon",
                 seco_fetch("ch_seco_concon",
                            data_url = paste0(ks_base, "ks_q.csv.download.csv/ks_q.csv"),
                            meta_url = paste0(ks_base, "ks_q_json.txt.download.txt/ks_q_json.txt")),
                 "Business surveys"))

  # FSO SDMX (CH1.KEU): turnover flows migrated off the dead PX-Web onto
  # disseminate.stats.swiss. Retail = monthly DF_KEU_M1 (NOGA division 47);
  # industry + construction = quarterly DF_KEU_Q1 (NOGA B-E + F, divisions 41-43).
  add(.try_fetch("ch_fso_retail",
                 fso_sdmx_fetch("ch_fso_retail", "CH1.KEU", "DF_KEU_M1", "1.0.0",
                                title = list(en = "Retail trade turnover (monthly)"),
                                noga_keep = .SDMX_RETAIL_NOGA),
                 "Domestic economy"))
  add(.try_fetch("ch_fso_production",
                 fso_sdmx_fetch("ch_fso_production", "CH1.KEU", "DF_KEU_Q1", "1.0.0",
                                title = list(en = "Industry & construction turnover (quarterly)"),
                                noga_keep = .SDMX_PRODUCTION_NOGA),
                 "Domestic economy"))
  add(.try_fetch("ch_fso_services",
                 fso_sdmx_fetch("ch_fso_services", "CH1.KEU", "DF_KEU_Q1", "1.0.0",
                                title = list(en = "Services-sector turnover (quarterly)"),
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
                 ffa_fetch("ch_ffa_finances",
                           title = list(en = "Public finances: general government main aggregates")),
                 "Public finances"))

  # KOF: the Economic Barometer (single monthly series).
  add(.try_fetch("ch_kof_barometer",
                 kof_fetch("ch.kof.barometer", title = list(en = "KOF Economic Barometer")),
                 "Business cycle"))
  # KOF Economic Sentiment Index (ESI), monthly, via the open OGD /sets endpoint
  # (two methodology versions: pre-Brexit + standard 2018).
  add(.try_fetch("ch_kof_esi",
                 kof_set_fetch("ogd_ch.kof.esi",
                               title = list(en = "KOF Economic Sentiment Index"),
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
                           title = list(en = "Employment outlook index by economic division"),
                           quarter_col = "Quartal"),
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

  # FSO DAM CSV-master assets (already-long CSVs, no sheet reshaping):
  # labour productivity (index). The parsers fso_ets() / fso_gfcf_detail() /
  # fso_hours_worked() are implemented and verified but HELD from the catalog
  # pending a display rework (multi-dimension selector / ragged-tree polish) —
  # re-enable here once the Display is sorted.
  add(.try_fetch("ch_fso_labour_productivity", fso_labour_productivity(), "National accounts"))
  # add(.try_fetch("ch_fso_ets",                 fso_ets(),                 "Labour"))            # HELD: split=sector/sex selector
  # add(.try_fetch("ch_fso_gfcf_detail",         fso_gfcf_detail(),         "National accounts")) # HELD: ragged sector×asset tree
  # add(.try_fetch("ch_fso_hours_worked",        fso_hours_worked(),        "Labour"))            # HELD: 3-dim display unreviewed

  # FSO DAM Excel (bespoke sheet parsers): the construction price index + foreign
  # trade by partner country (self-contained, pins the English-master asset ids).
  # fso_excel_ch_fso_gdp_region() is implemented + verified but HELD pending a
  # hierarchical region tree (CH → greater region → canton) instead of region×level.
  # add(.try_fetch("ch_fso_gdp_region",
  #                fso_excel_dataset("ch_fso_gdp_region", "je-e-04.02.06.01"), "National accounts")) # HELD
  add(.try_fetch("ch_fso_construction_prices",
                 fso_excel_dataset("ch_fso_construction_prices", "cc-t-05.05.01"), "Prices"))
  add(.try_fetch("ch_fso_trade_partner", fso_excel_ch_fso_trade_partner(), "External sector"))

  # Eurostat (NOT FSO): Swiss HICP, the EU-harmonised CPI (2015=100), all-items +
  # 12 COICOP divisions. Concept-distinct from the national LIK (ch_fso_cpi).
  add(.try_fetch("ch_fso_hicp", eurostat_hicp_fetch("ch_fso_hicp"), "Prices"))

  # SECO Weekly Economic Activity index (WEA/WWA) — the catalog's first weekly series.
  add(.try_fetch("ch_seco_wwa", seco_wwa_fetch("ch_seco_wwa"), "Business cycle"))

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
    # Drop levels the app reproduces via its transform toggle (see REDUNDANT_LEVELS),
    # then drop any dimension thereby (or already) pinned to a single value.
    datasets[[i]] <- drop_redundant_levels(datasets[[i]])
    datasets[[i]] <- drop_degenerate_dims(datasets[[i]])
    # Capture the return: write_dataset() stamps meta$fetched_utc, which
    # write_catalog() below reads into the catalog "fetched" field.
    datasets[[i]] <- write_dataset(datasets[[i]], DATA_DIR)
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
