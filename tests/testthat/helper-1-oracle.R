# ==============================================================================
# Helpers of the tests: the checks of the original suite of Strong4VM as
# testthat expectations, an enumerator of the valid configurations of a small
# formula (the oracle: it does not use Strong4VM nor igraph), and builders of
# models, from runs of Strong4VM or from links written by hand.
# ==============================================================================

# The checks of the original suite, as testthat expectations: `check(name,
# expr)` expects a single TRUE.
check <- function(name, expr, detail = NULL) {
  ok <- tryCatch(isTRUE(expr), error = function(e) {
    detail <<- conditionMessage(e)
    FALSE
  })
  testthat::expect(
    ok,
    paste0(
      name,
      if (!is.null(detail)) paste0("\n  ", paste(detail, collapse = " "))
    )
  )
  invisible(ok)
}
# A check that cannot run here (the reason is printed only with
# options(vptest.verbose = TRUE)).
skip_note <- function(name, why) {
  if (isTRUE(getOption("vptest.verbose"))) {
    message("SKIP ", name, " (", why, ")")
  }
}
section <- function(title) invisible(NULL)

#' An error is raised, and its message matches `pattern`.
fails_with <- function(expr, pattern) {
  msg <- tryCatch(
    {
      force(expr)
      NULL
    },
    error = function(e) conditionMessage(e)
  )
  !is.null(msg) && grepl(pattern, msg)
}

# ------------------------------------------------------------------- the oracle
#' A DIMACS file: names (variable number -> name, from the comments "c N name")
#' and clauses.
read_dimacs <- function(path) {
  lines <- readLines(path, warn = FALSE)
  names <- character(0)
  cl <- list()
  for (l in lines) {
    if (grepl("^c [0-9]+ ", l)) {
      parts <- regmatches(l, regexec("^c ([0-9]+) (.*)$", l))[[1]]
      names[parts[2]] <- parts[3]
    } else if (!grepl("^[cp]", l) && nzchar(trimws(l))) {
      lits <- as.integer(strsplit(trimws(l), "[[:space:]]+")[[1]])
      cl[[length(cl) + 1]] <- lits[lits != 0]
    }
  }
  nv <- max(abs(unlist(cl)), as.integer(names(names)))
  nm <- paste0("v", seq_len(nv))
  nm[as.integer(names(names))] <- names
  list(n = nv, names = nm, clauses = cl)
}

#' Every solution of a CNF formula, by backtracking with a check of the clauses
#' that become fully assigned. Returns a logical matrix (one row per solution,
#' one column per variable), or NULL when there are more than `max` solutions.
enumerate <- function(f, max = 200000) {
  n <- f$n
  occ <- vector("list", n)
  # a clause is fully assigned when its largest variable is
  last <- vapply(f$clauses, function(c) max(abs(c)), 0L)
  for (k in seq_along(f$clauses)) {
    occ[[last[k]]] <- c(occ[[last[k]]], k)
  }
  a <- logical(n)
  sols <- list()
  count <- 0L
  rec <- function(v) {
    if (count > max) {
      return(invisible())
    }
    if (v > n) {
      count <<- count + 1L
      sols[[count]] <<- a
      return(invisible())
    }
    for (val in c(FALSE, TRUE)) {
      # nolint start: assignment_linter. A closure updates its parent.
      a[v] <<- val
      # nolint end
      ok <- TRUE
      for (k in occ[[v]]) {
        c <- f$clauses[[k]]
        if (!any(a[abs(c)] == (c > 0))) {
          ok <- FALSE
          break
        }
      }
      if (ok) rec(v + 1L)
    }
  }
  rec(1L)
  if (count > max) {
    return(NULL)
  }
  m <- do.call(rbind, sols)
  if (is.null(m)) {
    m <- matrix(FALSE, 0, n)
  }
  colnames(m) <- f$names
  m
}

#' Everything the oracle knows about a model whose valid configurations are the
#' rows of X (columns: the variable features of the graphs, in their order).
#' Relations as sets of keys "a\tb".
truth <- function(x_mat) {
  nm <- colnames(x_mat)
  n <- ncol(x_mat)
  key <- function(i, j) paste(nm[i], nm[j], sep = "\t")
  ukey <- function(i, j) {
    paste(pmin(nm[i], nm[j]), pmax(nm[i], nm[j]), sep = "\t")
  }
  tt <- crossprod(x_mat) > 0
  tf <- crossprod(x_mat, !x_mat) > 0
  ff <- crossprod(!x_mat) > 0
  ij <- which(upper.tri(tt) | lower.tri(tt), arr.ind = TRUE)
  req <- ij[!tf[ij], , drop = FALSE]
  up <- which(upper.tri(tt), arr.ind = TRUE)
  exc <- up[!tt[up], , drop = FALSE]
  alo <- up[!ff[up], , drop = FALSE]
  list(
    X = x_mat,
    names = nm,
    tt = tt,
    tf = tf,
    ff = ff,
    requires = key(req[, 1], req[, 2]),
    excludes = ukey(exc[, 1], exc[, 2]),
    atleastone = ukey(alo[, 1], alo[, 2])
  )
}

#' Is this mix of decisions possible in some valid configuration? (on: selected;
#' off: left out)
possible <- function(truth_t, on = character(0), off = character(0)) {
  x_mat <- truth_t$X
  ok <- rep(TRUE, nrow(x_mat))
  for (f in on) {
    ok <- ok & x_mat[, f]
  }
  for (f in off) {
    ok <- ok & !x_mat[, f]
  }
  any(ok)
}

