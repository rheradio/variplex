# ==============================================================================
# Topic 7. Testing: samples of configurations
#
# A product line cannot test every product, so it tests a sample: a few
# configurations chosen so that every feature (t = 1), or every pair of features
# (t = 2), appears in every valid combination of values at least once. The
# graphs answer three questions about samples without a solver: how many
# combinations there are to cover, how many of them a given sample covers (and
# whether the sample breaks a rule), and how small a covering sample can
# possibly be.
#
# A sample is a data frame (or tibble) with one row per configuration and one
# column per feature, holding 0/1 or FALSE/TRUE. Other columns (an identifier,
# the core features) are ignored.
#
# LIMITS. For t = 2 the count of combinations is exact only with the
# at-least-one graph (or_graph = TRUE); without it, it is an upper limit. The
# lower bound on the size of a sample is a floor, not always the true minimum: a
# rule over three or more features can force more configurations. And the graphs
# cannot build a sample: a configuration must satisfy every rule of the model,
# so building one needs a solver (or a sampling tool).
# ==============================================================================

#' How many combinations a t-wise sample must cover
#'
#' How many combinations of values a t-wise sample must cover.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param t 1 (every feature selected and left out) or 2 (every valid
#'   combination of two features).
#' @return One row: `t`, `combinations` and `exact` (FALSE for t = 2 without the
#'   at-least-one graph: then the count is an upper limit, because some
#'   "neither" combinations may be impossible).
#' @family testing
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_combinations_to_cover(band, t = 1)
#' vp_combinations_to_cover(band, t = 2)
vp_combinations_to_cover <- function(model, t = 2) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  n <- length(.vp_nodes(model))
  if (t == 1) {
    return(tibble::tibble(t = 1L, combinations = 2 * n, exact = TRUE))
  }
  if (t != 2) {
    stop("t must be 1 or 2.", call. = FALSE)
  }
  alo <- if (is.null(model$atleastone)) 0 else nrow(model$atleastone)
  tibble::tibble(
    t = 2L,
    combinations = 4 *
      choose(n, 2) -
      nrow(model$requires) -
      nrow(model$excludes) -
      alo,
    exact = !is.null(model$atleastone)
  )
}

#' How much of them a sample covers
#'
#' How much of the combinations to cover a sample covers.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param sample One row per configuration, one 0/1 or logical column per
#'   variable feature.
#' @return One row per t (1 and 2): `t`, `covered`, `to_cover` and `coverage`
#'   (the share). Combinations that the sample has but that are impossible are
#'   not counted (see vp_sample_violations()).
#' @family testing
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' nodes <- with(vp_features(band), feature[status == "variable"])
#' sample <- as.data.frame(matrix(
#'   c(1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1),
#'   nrow = 2,
#'   dimnames = list(NULL, nodes)
#' ))
#' vp_coverage(band, sample)
vp_coverage <- function(model, sample) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  x <- .vp_sample_matrix(model, sample)
  n <- ncol(x)
  on <- crossprod(x) > 0
  off <- crossprod(1 - x) > 0
  mix <- crossprod(x, 1 - x) > 0
  dep_m <- as.matrix(.vp_matrix(model, "requires")) > 0
  conf_m <- as.matrix(.vp_matrix(model, "excludes")) > 0
  alo_m <- if (is.null(model$atleastone)) {
    matrix(FALSE, n, n)
  } else {
    as.matrix(.vp_matrix(model, "atleastone")) > 0
  }
  up <- upper.tri(on)
  c1 <- sum(diag(on)) + sum(diag(off))
  c2 <- sum((on & !conf_m)[up]) +
    sum((off & !alo_m)[up]) +
    sum(mix & !dep_m & !diag(n))
  tot <- c(
    vp_combinations_to_cover(model, 1)$combinations,
    vp_combinations_to_cover(model, 2)$combinations
  )
  tibble::tibble(
    t = 1:2,
    covered = c(c1, c2),
    to_cover = tot,
    coverage = ifelse(tot > 0, c(c1, c2) / pmax(tot, 1), 1)
  ) # nothing to cover: everything is covered
}

