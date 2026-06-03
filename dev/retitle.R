#!/usr/bin/env Rscript
# retitle.R — curate display titles. Writes a `- **title**:` override into each
# datasheet for the series whose raw source title is too long/awkward for the UI.
# Datasheets are the source of truth; run dev/rebuild_from_datasheets.R afterwards
# (this script calls it) to propagate to sidecars + catalog. Idempotent.
# Run from repo root: Rscript dev/retitle.R

root <- normalizePath(file.path(dirname(sub("--file=", "",
  grep("--file=", commandArgs(FALSE), value = TRUE)[1])), ".."))
DATASHEET_DIR <- file.path(root, "datasets")

titles <- list(
  # Labour
  ch_snb_amarbma             = "Registered unemployment",
  ch_fso_unemp_rate          = "Unemployment rate (ILO)",
  ch_fso_besta               = "Jobs by economic division",
  ch_fso_besta_outlook       = "Employment outlook",
  ch_fso_ets                 = "Employed persons (ETS)",
  ch_fso_cross_border_commuters = "Cross-border commuters",
  ch_fso_hours_worked        = "Hours worked",
  ch_fso_labour_productivity = "Labour productivity",
  ch_fso_vacancies           = "Job vacancies",
  # Prices
  ch_snb_plkopr              = "Consumer prices (CPI)",
  ch_snb_plkoprinfla         = "Core inflation",
  ch_fso_cpi                 = "Consumer prices (detailed basket)",
  ch_fso_hicp                = "Harmonised CPI (HICP)",
  ch_fso_ppi                 = "Producer & import prices",
  ch_snb_plimoinchq          = "Real estate prices",
  ch_fso_construction_prices = "Construction prices",
  ch_snb_snbiprogq           = "Inflation forecast (SNB)",
  # National accounts
  ch_fso_gdp_region          = "Regional GDP",
  ch_fso_gfcf_detail         = "Investment (GFCF) detail",
  ch_ffa_finances            = "Government finances",
  # Interest rates & yields
  ch_snb_rendeiduebd         = "Bond yields (spot rates)",
  ch_snb_zikredlauf          = "New lending rates",
  ch_snb_zikrepro            = "Published interest rates",
  # Exchange rates
  ch_snb_devkum              = "Bilateral exchange rates",
  ch_snb_devwkibiim          = "Bilateral exchange-rate indices",
  ch_snb_devwkieffid         = "Effective exchange-rate index",
  # Financial markets
  ch_snb_capweums            = "Securities turnover",
  # External sector
  ch_snb_auvekomq            = "International investment position",
  ch_snb_auvercurrq          = "Investment position by currency",
  ch_snb_auversecq           = "Investment position by sector",
  ch_snb_auverdeptq          = "External debt",
  ch_snb_bopcurrq            = "Balance of payments: current account",
  ch_snb_bopcapbalq          = "Balance of payments: financial account",
  ch_snb_bopoverq            = "Balance of payments: overview",
  ch_snb_bopservq            = "Balance of payments: services",
  # Money & banking
  ch_snb_snbmonagg           = "Monetary aggregates (M1–M3)",
  ch_snb_snbbipo             = "SNB balance sheet",
  ch_snb_babilpobm           = "Bank balance sheets by currency",
  ch_snb_bakredbetgrbm       = "Corporate loans by company size",
  ch_snb_bakredinausbm       = "Mortgage & other loans",
  ch_snb_bakredsekbm         = "Domestic loans by sector",
  # Domestic economy
  ch_fso_production          = "Industry & construction turnover",
  ch_fso_retail              = "Retail trade turnover",
  ch_fso_services            = "Services turnover",
  ch_fso_hesta               = "Hotel overnight stays",
  ch_fso_new_vehicles        = "New car registrations by fuel",
  # Population
  ch_fso_pop                 = "Resident population",
  ch_fso_pop_detail          = "Resident population by nationality",
  # Business cycle & sentiment
  ch_seco_concon             = "Consumer confidence",
  ch_seco_wwa                = "Weekly economic activity (WEA)",
  # Payment systems
  ch_snb_zavesic             = "Interbank clearing (SIC)",
  ch_snb_zavkuzaart          = "Customer payments (outgoing)",
  ch_snb_zavegelade          = "E-money"
)

set_title <- function(lines, value) {
  new <- sprintf("- **title**: %s", value)
  hit <- grep("^- \\*\\*title\\*\\*:", lines)
  if (length(hit)) { lines[hit[1]] <- new; return(lines) }
  id_at <- grep("^- \\*\\*id\\*\\*:", lines)[1]   # insert right after the id line
  append(lines, new, after = id_at)
}

n <- 0
for (id in names(titles)) {
  f <- file.path(DATASHEET_DIR, paste0(id, ".md"))
  if (!file.exists(f)) { warning("no datasheet: ", id); next }
  writeLines(set_title(readLines(f, warn = FALSE), titles[[id]]), f)
  n <- n + 1
}
cat(sprintf("set %d titles\n", n))

system2("Rscript", file.path(root, "dev", "rebuild_from_datasheets.R"))
