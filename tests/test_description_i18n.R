# Translated descriptions must preserve the FACTS of the English original.
#
# The `## What is special` prose is the one datasheet section published to users
# (page lede, <meta description>, JSON-LD). Its translations are drafted, so the
# failure mode that matters is not awkward phrasing — a human skim catches that —
# but a silently altered FIGURE or a dropped cross-reference: "595 positions"
# becoming "596", or a `ch_snb_plkopr` pointer vanishing. Those are mechanically
# checkable, so they are checked.
#
# Run from repo root:  Rscript tests/test_description_i18n.R

source("R/datasheet.R")

ids <- sub("\\.md$", "", list.files("datasets", pattern = "^ch_.*\\.md$"))
problems <- character(0)
n_tr <- 0L

# Numeric tokens: years, counts, base periods. Ignore pure formatting noise.
nums_of <- function(s) {
  m <- regmatches(s, gregexpr("[0-9]+(?:[.,][0-9]+)?", s))[[1]]
  sort(unique(gsub(",", ".", m)))
}
# Dataset cross-references (`ch_xxx_yyy`) must survive verbatim.
refs_of <- function(s) sort(unique(regmatches(s, gregexpr("ch_[a-z0-9_]+", s))[[1]]))

for (id in ids) {
  lines <- ds_read(id, "datasets")
  en <- ds_prose(lines, "What is special")
  if (is.null(en)) next
  for (L in DS_I18N_LANGS) {
    tr <- ds_prose(lines, sprintf("What is special (%s)", L))
    if (is.null(tr)) next
    n_tr <- n_tr + 1L
    miss_ref <- setdiff(refs_of(en), refs_of(tr))
    if (length(miss_ref))
      problems <- c(problems, sprintf("%s [%s]: dropped dataset ref(s): %s",
                                      id, L, paste(miss_ref, collapse = ", ")))
    miss_num <- setdiff(nums_of(en), nums_of(tr))
    extra_num <- setdiff(nums_of(tr), nums_of(en))
    if (length(miss_num) || length(extra_num))
      problems <- c(problems, sprintf("%s [%s]: figures differ (missing: %s | invented: %s)",
                                      id, L,
                                      paste(miss_num, collapse = ","),
                                      paste(extra_num, collapse = ",")))
    # A "translation" that is byte-identical to English is an untranslated stub.
    if (identical(tr, en))
      problems <- c(problems, sprintf("%s [%s]: identical to the English text", id, L))
  }
}

# Language purity: a word exclusive to another language means the translation
# drifted (a stray Italian clause in the French, say). The figure/reference guard
# above cannot see this, and a reviewer skimming 210 strings will not either.
FORBIDDEN <- list(
  de = "\\b(che|gli|degli|delle|pi\u00f9|sono|avec|aux|dans|selon|leur|ainsi|chaque|sont)\\b",
  fr = "\\b(che|gli|degli|delle|pi\u00f9|sono|nella|und|f\u00fcr|nach|sowie|werden|nicht|sind|wird)\\b",
  it = "\\b(avec|aux|dans|selon|leur|ainsi|chaque|sont|und|f\u00fcr|nach|sowie|werden|nicht|sind|wird)\\b"
)
for (id in ids) {
  lines <- ds_read(id, "datasets")
  for (L in names(FORBIDDEN)) {
    tr <- ds_prose(lines, sprintf("What is special (%s)", L))
    if (is.null(tr)) next
    m <- regmatches(tr, gregexpr(FORBIDDEN[[L]], tr, perl = TRUE, ignore.case = TRUE))[[1]]
    if (length(m))
      problems <- c(problems, sprintf("%s [%s]: foreign-language word(s): %s", id, L,
                                      paste(unique(m), collapse = ", ")))
  }
}

# Staleness: the translations were written from a specific English sentence. Edit
# the English and the other three silently stop matching it — and a stale German
# snippet is worse than no German snippet, because it reads as current. The
# checksum in datasets/translation-sync.json is what each translation was blessed
# against; a mismatch means the English moved on.
#
# This is the one drift the checks above cannot see: rewording the English
# without touching a figure or a ch_ reference passes every one of them.
SYNC_PATH <- "datasets/translation-sync.json"
sync <- if (file.exists(SYNC_PATH))
  jsonlite::fromJSON(SYNC_PATH, simplifyVector = FALSE) else list()
stale <- character(0)
untracked <- character(0)
for (id in ids) {
  lines <- ds_read(id, "datasets")
  en <- ds_prose(lines, "What is special")
  if (is.null(en)) next
  have <- DS_I18N_LANGS[vapply(DS_I18N_LANGS, function(L)
    !is.null(ds_prose(lines, sprintf("What is special (%s)", L))), logical(1))]
  if (!length(have)) next                    # untranslated on purpose — not tracked
  rec <- sync[[id]]
  if (is.null(rec)) { untracked <- c(untracked, id); next }
  if (!identical(rec$en, digest::digest(en, algo = "md5", serialize = FALSE)))
    stale <- c(stale, id)
}
if (length(stale))
  problems <- c(problems, sprintf(
    "%s: the English changed since its translations were blessed", stale))
if (length(untracked))
  problems <- c(problems, sprintf(
    "%s: translated but absent from %s", untracked, SYNC_PATH))
if (length(stale) || length(untracked))
  problems <- c(problems,
    "  -> update the de/fr/it prose to match, then: Rscript dev/bless_translations.R")

if (length(problems)) {
  cat(paste0("  ", problems, collapse = "\n"), "\n")
  stop(sprintf("test_description_i18n: %d problem(s) across %d translations",
               length(problems), n_tr), call. = FALSE)
}
cat(sprintf(paste0("test_description_i18n: %d translations preserve every figure and ",
                   "cross-reference; %d in sync with their English\n"),
            n_tr, length(sync)))