#' Which combinations a sample misses
#'
#' The combinations of two features that are possible but that the sample does
#' not have.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param sample A sample of configurations: a data frame with one row per
#'   configuration and one column per variable feature, holding 0/1 or
#'   `FALSE`/`TRUE` (other columns are ignored).
#' @return A tibble with `feature_1`, `value_1`, `feature_2`, `value_2` (TRUE =
#'   selected).
#' @family testing
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' nodes <- with(vp_features(band), feature[status == "variable"])
#' sample <- as.data.frame(matrix(
#'   c(1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1),
#'   nrow = 2,
#'   dimnames = list(NULL, nodes)
#' ))
#' head(vp_uncovered(band, sample))
vp_uncovered <- function(model, sample) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  x <- .vp_sample_matrix(model, sample)
  n <- ncol(x)
  nm <- colnames(x)
  dep_m <- as.matrix(.vp_matrix(model, "requires")) > 0
  conf_m <- as.matrix(.vp_matrix(model, "excludes")) > 0
  alo_m <- if (is.null(model$atleastone)) {
    matrix(FALSE, n, n)
  } else {
    as.matrix(.vp_matrix(model, "atleastone")) > 0
  }
  seen <- list(
    tt = crossprod(x) > 0,
    ff = crossprod(1 - x) > 0,
    tf = crossprod(x, 1 - x) > 0
  )
  out <- list()
  for (i in seq_len(n - 1)) {
    for (j in (i + 1):n) {
      if (!seen$tt[i, j] && !conf_m[i, j]) {
        out[[length(out) + 1]] <- c(i, TRUE, j, TRUE)
      }
      if (!seen$tf[i, j] && !dep_m[i, j]) {
        out[[length(out) + 1]] <- c(i, TRUE, j, FALSE)
      }
      if (!seen$tf[j, i] && !dep_m[j, i]) {
        out[[length(out) + 1]] <- c(i, FALSE, j, TRUE)
      }
      if (!seen$ff[i, j] && !alo_m[i, j]) {
        out[[length(out) + 1]] <- c(i, FALSE, j, FALSE)
      }
    }
  }
  if (length(out) == 0) {
    return(tibble::tibble(
      feature_1 = character(0),
      value_1 = logical(0),
      feature_2 = character(0),
      value_2 = logical(0)
    ))
  }
  o <- do.call(rbind, out)
  tibble::tibble(
    feature_1 = nm[o[, 1]],
    value_1 = as.logical(o[, 2]),
    feature_2 = nm[o[, 3]],
    value_2 = as.logical(o[, 4])
  )
}

#' Configurations of a sample that break a link
#'
#' Configurations of a sample that break a link of the graphs. Such a
#' configuration is not valid (or the graphs are wrong). A configuration that
#' breaks no link can still be invalid, because of a rule over three or more
#' features.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param sample A sample of configurations: a data frame with one row per
#'   configuration and one column per variable feature, holding 0/1 or
#'   `FALSE`/`TRUE` (other columns are ignored).
#' @return A tibble with `configuration` (the row number), `rule` and
#'   `features`.
#' @family testing
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' nodes <- with(vp_features(band), feature[status == "variable"])
#' sample <- as.data.frame(matrix(
#'   c(1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1),
#'   nrow = 2,
#'   dimnames = list(NULL, nodes)
#' ))
#' vp_sample_violations(band, sample)
vp_sample_violations <- function(model, sample) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  x <- .vp_sample_matrix(model, sample)
  nm <- colnames(x)
  out <- list()
  for (k in seq_len(nrow(model$requires))) {
    a <- model$requires$from[k]
    b <- model$requires$to[k]
    bad <- which(x[, a] == 1 & x[, b] == 0)
    if (length(bad)) {
      out[[length(out) + 1]] <- tibble::tibble(
        configuration = bad,
        rule = "requires",
        features = paste(a, "->", b)
      )
    }
  }
  for (k in seq_len(nrow(model$excludes))) {
    a <- model$excludes$from[k]
    b <- model$excludes$to[k]
    bad <- which(x[, a] == 1 & x[, b] == 1)
    if (length(bad)) {
      out[[length(out) + 1]] <- tibble::tibble(
        configuration = bad,
        rule = "excludes",
        features = paste(a, "--", b)
      )
    }
  }
  if (!is.null(model$atleastone)) {
    for (k in seq_len(nrow(model$atleastone))) {
      a <- model$atleastone$from[k]
      b <- model$atleastone$to[k]
      bad <- which(x[, a] == 0 & x[, b] == 0)
      if (length(bad)) {
        out[[length(out) + 1]] <- tibble::tibble(
          configuration = bad,
          rule = "atleastone",
          features = paste(a, "or", b)
        )
      }
    }
  }
  if (length(out) == 0) {
    return(tibble::tibble(
      configuration = integer(0),
      rule = character(0),
      features = character(0)
    ))
  }
  r <- dplyr::bind_rows(out)
  r[order(r$configuration, method = "radix"), ]
}

