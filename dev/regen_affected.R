# One-off: regenerate only the datasets touched by the redundant-transform /
# degenerate-dimension cleanup, exercising the real pipeline defs. Not part of the
# scheduled run (main() regenerates everything); kept in dev/ for reproducibility.
txt <- paste(readLines("R/pipeline.R"), collapse = "\n")
blk <- paste(
  "root <- tryCatch(",
  "  dirname(normalizePath(sub(\"--file=\", \"\", grep(\"--file=\", commandArgs(FALSE), value = TRUE)))),",
  "  error = function(e) \"R\"",
  ")", sep = "\n")
stopifnot(grepl(blk, txt, fixed = TRUE))
txt <- sub(blk, "root <- \"R\"", txt, fixed = TRUE)
txt <- sub("\nmain()", "\n", txt, fixed = TRUE)
eval(parse(text = txt), envir = globalenv())
stopifnot(exists("drop_redundant_levels"), exists("drop_degenerate_dims"))

cubes <- read_snb_cubes()
title_of <- function(id) { for (c in cubes) if (c$cube_id == id) return(c$title); id }

hesta_query <- list(
  list(code = "Jahr", selection = list(filter = "all", values = list("*"))),
  list(code = "Monat", selection = list(filter = "item", values = as.list(as.character(1:12)))),
  list(code = "Tourismusregion", selection = list(filter = "all", values = list("*"))),
  list(code = "Indikator", selection = list(filter = "item", values = list("2")))
)
besta_query <- list(
  list(code = "Wirtschaftsabteilung", selection = list(filter = "all", values = list("*"))),
  list(code = "Beschäftigungsgrad", selection = list(filter = "item", values = list("TOT"))),
  list(code = "Geschlecht", selection = list(filter = "item", values = list("TOT"))),
  list(code = "Quartal", selection = list(filter = "all", values = list("*")))
)

jobs <- list(
  function() fso_excel_dataset("ch_fso_wage_idx", "je-e-03.04.03.00.04"),
  function() fso_excel_dataset("ch_fso_pop", "su-d-01.02.04.05"),
  function() fso_sdmx_fetch("ch_fso_retail", "CH1.KEU", "DF_KEU_M1", "1.0.0",
               title = list(en = "Retail trade turnover (monthly)"), noga_keep = .SDMX_RETAIL_NOGA),
  function() fso_sdmx_fetch("ch_fso_production", "CH1.KEU", "DF_KEU_Q1", "1.0.0",
               title = list(en = "Industry & construction turnover (quarterly)"), noga_keep = .SDMX_PRODUCTION_NOGA),
  function() fso_fetch("ch_fso_hesta", "px-x-1003020000_103", hesta_query,
               title = list(en = "Hotel sector: overnight stays by tourism region")),
  function() fso_fetch("ch_fso_besta", "px-x-0602000000_101", besta_query,
               title = list(en = "Jobs by economic division (quarterly)"),
               quarter_col = "Quartal", chunk_by = "Quartal", chunk_size = 40L),
  function() snb_fetch("devwkibiim", title = list(en = title_of("devwkibiim"))),
  function() snb_fetch("devwkieffid", title = list(en = title_of("devwkieffid"))),
  function() snb_fetch("snbmonagg", title = list(en = title_of("snbmonagg"))),
  function() snb_fetch("plkopr", title = list(en = title_of("plkopr")))
)

for (thunk in jobs) {
  ds <- thunk()
  ds$meta <- modifyList(ds$meta, read_datasheet_meta(ds$id, DATASHEET_DIR))
  ds <- drop_redundant_levels(ds)
  ds <- drop_degenerate_dims(ds)
  ds <- write_dataset(ds, DATA_DIR)
  cat(sprintf("%-20s rows=%6d series=%4d dims=[%s]\n", ds$id, nrow(ds$data),
              n_series(ds$data), paste(dim_cols(ds$data), collapse = ",")))
}