keys <- function(l, undirected = FALSE) {
  if (is.null(l) || nrow(l) == 0) {
    return(character(0))
  }
  if (undirected) {
    paste(pmin(l$from, l$to), pmax(l$from, l$to), sep = "\t")
  } else {
    paste(l$from, l$to, sep = "\t")
  }
}

# -------------------------------------------------------------- building models
#' Runs the engine on a model (UVL or DIMACS) into `dir`, with or_graph, kernel
#' and keep_dimacs; returns the prefix.
run_vp <- function(model, dir, ...) {
  args <- utils::modifyList(
    list(or_graph = TRUE, kernel = TRUE, keep_dimacs = TRUE),
    list(...)
  )
  do.call(vp_generate, c(list(model, output_dir = dir, read = FALSE), args))
}

#' A model made from links written by hand: writes Pajek files into a temporary
#' folder and reads them back with vp_read(), so that the reader is exercised
#' too. `requires` etc. are data frames with `from` and `to`.
model_from_links <- function(
  nodes,
  requires = NULL,
  excludes = NULL,
  atleastone = NULL,
  core = character(0),
  dead = character(0),
  name = "handmade",
  atomic = NULL,
  dir = tempfile("vpmodel")
) {
  dir.create(dir, recursive = TRUE)
  esc <- function(x) gsub('"', '\\\\"', x)
  write_net <- function(file, links, kind) {
    id <- match(c(links$from, links$to), nodes)
    lines <- c(
      paste("*Vertices", length(nodes)),
      paste0(seq_along(nodes), ' "', esc(nodes), '"'),
      kind
    )
    if (!is.null(links) && nrow(links) > 0) {
      lines <- c(lines, paste(match(links$from, nodes), match(links$to, nodes)))
    }
    writeLines(lines, file.path(dir, paste0(name, "__", file)))
  }
  e <- data.frame(from = character(0), to = character(0))
  write_net("requires.net", if (is.null(requires)) e else requires, "*Arcs")
  write_net("excludes.net", if (is.null(excludes)) e else excludes, "*Edges")
  if (!is.null(atleastone)) {
    write_net("atleastone.net", atleastone, "*Edges")
  }
  writeLines(
    if (length(core)) paste0('0 "', esc(core), '"') else character(0),
    file.path(dir, paste0(name, "__core.txt"))
  )
  writeLines(
    if (length(dead)) paste0('0 "', esc(dead), '"') else character(0),
    file.path(dir, paste0(name, "__dead.txt"))
  )
  if (!is.null(atomic)) {
    writeLines(
      vapply(atomic, paste, "", collapse = "\t"),
      file.path(dir, paste0(name, "__atomic.txt"))
    )
  }
  vp_read(file.path(dir, name))
}

#' The graphs of a formula, as Strong4VM would write them, computed from its
#' configurations (the oracle), and read back as a model. Used to make models
#' from hand-written formulas without running Strong4VM.
model_from_configs <- function(x_mat, name = "fromconfigs") {
  always <- colSums(x_mat) == nrow(x_mat)
  never <- colSums(x_mat) == 0
  vars <- colnames(x_mat)[!always & !never]
  truth_t <- truth(x_mat[, vars, drop = FALSE])
  split_keys <- function(k) {
    if (length(k)) {
      data.frame(from = sub("\t.*", "", k), to = sub(".*\t", "", k))
    } else {
      NULL
    }
  }
  model_from_links(
    vars,
    split_keys(truth_t$requires),
    split_keys(truth_t$excludes),
    split_keys(truth_t$atleastone),
    core = colnames(x_mat)[always],
    dead = colnames(x_mat)[never],
    name = name
  )
}

# --------------------------------------------------- reading files and drawings
read_net_keys <- function(path, undirected) {
  g <- .vp_read_pajek(path)
  if (!length(g$from)) {
    return(character(0))
  }
  a <- g$names[g$from]
  b <- g$names[g$to]
  if (undirected) {
    paste(pmin(a, b), pmax(a, b), sep = "\t")
  } else {
    paste(a, b, sep = "\t")
  }
}

# the links of a DOT text, as a tibble: from, to, kind (requires, excludes,
# atleastone, cross_tree, tree), thick
parse_dot <- function(txt) {
  l <- strsplit(txt, "\n")[[1]]
  e <- grep('^  ".*" -> ".*" \\[.*\\];$', l, value = TRUE)
  m <- regmatches(
    e,
    regexec(
      '^  "((?:[^"\\\\]|\\\\.)*)" -> "((?:[^"\\\\]|\\\\.)*)" \\[(.*)\\];$',
      e,
      perl = TRUE
    )
  )
  a <- vapply(m, `[`, "", 4)
  kind <- ifelse(
    grepl("arrowhead=none", a),
    "tree",
    ifelse(
      grepl("#B3261E", a),
      "excludes",
      ifelse(
        grepl("#1B7F3B", a),
        "atleastone",
        ifelse(grepl("style=dashed", a), "cross_tree", "requires")
      )
    )
  )
  n <- grep(
    '^  "((?:[^"\\\\]|\\\\.)*)"( \\[.*\\])?;$',
    l,
    value = TRUE,
    perl = TRUE
  )
  list(
    links = tibble::tibble(
      from = vapply(m, `[`, "", 2),
      to = vapply(m, `[`, "", 3),
      kind = kind,
      thick = grepl("penwidth=2.6", a)
    ),
    nodes = sub('^  "((?:[^"\\\\]|\\\\.)*)".*$', "\\1", n, perl = TRUE),
    lines = l
  )
}
ukeys <- function(f, t) paste(pmin(f, t), pmax(f, t), sep = "\t")
