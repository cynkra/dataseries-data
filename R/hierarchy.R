# Breakdown hierarchies: turn a flat split/line dimension into a nested tree so the
# website's picker renders parent → child instead of one long sibling list.
#
# A dimension's meta carries `hierarchy`: a nested named list `{code: {child: {}}}`
# (leaf = empty list), exactly the shape the source-derived cubes (e.g. ch_seco_gdp,
# the SNB cubes) already ship. Interior nodes may themselves be data-bearing (a NOGA
# total or the 6.3 sentiment index have their own series) — the front-end renders a
# node with both `data` and children as a selectable row with an expand caret.
#
# Three ways a hierarchy is declared, in order of preference:
#   1. From the source (the parser builds it — e.g. the FSO CPI `Level` column). Those
#      arrive already attached and this module leaves them untouched.
#   2. Algorithmic from the codes themselves, where the codes encode the tree
#      (`derive: noga-range` for the FSO NOGA range codes 5-96 ⊃ 5-43 ⊃ 10-33 …).
#   3. Hand-declared in the datasheet `## Hierarchy` block (small curated trees).
#
# Cases 2 and 3 are driven by the datasheet `## Hierarchy` block; see
# read_hierarchy_block() for the grammar. attach_hierarchy() is the entry point the
# pipeline (and the offline regen) call after the datasheet merge.

if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a)) b else a

# ---- datasheet `## Hierarchy` block -----------------------------------------
# Grammar (under a `## Hierarchy` heading, until the next `## ` heading):
#   - an optional `dim: <name>` line targets a non-split dimension (default: split)
#   - either a single `derive: <method>` line (algorithmic), or
#   - an indented bullet tree, 2 spaces per level:
#       - <code>                 a real level code (label comes from the data)
#       - @<code>: <Label>       a synthetic grouping header (data = false)
# Returns NULL (no block) or a list with $dim plus either $derive or
# $tree (nested named list of codes) + $groups (named char: synthetic code -> label).
read_hierarchy_block <- function(lines) {
  h <- grep("^##\\s+Hierarchy\\s*$", lines)
  if (!length(h)) return(NULL)
  start <- h[1] + 1L
  nxt <- grep("^##\\s", lines)
  nxt <- nxt[nxt > h[1]]
  end <- if (length(nxt)) nxt[1] - 1L else length(lines)
  body <- lines[start:end]

  dim <- NULL; derive <- NULL
  groups <- character(0)
  # stack[[depth+1]] holds the code whose children we are currently filling.
  bullets <- list()  # collected (depth, code) in document order
  for (ln in body) {
    if (!nzchar(trimws(ln))) next
    d <- sub("^- \\*\\*dim\\*\\*:\\s*", "", ln)              # tolerate bold or plain
    m_dim <- regmatches(ln, regexec("^\\s*-?\\s*dim:\\s*(\\S+)", ln))[[1]]
    if (length(m_dim) == 2) { dim <- m_dim[2]; next }
    m_der <- regmatches(ln, regexec("^\\s*-?\\s*derive:\\s*(.+?)\\s*$", ln))[[1]]
    if (length(m_der) == 2) { derive <- m_der[2]; next }
    # a tree bullet: leading spaces set depth, then "- "
    m <- regmatches(ln, regexec("^( *)- (.+)$", ln))[[1]]
    if (length(m) != 3) next
    depth <- nchar(m[2]) %/% 2L
    txt <- trimws(m[3])
    if (startsWith(txt, "@")) {
      kv <- regmatches(txt, regexec("^@(\\S+?):\\s*(.+)$", txt))[[1]]
      if (length(kv) != 3)
        stop(sprintf("hierarchy: malformed group line '%s' (want '@code: Label')", txt), call. = FALSE)
      code <- kv[2]; groups[[code]] <- kv[3]
    } else {
      code <- txt
    }
    bullets[[length(bullets) + 1L]] <- list(depth = depth, code = code)
  }

  if (!is.null(derive)) return(list(dim = dim, derive = derive))
  if (!length(bullets)) return(if (is.null(dim)) NULL else list(dim = dim))

  # Build the nested tree from the (depth, code) stream. We assemble bottom-up by
  # tracking, per depth, the code currently open and accumulating its children.
  tree <- build_tree_from_bullets(bullets)
  list(dim = dim, tree = tree, groups = groups)
}

# Fold an ordered list of {depth, code} into a nested named list. A node's children
# are the deeper-depth bullets that follow it before the depth returns to its level.
build_tree_from_bullets <- function(bullets) {
  # Recursive descent over the flat stream using an index cursor.
  i <- 1L; n <- length(bullets)
  parse_level <- function(depth) {
    out <- list()
    while (i <= n && bullets[[i]]$depth == depth) {
      code <- bullets[[i]]$code
      i <<- i + 1L
      kids <- if (i <= n && bullets[[i]]$depth == depth + 1L) parse_level(depth + 1L) else list()
      out[[code]] <- kids
    }
    out
  }
  parse_level(0L)
}