#' A lower bound on the size of any covering sample
#'
#' A lower bound on the size of any t-wise sample: no sample that covers every
#' combination can have fewer configurations. The bound is the size of the
#' largest set of things to cover that are incompatible two by two (no
#' configuration can contain two of them).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param t 1 or 2. For t = 2 the model must be small (the graph of pairs has
#'   about 2 n^2 nodes); `max_features`.
#' @param max_features For t = 2, the largest number of variable features
#'   accepted.
#' @param exact TRUE searches the largest such set exactly; FALSE uses a quick
#'   greedy search, whose bound is still valid but may be lower. By default
#'   (NULL): exact for t = 1, which is fast on the sparse graphs of real models,
#'   and for t = 2 only when the graph of pairs has at most 250 nodes (about 11
#'   features), because there the exact search can take hours.
#' @return A list-free tibble: one row per member of the incompatible set, with
#'   `t`, `bound` (the size) and `item` (a decision such as "A" or "not A" for t
#'   = 1; a pair of decisions for t = 2).
#' @family testing
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_min_sample_size(band, t = 1)
vp_min_sample_size <- function(model, t = 1, max_features = 40, exact = NULL) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  nodes <- .vp_nodes(model)
  n <- length(nodes)
  if (is.null(model$atleastone)) {
    message(
      "Without the at-least-one graph the bound may be lower than it could be."
    )
  }
  lit <- c(nodes, paste("not", nodes))
  # two decisions that no configuration has together: on/on a conflict, on/off a
  # requirement (and f with not f), off/off an at-least-one line. Sparse, so
  # that it is quick for Linux too.
  dep_s <- .vp_matrix(model, "requires")
  conf_s <- .vp_matrix(model, "excludes")
  alo_s <- if (is.null(model$atleastone)) {
    Matrix::Matrix(0, n, n, sparse = TRUE)
  } else {
    .vp_matrix(model, "atleastone")
  }
  id_s <- Matrix::Diagonal(n)
  incomp_s <- rbind(
    cbind(conf_s, dep_s + id_s),
    cbind(Matrix::t(dep_s) + id_s, alo_s)
  )
  incomp_s <- Matrix::drop0(incomp_s)
  incomp_s@x[] <- 1
  if (t == 1) {
    if (n == 0) {
      return(tibble::tibble(t = 1L, bound = 0L, item = NA_character_))
    }
    g <- igraph::graph_from_adjacency_matrix(incomp_s, mode = "undirected")
    cl <- .vp_big_clique(g, if (is.null(exact)) TRUE else exact)
    return(tibble::tibble(t = 1L, bound = length(cl), item = lit[cl]))
  }
  if (n > max_features) {
    stop(
      "Too many features for t = 2 (",
      n,
      " > ",
      max_features,
      "). Use t = 1.",
      call. = FALSE
    )
  }
  incomp <- as.matrix(incomp_s) > 0
  pr <- t(utils::combn(2 * n, 2))
  pr <- pr[!incomp[pr], , drop = FALSE]
  # a feature with itself is not a pair
  pr <- pr[(pr[, 1] - 1) %% n + 1 != (pr[, 2] - 1) %% n + 1, , drop = FALSE]
  a <- pr[, 1]
  b <- pr[, 2]
  ex <- incomp[a, a] | incomp[a, b] | incomp[b, a] | incomp[b, b]
  if (length(a) == 0) {
    return(tibble::tibble(t = 2L, bound = 0L, item = NA_character_))
  } # no pair of features: nothing to cover
  g <- igraph::graph_from_adjacency_matrix(ex * 1, mode = "undirected")
  if (is.null(exact)) {
    exact <- igraph::vcount(g) <= 250
  }
  if (!exact) {
    message(
      "The graph of pairs has ",
      igraph::vcount(g),
      " nodes: greedy search; the bound is valid but may be lower ",
      paste0(
        "than the best one (exact = TRUE forces the exact search, which can ",
        "take hours)."
      )
    )
  }
  cl <- .vp_big_clique(g, exact)
  tibble::tibble(
    t = 2L,
    bound = length(cl),
    item = paste(lit[a[cl]], "and", lit[b[cl]])
  )
}

