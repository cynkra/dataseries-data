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
# Grammar (syntax handled by ds_section()/ds_bullets() in R/datasheet.R):
#   - an optional `dim: <name>` line targets a non-split dimension (default: split)
#   - either a single `derive: <method>` line (algorithmic), or
#   - an indented bullet tree, 2 spaces per level:
#       - <code>                 a real level code (label comes from the data)
#       - @<code>: <Label>       a synthetic grouping header (data = false)
#
# A block may carry MORE THAN ONE directive — one dimension can need a tree and a
# sibling line dimension another (e.g. an IIP cube split by component but also drawn
# by currency, both with a "Total" to reparent). Returns NULL (no block, or a
# prose-only block) or a list of specs, each $dim plus either $derive or
# $tree (nested named list of codes) + $groups (named char: synthetic code -> label).
read_hierarchy_block <- function(lines) {
  specs <- ds_bullets(ds_section(lines, "Hierarchy"))
  if (is.null(specs)) return(NULL)
  lapply(specs, function(s) {
    out <- list(dim = s$dim)
    if (!is.null(s$derive)) { out$derive <- s$derive; return(out) }
    # Interpret the raw bullet text: "@code" declares a synthetic grouping header
    # (its display text lives in the ## Labels block); the legacy "@code: Label"
    # form still carries the text inline. Anything else is a real level code.
    groups <- character(0)
    items <- lapply(s$items, function(it) {
      txt <- it$text
      if (startsWith(txt, "@")) {
        kv <- regmatches(txt, regexec("^@([^\\s:]+)(?::\\s*(.+))?$", txt, perl = TRUE))[[1]]
        if (length(kv) < 2 || !nzchar(kv[2]))
          stop(sprintf("hierarchy: malformed group line '%s' (want '@code' or '@code: Label')", txt), call. = FALSE)
        groups[[kv[2]]] <<- if (length(kv) == 3 && nzchar(kv[3])) kv[3] else NA_character_
        list(depth = it$depth, code = kv[2])
      } else {
        list(depth = it$depth, code = txt)
      }
    })
    out$tree <- ds_tree(items)
    out$groups <- groups
    out
  })
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
attach_hierarchy <- function(ds, datasheet_dir, lines = NULL) {
  lines <- lines %||% ds_read(ds$id, datasheet_dir)
  if (is.null(lines)) return(ds)
  specs <- read_hierarchy_block(lines)
  if (is.null(specs)) return(ds)
  for (spec in specs) ds <- apply_hierarchy_spec(ds, spec)
  ds
}

# Apply one directive (a derive or a declared tree) to its target dimension.
apply_hierarchy_spec <- function(ds, spec) {
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
    # flat, but they nest). Register synthetic group codes, then validate the codes.
    # Bare "@code" groups (NA label) keep the label the ## Labels block already set;
    # the legacy inline form still writes its text here.
    for (g in names(spec$groups)) {
      if (is.na(spec$groups[[g]])) {
        lv <- levels[[g]] %||% list()
        lv$data <- FALSE
        levels[[g]] <- lv
      } else {
        levels[[g]] <- list(label = list(en = spec$groups[[g]]), data = FALSE)
      }
    }
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