# ---- algorithmic derivers ---------------------------------------------------
# FSO NOGA "range" codes: each code is a contiguous division range like "5-96"
# (Total), "5-43" (Sector II), "10-33" (Manufacturing), "21" (a single division).
# A code A-B is the child of the *smallest* other range that strictly contains it.
# Robust to the odd composite "77+79-82" — we read its overall [min,max] span.
noga_range_span <- function(code) {
  nums <- as.integer(regmatches(code, gregexpr("[0-9]+", code))[[1]])
  if (!length(nums)) return(NULL)
  c(min(nums), max(nums))
}
derive_noga_range <- function(codes) {
  spans <- lapply(codes, noga_range_span)
  names(spans) <- codes
  ok <- codes[!vapply(spans, is.null, logical(1))]
  contains <- function(a, b) {            # span a strictly contains span b
    sa <- spans[[a]]; sb <- spans[[b]]
    sa[1] <= sb[1] && sa[2] >= sb[2] && !(sa[1] == sb[1] && sa[2] == sb[2])
  }
  width <- function(c) spans[[c]][2] - spans[[c]][1]
  parent_of <- function(c) {
    cand <- Filter(function(p) p != c && contains(p, c) &&
                     !(spans[[p]][1] == spans[[c]][1] && spans[[p]][2] == spans[[c]][2]), ok)
    if (!length(cand)) return(NA_character_)
    cand[[which.min(vapply(cand, width, integer(1)))]]  # smallest container
  }
  parents <- vapply(ok, parent_of, character(1))
  assemble_tree(ok, setNames(parents, ok))
}

# Reparent a flat-topped dimension under a single total node. Some sources (the SNB
# cubes) list the "Total" item as a SIBLING of the category groups rather than their
# parent. `under-root <CODE>` nests every other top-level node — keeping its existing
# subtree — beneath <CODE>, so the tree reads Total -> category -> product. Works on an
# existing (source-supplied) hierarchy if present, else builds one level from the codes.
reparent_under_root <- function(existing, codes, root) {
  if (!nzchar(root %||% "")) stop("under-root: missing root code", call. = FALSE)
  if (is.null(existing) || !length(existing)) {
    if (!root %in% codes) stop(sprintf("under-root: root '%s' not a level", root), call. = FALSE)
    kids <- list(); for (c in setdiff(codes, root)) kids[[c]] <- list()
    out <- list(); out[[root]] <- kids; return(out)
  }
  if (!root %in% names(existing))
    stop(sprintf("under-root: root '%s' not a top-level node", root), call. = FALSE)
  kids <- existing[[root]]                       # keep the root's own children (if any)
  for (k in names(existing)) if (k != root) kids[[k]] <- existing[[k]]
  out <- list(); out[[root]] <- kids; out
}

# ---- shared tree assembly ---------------------------------------------------
# Given codes and a code->parent map (NA parent = root), build the nested named list
# preserving the input order of `codes` among siblings.
assemble_tree <- function(codes, parent) {
  build <- function(node) {
    kids <- codes[!is.na(parent[codes]) & parent[codes] == node]
    out <- list()
    for (k in kids) out[[k]] <- build(k)
    out
  }
  roots <- codes[is.na(parent[codes])]
  out <- list()
  for (r in roots) out[[r]] <- build(r)
  out
}

# ---- entry point ------------------------------------------------------------
# Attach a hierarchy to one dataset's split (or block-named) dimension, from its
# datasheet `## Hierarchy` block. No block (or a block with no derive/tree) is a no-op,
# leaving any source-supplied hierarchy intact. A declared tree or a `derive:` method
# overrides the source tree. Synthetic group codes are added to the dim's `levels` so
# the front-end has a label for them; codes present in the levels but absent from the
# declared tree are appended as top-level leaves so nothing vanishes.
attach_hierarchy <- function(ds, datasheet_dir) {
  f <- file.path(datasheet_dir, paste0(ds$id, ".md"))
  if (!file.exists(f)) return(ds)
  spec <- read_hierarchy_block(readLines(f, warn = FALSE))
  if (is.null(spec)) return(ds)

  dim <- spec$dim %||% ds$meta$split
  if (is.null(dim) || is.null(ds$meta$dimensions[[dim]])) {
    warning(sprintf("%s: hierarchy targets unknown dim '%s'", ds$id, dim %||% "<split>"))
    return(ds)
  }
  existing <- ds$meta$dimensions[[dim]]$hierarchy
  levels <- ds$meta$dimensions[[dim]]$levels %||% list()
  codes <- names(levels)

  if (!is.null(spec$derive)) {
    parts <- strsplit(spec$derive, "\\s+")[[1]]
    method <- parts[1]; arg <- if (length(parts) > 1) parts[2] else NULL
    tree <- switch(method,
      "noga-range" = derive_noga_range(codes),                 # ignores any source tree
      "under-root" = reparent_under_root(existing, codes, arg),
      stop(sprintf("%s: unknown hierarchy derive method '%s'", ds$id, method), call. = FALSE))
  } else if (is.null(spec$tree)) {
    return(ds)                                                 # block has neither a derive nor a tree
  } else {
    # A declared tree OVERRIDES a source-supplied hierarchy (you only write the block
    # when the source tree is missing or wrong — e.g. SNB ships the M1/M2/M3 aggregates
    # flat, but they nest). Register synthetic group labels, then validate the codes.
    for (g in names(spec$groups))
      levels[[g]] <- list(label = list(en = spec$groups[[g]]), data = FALSE)
    declared <- tree_codes(spec$tree)
    unknown <- setdiff(declared, c(codes, names(spec$groups)))
    if (length(unknown))
      warning(sprintf("%s: hierarchy references codes not in dim '%s': %s",
                      ds$id, dim, paste(unknown, collapse = ", ")))
    tree <- spec$tree
    # Append any real codes not placed in the tree as top-level leaves.
    missing <- setdiff(codes, declared)
    for (m in missing) tree[[m]] <- list()
    ds$meta$dimensions[[dim]]$levels <- levels
  }
  ds$meta$dimensions[[dim]]$hierarchy <- tree
  ds
}

# All codes appearing anywhere in a nested tree.
tree_codes <- function(tree) {
  out <- character(0)
  walk <- function(node) for (k in names(node)) { out[[length(out) + 1L]] <<- k; walk(node[[k]]) }
  walk(tree)
  unlist(out, use.names = FALSE)
}
