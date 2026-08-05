# Datasheet SYNTAX layer — the one module that knows how a datasheet is written.
#
# A datasheet (datasets/<id>.md) is the source of truth for a dataset's curation:
# identity fields at the top, `## Display` presentation fields, the `## Hierarchy`
# block, prose sections. Historically each consumer grew its own reader (whole-file
# `pick()` in io.R, a bespoke block parser in hierarchy.R, `sect()` for prose); this
# module unifies the SYNTAX so consumers keep only their SEMANTICS:
#
#   ds_read(id, dir)          read the file once; hand `lines` to every consumer
#   ds_top(lines)             the identity block (before the first "## " heading)
#   ds_section(lines, name)   one section's body (heading to next heading)
#   ds_fields(lines)          "- **key**: value" pairs, SCOPED to the lines given
#   ds_bullets(lines)         directive/bullet-tree reader (Hierarchy, Labels)
#   ds_i18n(value)            the "<en> | de: … | fr: …" language grammar
#
# Scoping is the behavioural point: a key is looked up in its own section, never
# across the whole file, so two sections can use the same key without colliding.
# (Verified against all 70 datasheets: identity keys live only in the top block and
# display keys only under ## Display, so scoped lookup reproduces the historical
# whole-file behaviour exactly.)
#
# Spec: dataseries.org spec/multilingual/2-design.md §1–2.

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a)) b else a

# Read a datasheet's lines, or NULL if the dataset has no datasheet.
ds_read <- function(id, datasheet_dir) {
  f <- file.path(datasheet_dir, paste0(id, ".md"))
  if (!file.exists(f)) return(NULL)
  readLines(f, warn = FALSE)
}

# The identity block: everything before the first "## " heading.
ds_top <- function(lines) {
  h <- grep("^##\\s", lines)
  if (!length(h)) lines else if (h[1] == 1L) character(0) else lines[seq_len(h[1] - 1L)]
}

# One section's body: the lines under "## <name>" up to (excluding) the next "## "
# heading, or NULL when the section is absent. `name` is matched literally.
ds_section <- function(lines, name) {
  h <- grep(sprintf("^##\\s+%s\\s*$", name), lines)
  if (!length(h)) return(NULL)
  nxt <- grep("^##\\s", lines)
  nxt <- nxt[nxt > h[1]]
  end <- if (length(nxt)) nxt[1] - 1L else length(lines)
  if (h[1] + 1L > end) character(0) else lines[(h[1] + 1L):end]
}

# "- **key**: value" pairs within the lines given (typically ds_top() or one
# ds_section()). Returns a named list of RAW single-line values, first occurrence
# winning — semantics (splitting, i18n, defaults) stay with the consumer.
ds_fields <- function(lines) {
  out <- list()
  for (ln in lines %||% character(0)) {
    m <- regmatches(ln, regexec("^- \\*\\*(.+?)\\*\\*:\\s*(.*?)\\s*$", ln))[[1]]
    if (length(m) == 3 && is.null(out[[m[2]]])) out[[m[2]]] <- m[3]
  }
  out
}

# Prose: a section flattened to one normalized paragraph (the historical sect()).
ds_prose <- function(lines, name) {
  body <- ds_section(lines, name)
  if (is.null(body)) return(NULL)
  body <- paste(body, collapse = " ")
  body <- gsub("[`*]", "", body)        # drop md bold/code markers
  body <- trimws(gsub("\\s+", " ", body))
  if (nzchar(body)) body else NULL
}

# ---- the language grammar ---------------------------------------------------
# "<en text> [ | <lang>: <text> ]..."   lang ∈ de, fr, it
#
# The FIRST segment is English (unmarked); each further segment must open with a
# known language tag. An unknown tag is an ERROR, not a silent skip — a typoed
# "ff: …" must not vanish into the English text. " | " (space-pipe-space) is the
# reserved separator; verified absent from every existing label (health check
# keeps it that way). A value with no separator parses to list(en = value), which
# is why every pre-i18n datasheet parses unchanged under this grammar.
DS_I18N_LANGS <- c("de", "fr", "it")

ds_i18n <- function(value) {
  if (is.null(value) || !nzchar(value)) return(NULL)
  parts <- strsplit(value, " | ", fixed = TRUE)[[1]]
  out <- list(en = trimws(parts[1]))
  for (p in parts[-1]) {
    m <- regmatches(p, regexec("^([a-z]{2}):\\s*(.+?)\\s*$", trimws(p)))[[1]]
    if (length(m) != 3 || !(m[2] %in% DS_I18N_LANGS))
      stop(sprintf("ds_i18n: malformed language segment '%s' in '%s' (want '<%s>: text')",
                   p, value, paste(DS_I18N_LANGS, collapse = "|")), call. = FALSE)
    out[[m[2]]] <- m[3]
  }
  out
}

# ---- directive/bullet-tree reader --------------------------------------------
# The shared shape of the ## Hierarchy and ## Labels blocks: a section is a list
# of DIRECTIVES, each scoped to one dimension. A "dim: <name>" line opens a new
# directive (anything before the first one is scoped to the split dim, dim = NULL);
# within a directive there is either a single "derive: <method>" line or indented
# "- <text>" bullets (2 spaces per depth level). Bullet text is returned RAW —
# "@code: Label" vs "code: value" vs bare "code" is consumer semantics.
#
# Returns list of list(dim=, derive=, items = list(list(depth=, text=))), or NULL
# when the lines are NULL / hold no directive content (a prose-only block).
ds_bullets <- function(lines) {
  if (is.null(lines)) return(NULL)
  specs <- list()
  cur <- list(dim = NULL, derive = NULL, items = list())
  flush <- function() {
    if (!is.null(cur$derive) || length(cur$items)) specs[[length(specs) + 1L]] <<- cur
  }
  for (ln in lines) {
    if (!nzchar(trimws(ln))) next
    m_dim <- regmatches(ln, regexec("^\\s*-?\\s*\\**dim\\**:\\s*(\\S+)", ln))[[1]]
    if (length(m_dim) == 2) {
      flush()
      cur <- list(dim = m_dim[2], derive = NULL, items = list())
      next
    }
    m_der <- regmatches(ln, regexec("^\\s*-?\\s*derive:\\s*(.+?)\\s*$", ln))[[1]]
    if (length(m_der) == 2) { cur$derive <- m_der[2]; next }
    m <- regmatches(ln, regexec("^( *)- (.+)$", ln))[[1]]   # tree bullet: indent sets depth
    if (length(m) != 3) next                                # prose line inside the block
    cur$items[[length(cur$items) + 1L]] <-
      list(depth = nchar(m[2]) %/% 2L, text = trimws(m[3]))
  }
  flush()
  if (!length(specs)) return(NULL)
  specs
}

# Fold an ordered list of {depth, code} into a nested named list (a node's children
# are the deeper bullets that follow it before depth returns to its level). Shared
# by the Hierarchy tree and any future tree-shaped block.
ds_tree <- function(items) {
  i <- 1L; n <- length(items)
  parse_level <- function(depth) {
    out <- list()
    while (i <= n && items[[i]]$depth == depth) {
      code <- items[[i]]$code
      i <<- i + 1L
      kids <- if (i <= n && items[[i]]$depth == depth + 1L) parse_level(depth + 1L) else list()
      out[[code]] <- kids
    }
    out
  }
  parse_level(0L)
}