#' A small covering sample chosen from given configurations
#'
#' A small sample that covers every combination, chosen from configurations that
#' you already have (for example, all the valid configurations of a small model,
#' or the output of a sampling tool). It picks, again and again, the
#' configuration that covers most of what is still uncovered. The result is
#' small but not always the smallest.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param pool Candidate configurations, in the format of a sample. They should
#'   be valid.
#' @param t 1 or 2.
#' @return The rows of `pool` that were picked, in the order they were picked,
#'   with a column `newly_covered`.
#' @family testing
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' nodes <- with(vp_features(band), feature[status == "variable"])
#' # every selection of the variable features that breaks no link of the graphs
#' pool <- expand.grid(rep(list(0:1), length(nodes)))
#' names(pool) <- nodes
#' bad <- unique(vp_sample_violations(band, pool)$configuration)
#' pool <- pool[-bad, ]
#' vp_pick_sample(band, pool, t = 2)
vp_pick_sample <- function(model, pool, t = 2) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  x <- .vp_sample_matrix(model, pool)
  n <- ncol(x)
  items <- function(row) {
    on <- which(row == 1)
    off <- which(row == 0)
    one <- c(paste0(on, "+"), paste0(off, "-"))
    if (t == 1) {
      return(one)
    }
    if (n < 2) {
      return(one)
    } # one feature: no pair, only its two values
    s <- ifelse(row == 1, "+", "-")
    ij <- utils::combn(n, 2)
    # a pairwise sample covers the single values too
    c(one, paste0(ij[1, ], s[ij[1, ]], ":", ij[2, ], s[ij[2, ]]))
  }
  cov <- lapply(seq_len(nrow(x)), function(k) items(x[k, ]))
  todo <- unique(unlist(cov))
  picked <- integer(0)
  gain <- integer(0)
  while (length(todo) > 0) {
    g <- vapply(cov, function(s) sum(s %in% todo), 0)
    k <- which.max(g)
    if (g[k] == 0) {
      break
    }
    picked <- c(picked, k)
    gain <- c(gain, g[k])
    todo <- setdiff(todo, cov[[k]])
  }
  out <- tibble::as_tibble(pool)[picked, ]
  out$newly_covered <- as.integer(gain)
  out
}

# ------------------------------------------------------------- internal helpers
.vp_sample_matrix <- function(model, sample) {
  nodes <- .vp_nodes(model)
  miss <- setdiff(nodes, names(sample))
  if (length(miss) > 0) {
    stop(
      "The sample has no column for: ",
      paste(miss, collapse = ", "),
      call. = FALSE
    )
  }
  x <- as.matrix(as.data.frame(sample)[, nodes, drop = FALSE])
  x <- matrix(
    as.numeric(x),
    nrow = nrow(x),
    ncol = length(nodes),
    dimnames = list(NULL, nodes)
  )
  if (!all(x %in% c(0, 1))) {
    stop("The sample must hold 0/1 or FALSE/TRUE.", call. = FALSE)
  }
  x
}

# The largest clique (exact), or a greedy clique (a valid bound, possibly
# lower): started from each of the 30 nodes of highest degree, it adds the
# candidate with the most neighbours among the remaining candidates; the best is
# kept.
.vp_big_clique <- function(g, exact = TRUE) {
  if (igraph::vcount(g) == 0) {
    return(integer(0))
  }
  if (exact) {
    return(as.integer(igraph::largest_cliques(g)[[1]]))
  }
  adj <- lapply(igraph::as_adj_list(g), as.integer)
  deg <- igraph::degree(g)
  best <- integer(0)
  for (start in utils::head(order(-deg, method = "radix"), 30)) {
    cl <- start
    cand <- adj[[start]]
    while (length(cand) > 0) {
      score <- vapply(cand, function(v) sum(adj[[v]] %in% cand), 0)
      v <- cand[which.max(score)]
      cl <- c(cl, v)
      cand <- intersect(cand, adj[[v]])
    }
    if (length(cl) > length(best)) best <- cl
  }
  best
}
