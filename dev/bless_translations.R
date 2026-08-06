# Record which English text each set of description translations was made from.
#
# The `## What is special` prose ships to users in four languages. Editing the
# English silently invalidates the other three: nothing in the text says "this
# translation predates the sentence it translates", and a stale German snippet
# is worse than none because it reads as current.
#
# So the translations are BLESSED against a checksum of the English they were
# written from, kept in datasets/translation-sync.json. tests/test_description_i18n.R
# fails when the English has moved on, naming the datasets to revisit.
#
# Workflow: edit the English -> the test fails -> update de/fr/it -> run this to
# re-bless. Running it is the act of saying "the translations now match".
#
#   Rscript dev/bless_translations.R            # re-bless every dataset
#   Rscript dev/bless_translations.R ch_fso_cpi # ...or just these
#
# The file stores a checksum, not the text: the datasheet stays the single
# source of truth for the words, and this is only a review ledger. `git diff`
# on the datasheet shows what actually changed.

source("R/datasheet.R")

SYNC_PATH <- "datasets/translation-sync.json"

# Checksum of the prose as the parser sees it (whitespace-flattened, markers
# stripped), so reflowing a paragraph does NOT count as a change — only the
# words do.
en_digest <- function(lines) {
  en <- ds_prose(lines, "What is special")
  if (is.null(en)) return(NULL)
  digest::digest(en, algo = "md5", serialize = FALSE)
}

# Which languages actually carry a translation right now.
langs_present <- function(lines) {
  have <- DS_I18N_LANGS[vapply(DS_I18N_LANGS, function(L)
    !is.null(ds_prose(lines, sprintf("What is special (%s)", L))), logical(1))]
  unname(have)
}

args <- commandArgs(trailingOnly = TRUE)
all_ids <- sub("\\.md$", "", list.files("datasets", pattern = "^ch_.*\\.md$"))
ids <- if (length(args)) args else all_ids
if (length(setdiff(ids, all_ids)))
  stop("unknown dataset(s): ", paste(setdiff(ids, all_ids), collapse = ", "), call. = FALSE)

prev <- if (file.exists(SYNC_PATH))
  jsonlite::fromJSON(SYNC_PATH, simplifyVector = FALSE) else list()

changed <- character(0)
for (id in ids) {
  lines <- ds_read(id, "datasets")
  d <- en_digest(lines)
  if (is.null(d)) next                      # no English prose -> nothing to bless
  langs <- langs_present(lines)
  if (!length(langs)) { prev[[id]] <- NULL; next }   # untranslated -> not tracked
  entry <- list(en = d, langs = as.list(langs))
  if (!identical(prev[[id]], entry)) changed <- c(changed, id)
  prev[[id]] <- entry
}

prev <- prev[order(names(prev))]
writeLines(jsonlite::toJSON(prev, auto_unbox = TRUE, pretty = TRUE), SYNC_PATH)

cat(sprintf("blessed %d dataset(s); %d entry change(s)%s\n",
            length(ids), length(changed),
            if (length(changed)) paste0(": ", paste(changed, collapse = ", ")) else ""))
