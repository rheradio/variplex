# ==============================================================================
# Topic 8. Patterns, groups and statistics
#
# Techniques of network science applied to the graphs: small patterns that mix
# requirements and conflicts, groups of closely linked features (communities),
# how the model falls apart when its hubs are removed, whether a degree
# distribution follows a power law, what a random model of the same shape would
# give, and which features look alike.
#
# LIMITS. These techniques see the graphs, so they see relationships between two
# features only. Several of them are statistical or random: a community
# detection gives different groups on different runs (repeat it), a power-law
# test needs many features to mean anything, and a baseline depends on how it
# was randomised. Measures built on shortest paths are computed on the skeleton,
# because in the complete graphs every reachable feature is one step away.
# ==============================================================================

#' The four kinds of triangle
#'
#' The four kinds of triangle: three features all related to one another, by
#' requirement (in either direction) or by conflict. Each kind is a modelling
#' idiom. A fifth pattern must never occur: a feature that requires two features
#' that exclude each other (it would be dead).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param minimal TRUE to count on the skeleton and the primitive conflicts,
#'   which drops the triangles that are mere consequences of others.
#' @return A tibble with `kind`, `meaning` and `count`.
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_triangles(band)
vp_triangles <- function(model, minimal = FALSE) {
  m <- .vp_merged(model)
  dep_m <- m$D
  conf_m <- m$C
  if (minimal) {
    skel <- vp_skeleton(model)
    prim <- vp_primitive_conflicts(model)
    mk <- function(l, sym) {
      i <- match(l$from, m$nodes)
      j <- match(l$to, m$nodes)
      if (sym) {
        i2 <- c(i, j)
        j <- c(j, i)
        i <- i2
      }
      mtx <- Matrix::sparseMatrix(
        i = i,
        j = j,
        x = 1,
        dims = rep(length(m$nodes), 2)
      )
      mtx@x[] <- 1
      mtx
    }
    dep_m <- mk(skel, FALSE)
    conf_m <- mk(prim[, c("from", "to")], TRUE)
  }
  tibble::tibble(
    kind = c(
      "no conflict",
      "one conflict",
      "two conflicts",
      "three conflicts",
      "impossible"
    ),
    meaning = c(
      "a chain of requirements",
      "alternatives with a common requirement",
      "an inherited conflict",
      "three alternatives",
      paste0(
        "a feature requiring, directly or through the third, two features ",
        "that exclude each other"
      )
    ),
    count = .vp_triangle_counts(dep_m, conf_m)
  )
}

# Shuffles the arrows of an acyclic graph keeping every in- and out-degree: two
# arrows a -> b and c -> d become a -> d and c -> b when both new arrows follow
# the order `pos` (pos[from] < pos[to]) and do not exist yet, so the result has
# no cycle and no repeated arrow. `e` is a two-column matrix of node numbers.
.vp_swap_dag <- function(e, pos, n, niter) {
  k <- nrow(e)
  if (k < 2) {
    return(e)
  }
  m <- max(1L, k %/% 4L) # swaps proposed at once, on distinct arrows
  for (b in seq_len(ceiling(niter / m))) {
    idx <- sample.int(k, 2L * m)
    i <- idx[seq_len(m)]
    j <- idx[m + seq_len(m)]
    a <- e[i, 1]
    bb <- e[i, 2]
    c <- e[j, 1]
    d <- e[j, 2]
    k1 <- (a - 1) * n + d
    k2 <- (c - 1) * n + bb
    ok <- a != c & bb != d & pos[a] < pos[d] & pos[c] < pos[bb]
    cur <- (e[, 1] - 1) * n + e[, 2]
    ok <- ok & !(k1 %in% cur) & !(k2 %in% cur)
    # two swaps of the batch must not make the same arrow
    new <- c(k1[ok], k2[ok])
    dup <- new[duplicated(new)]
    ok[ok] <- !(k1[ok] %in% dup) & !(k2[ok] %in% dup)
    e[i[ok], 2] <- d[ok]
    e[j[ok], 2] <- bb[ok]
  }
  e
}

# The five triangle counts of a requires matrix D (directed, 0/1) and an
# excludes matrix C (symmetric, 0/1). The kinds do not overlap: a triangle with
# one conflict is either two alternatives with a common requirement (both
# require the third feature) or impossible (a feature requires both, directly or
# through the third: it would be dead).
.vp_triangle_counts <- function(dep_m, conf_m) {
  dep_sym <- dep_m + Matrix::t(dep_m)
  dep_sym@x[] <- 1
  tri <- function(x_mat, y_mat, incomp) {
    sum(Matrix::diag(x_mat %*% y_mat %*% incomp))
  }
  common <- sum((dep_m %*% Matrix::t(dep_m)) * conf_m) / 2 # g -> f <- h, g # h
  # g <- f -> h, or g -> f -> h, with g # h
  dead <- sum((Matrix::t(dep_m) %*% dep_m) * conf_m) /
    2 +
    sum((dep_m %*% dep_m) * conf_m)
  c(
    tri(dep_sym, dep_sym, dep_sym) / 6,
    common,
    tri(dep_sym, conf_m, conf_m) / 2,
    tri(conf_m, conf_m, conf_m) / 6,
    dead
  )
}

#' Which kinds of triangle occur more, or less, often than by chance
#'
#' Which kinds of triangle occur more, or less, often than by chance? The
#' triangles are counted on the minimal form (the skeleton and the primitive
#' conflicts), where each link is close to one decision of whoever wrote the
#' model. Chance is a model of the same shape: the skeleton is shuffled keeping
#' how many direct requirements and dependants each feature has, and the order
#' of its features (so that no cycle appears), and the primitive conflicts are
#' shuffled keeping how many conflicts each feature has, independently of the
#' requirements. A kind that is far more frequent in the real model than in the
#' shuffled ones is a modelling idiom (a "network motif"); far less frequent, an
#' anti-motif.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param runs How many shuffled models to build.
#' @param seed The seed of the random numbers, so that the result can be
#'   repeated. The random state of the session is left as it was.
#' @return A tibble with `kind`, `observed`, `random_mean`, `random_sd`, `z`
#'   ((observed - mean) / sd; NA when the shuffled models never vary), `p_more`
#'   (the share of shuffled models with at least as many) and `p_fewer` (at most
#'   as many). The attribute "runs" says how many shuffles were kept (a shuffle
#'   of the conflicts that repeats a line is thrown away).
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_triangle_significance(band, runs = 20)
vp_triangle_significance <- function(model, runs = 100, seed = 1) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  n <- length(m$nodes)
  skel <- vp_skeleton(model)
  prim <- vp_primitive_conflicts(model)
  mat <- function(i, j, sym) {
    if (sym) {
      i2 <- c(i, j)
      j <- c(j, i)
      i <- i2
    }
    mtx <- Matrix::sparseMatrix(i = i, j = j, x = 1, dims = c(n, n))
    if (length(mtx@x)) {
      mtx@x[] <- 1
    }
    mtx
  }
  obs <- .vp_triangle_counts(
    mat(match(skel$from, m$nodes), match(skel$to, m$nodes), FALSE),
    mat(match(prim$from, m$nodes), match(prim$to, m$nodes), TRUE)
  )
  g_skel <- igraph::graph_from_data_frame(
    skel,
    directed = TRUE,
    vertices = m$nodes
  )
  g_prim <- igraph::graph_from_data_frame(
    prim[, c("from", "to")],
    directed = FALSE,
    vertices = m$nodes
  )
  .vp_local_seed(seed)
  es <- igraph::as_edgelist(g_skel, names = FALSE)
  pos <- integer(n)
  # a fixed order: no cycle can appear
  pos[as.integer(igraph::topo_sort(g_skel, mode = "out"))] <- seq_len(n)
  sims <- lapply(seq_len(runs), function(r) {
    er <- .vp_swap_dag(es, pos, n, niter = 10 * nrow(es))
    g_rew <- if (igraph::ecount(g_prim) > 1) {
      igraph::rewire(
        g_prim,
        igraph::keeping_degseq(niter = 10 * igraph::ecount(g_prim))
      )
    } else {
      g_prim
    }
    if (!igraph::is_simple(g_rew)) {
      return(NULL)
    }
    eq <- igraph::as_edgelist(g_rew, names = FALSE)
    .vp_triangle_counts(
      mat(er[, 1], er[, 2], FALSE),
      mat(eq[, 1], eq[, 2], TRUE)
    )
  })
  sims <- do.call(rbind, sims[!vapply(sims, is.null, TRUE)])
  if (is.null(sims)) {
    sims <- matrix(numeric(0), 0, 5)
  }
  mu <- colMeans(sims)
  sd <- apply(sims, 2, function(x) {
    if (length(x) > 1) stats::sd(x) else NA_real_
  })
  out <- tibble::tibble(
    kind = c(
      "no conflict",
      "one conflict",
      "two conflicts",
      "three conflicts",
      "impossible"
    ),
    observed = obs,
    random_mean = mu,
    random_sd = sd,
    z = ifelse(!is.na(sd) & sd > 0, (obs - mu) / sd, NA_real_),
    p_more = colMeans(sims >= rep(obs, each = nrow(sims))),
    p_fewer = colMeans(sims <= rep(obs, each = nrow(sims)))
  )
  attr(out, "runs") <- nrow(sims)
  out
}

#' Groups of closely linked features
#'
#' Communities: groups of features with more links inside than a random graph of
#' the same degrees would give, found on the minimal form (the complete graph
#' links every feature to everything above it, which hides the groups). By
#' default only the skeleton counts; `graphs` adds the primitive conflicts and
#' the primitive at-least-one lines (which need or_graph = TRUE). The algorithm
#' (Louvain) has a random element: fix `seed` to get the same groups again, and
#' compare several seeds before trusting them.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param seed The seed of the random numbers, so that the result can be
#'   repeated. The random state of the session is left as it was.
#' @param graphs Which graphs of the minimal form link features: any of
#'   "requires", "excludes", "atleastone".
#' @return A tibble with `feature` and `community` (a number); its attribute
#'   "modularity" says how good the split is (NA when the skeleton has no arrow:
#'   each feature is then a community of its own).
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_communities(band)
vp_communities <- function(model, seed = 1, graphs = "requires") {
  graphs <- match.arg(
    graphs,
    c("requires", "excludes", "atleastone"),
    several.ok = TRUE
  )
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  # the minimal form: skeleton, primitive conflicts and lines
  links <- vp_skeleton(model)[, c("from", "to")]
  if ("excludes" %in% graphs) {
    links <- dplyr::bind_rows(
      links,
      vp_primitive_conflicts(model)[, c("from", "to")]
    )
  }
  if ("atleastone" %in% graphs) {
    links <- dplyr::bind_rows(
      links,
      vp_primitive_atleastone(model)[, c("from", "to")]
    )
  }
  if (!"requires" %in% graphs) {
    links <- links[-seq_len(nrow(vp_skeleton(model))), ]
  }
  links$from <- unname(m$rep[links$from])
  links$to <- unname(m$rep[links$to])
  links <- links[links$from != links$to, ]
  g_und <- igraph::simplify(igraph::graph_from_data_frame(
    links,
    directed = FALSE,
    vertices = m$nodes
  ))
  .vp_local_seed(seed)
  com <- igraph::cluster_louvain(g_und)
  mem <- igraph::membership(com)
  out <- tibble::tibble(
    feature = names(m$rep),
    community = as.integer(mem[m$rep])
  )
  attr(out, "modularity") <- if (igraph::ecount(g_und) == 0) {
    NA_real_
  } else {
    igraph::modularity(com)
  } # undefined without links
  out
}

#' How alike two groupings are
#'
#' How alike two groupings of the same features are: 1 when they are the same,
#' near 0 when they are unrelated (normalised mutual information). Each grouping
#' is a tibble with a column `feature` and one column of group labels.
#'
#' @param a A grouping: a tibble with a column `feature` and one column of group
#'   labels, such as the result of [vp_communities()].
#' @param b Another grouping of the same features.
#' @param method The measure of similarity, as in [igraph::compare()]: `"nmi"`
#'   (normalised mutual information), `"vi"`, `"split.join"`, `"rand"` or
#'   `"adjusted.rand"`.
#' @return A number: 1 for the same grouping, near 0 for unrelated ones.
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_compare_groupings(
#'   vp_communities(band, seed = 1),
#'   vp_communities(band, seed = 2)
#' )
vp_compare_groupings <- function(a, b, method = "nmi") {
  common <- intersect(a$feature, b$feature)
  ga <- a[[setdiff(names(a), "feature")[1]]][match(common, a$feature)]
  gb <- b[[setdiff(names(b), "feature")[1]]][match(common, b$feature)]
  igraph::compare(
    as.integer(factor(ga)),
    as.integer(factor(gb)),
    method = method
  )
}

#' How the skeleton falls apart when hubs are removed
#'
#' Robustness: remove the most required features one at a time and see how much
#' of the skeleton survives. With `strategy = "random"` the features are removed
#' at random instead, which gives the baseline.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param steps How many features to remove.
#' @param strategy `"hubs"` removes the most required features first; `"random"`
#'   removes them at random (the baseline).
#' @param seed The seed of the random numbers, so that the result can be
#'   repeated. The random state of the session is left as it was.
#' @return A tibble with `removed` (how many), `feature` (the one removed at
#'   that step), `links_left` (arrows of the skeleton among the remaining
#'   features) and `largest_piece` (features in the largest connected piece).
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_robustness(band, steps = 3)
vp_robustness <- function(
  model,
  steps = 5,
  strategy = c("hubs", "random"),
  seed = 1
) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  strategy <- match.arg(strategy)
  m <- .vp_merged(model)
  g <- igraph::graph_from_data_frame(
    vp_skeleton(model),
    directed = TRUE,
    vertices = m$nodes
  )
  required_by <- Matrix::colSums(m$D)
  .vp_local_seed(seed)
  order <- if (strategy == "hubs") {
    names(.vp_sort(required_by, decreasing = TRUE))
  } else {
    sample(m$nodes)
  }
  rows <- list(tibble::tibble(
    removed = 0L,
    feature = NA_character_,
    links_left = igraph::ecount(g),
    largest_piece = max(igraph::components(g, mode = "weak")$csize)
  ))
  for (k in seq_len(min(steps, length(order) - 1))) {
    g <- igraph::delete_vertices(g, order[k])
    rows[[k + 1]] <- tibble::tibble(
      removed = k,
      feature = order[k],
      links_left = igraph::ecount(g),
      largest_piece = max(igraph::components(g, mode = "weak")$csize)
    )
  }
  dplyr::bind_rows(rows)
}

#' How deep in the conflicts each feature sits
#'
#' Coreness in the excludes graph: how deep in a dense region of conflicts each
#' feature sits (0: no conflict).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `feature` and `coreness`.
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_coreness(band)
vp_coreness <- function(model) {
  g <- vp_igraph(model, "excludes")
  tibble::tibble(
    feature = igraph::V(g)$name,
    coreness = as.integer(igraph::coreness(g))
  )
}

#' Does a degree distribution follow a power law?
#'
#' A formal test of whether a degree distribution follows a power law (Clauset
#' et al.). A small p-value (below 0.1) rejects the power law. Test the
#' skeleton: in the complete graph, any deep hierarchy gives a long tail by
#' itself.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param graph Which graph: `"requires"`, `"excludes"` or `"atleastone"` (the
#'   last one needs `or_graph = TRUE` in [vp_generate()]).
#' @param seed The seed of the random numbers, so that the result can be
#'   repeated. The random state of the session is left as it was.
#' @return One row: `graph`, `features` (with a degree above 0), `alpha`,
#'   `xmin`, `p_value` and `verdict`. The p-value comes from a simulation;
#'   `seed` makes it repeatable.
#' @family patterns
#' @export
#' @examples
#' \donttest{
#' bb <- vp_generate(vp_example("busybox_01.uvl"))
#' vp_power_law(bb)
#' }
vp_power_law <- function(
  model,
  graph = c("skeleton", "requires", "excludes"),
  seed = 1
) {
  graph <- match.arg(graph)
  .vp_local_seed(seed) # the p-value is estimated by simulation
  d <- vp_degree_distribution(model, graph, "in")
  x <- rep(d$degree, d$features)
  x <- x[x > 0]
  if (length(x) < 50) {
    warning(
      "Fewer than 50 features with a degree above 0: the test means little.",
      call. = FALSE
    )
  }
  fit <- igraph::fit_power_law(x, implementation = "plfit", p.value = TRUE)
  tibble::tibble(
    graph = graph,
    features = length(x),
    alpha = fit$alpha,
    xmin = fit$xmin,
    p_value = fit$KS.p,
    verdict = ifelse(
      fit$KS.p < 0.1,
      "not a power law",
      "a power law cannot be rejected"
    )
  )
}

#' What a random model of the same shape would give
#'
#' A baseline: shuffle the skeleton many times, keeping how many direct
#' requirements and dependants each feature has (and the order of the features,
#' so that no cycle appears), and count the arrows that the shuffled hierarchy
#' implies. Compare the real number with the spread of the shuffled ones to see
#' whether the model is unusual or just what any hierarchy of that shape would
#' give.
#'
#' Only the requires graph: conflicts and at-least-one lines play no part,
#' neither in the shuffle nor in the numbers. (vp_triangle_significance() also
#' shuffles the primitive conflicts, for triangles; nothing here shuffles the
#' at-least-one lines.)
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param runs How many randomised models to build.
#' @param seed The seed of the random numbers, so that the result can be
#'   repeated. The random state of the session is left as it was.
#' @return A tibble with one row per shuffle: `run`, `arrows` (of the complete
#'   graph it implies) and `implicit_share`; its attribute "observed" holds the
#'   real values.
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' b <- vp_baseline(band, runs = 20)
#' summary(b$arrows)
#' attr(b, "observed")
vp_baseline <- function(model, runs = 200, seed = 1) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  skel <- igraph::graph_from_data_frame(
    vp_skeleton(model),
    directed = TRUE,
    vertices = m$nodes
  )
  closure <- function(g) {
    sum(igraph::ego_size(g, order = igraph::vcount(g), mode = "out")) -
      igraph::vcount(g)
  }
  .vp_local_seed(seed)
  e <- igraph::as_edgelist(skel, names = FALSE)
  n <- igraph::vcount(skel)
  pos <- integer(n)
  # a fixed order: no cycle can appear
  pos[as.integer(igraph::topo_sort(skel, mode = "out"))] <- seq_len(n)
  vals <- vapply(
    seq_len(runs),
    function(r) {
      er <- .vp_swap_dag(e, pos, n, niter = 10 * nrow(e))
      closure(
        igraph::graph_from_edgelist(er, directed = TRUE) |>
          igraph::add_vertices(n - max(c(0, er)))
      )
    },
    0
  )
  out <- tibble::tibble(
    run = seq_len(runs),
    arrows = vals,
    implicit_share = 1 - igraph::ecount(skel) / vals
  )
  attr(out, "observed") <- c(
    arrows = nrow(m$requires),
    implicit_share = 1 - igraph::ecount(skel) / nrow(m$requires)
  )
  out[!is.na(out$arrows), ]
}

#' Features most alike in one graph
#'
#' The features most alike a given one in one graph (Jaccard similarity of their
#' neighbours: 1 for the same neighbours, 0 for none in common).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param feature The name of a variable feature of the model.
#' @param graph Which graph: `"requires"`, `"excludes"` or `"atleastone"` (the
#'   last one needs `or_graph = TRUE` in [vp_generate()]).
#' @return A tibble with `feature` and `similarity`, the most similar first.
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_similar_features(band, "BLEv40")
vp_similar_features <- function(
  model,
  feature,
  graph = c("excludes", "requires", "atleastone")
) {
  graph <- match.arg(graph)
  .vp_check_features(model, feature)
  g <- vp_igraph(model, graph)
  jac <- igraph::similarity(g, method = "jaccard", mode = "all", loops = FALSE)
  dimnames(jac) <- list(igraph::V(g)$name, igraph::V(g)$name)
  s <- jac[feature, ]
  s <- s[names(s) != feature]
  s <- .vp_sort(s, decreasing = TRUE)
  tibble::tibble(feature = names(s), similarity = unname(s))
}

#' Alike in conflicts, different in requirements
#'
#' The odd ones out: pairs of features that are very alike in their conflicts
#' but differ in what they require. Such a difference may be intended, or a sign
#' of a missing rule: a question for whoever maintains the model.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param threshold How alike the conflicts must be (Jaccard, 0.6 by default).
#' @return A tibble with `feature_1`, `feature_2`, `conflict_similarity`,
#'   `requires_similarity` and `differs_in`.
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_odd_ones(band, threshold = 0.5)
vp_odd_ones <- function(model, threshold = 0.6) {
  gc <- vp_igraph(model, "excludes")
  jac_c <- igraph::similarity(gc, method = "jaccard")
  nm <- igraph::V(gc)$name
  dep_m <- .vp_matrix(model, "requires")
  rep <- .vp_representative(model)
  idx <- which(jac_c >= threshold & upper.tri(jac_c), arr.ind = TRUE)
  idx <- idx[
    Matrix::rowSums(.vp_matrix(model, "excludes"))[idx[, 1]] > 0 &
      rep[nm[idx[, 1]]] != rep[nm[idx[, 2]]],
    ,
    drop = FALSE
  ]
  rows <- lapply(seq_len(nrow(idx)), function(k) {
    a <- nm[idx[k, 1]]
    b <- nm[idx[k, 2]]
    ra <- setdiff(colnames(dep_m)[dep_m[a, ] > 0], b)
    # each one's needs, the other aside
    rb <- setdiff(colnames(dep_m)[dep_m[b, ] > 0], a)
    if (setequal(ra, rb)) {
      return(NULL)
    }
    js <- if (length(union(ra, rb))) {
      length(intersect(ra, rb)) / length(union(ra, rb))
    } else {
      1
    }
    tibble::tibble(
      feature_1 = a,
      feature_2 = b,
      conflict_similarity = jac_c[idx[k, 1], idx[k, 2]],
      requires_similarity = js,
      differs_in = paste(
        c(
          if (length(setdiff(ra, rb))) {
            paste(a, "alone requires", paste(setdiff(ra, rb), collapse = ", "))
          },
          if (length(setdiff(rb, ra))) {
            paste(b, "alone requires", paste(setdiff(rb, ra), collapse = ", "))
          }
        ),
        collapse = "; "
      )
    )
  })
  out <- dplyr::bind_rows(rows)
  if (nrow(out) == 0) {
    return(tibble::tibble(
      feature_1 = character(0),
      feature_2 = character(0),
      conflict_similarity = numeric(0),
      requires_similarity = numeric(0),
      differs_in = character(0)
    ))
  }
  out[
    order(-out$conflict_similarity, out$requires_similarity, method = "radix"),
  ]
}

#' Features grouped by their measures
#'
#' Features grouped by their measures (the columns of vp_feature_table()):
#' features in the same group play a similar role. Hierarchical clustering on
#' the scaled measures.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param groups How many groups.
#' @param measures The columns of [vp_feature_table()] to group by.
#' @return A tibble with `feature` and `group`.
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_feature_groups(band, groups = 3)
vp_feature_groups <- function(
  model,
  groups = 4,
  measures = c("required_by", "requires", "excludes", "level", "betweenness")
) {
  t <- vp_feature_table(model)
  if (nrow(t) < 2) {
    return(tibble::tibble(feature = t$feature, group = rep(1L, nrow(t))))
  } # nothing to cluster
  x <- scale(as.matrix(t[, measures]))
  x[is.nan(x) | is.na(x)] <- 0
  tibble::tibble(
    feature = t$feature,
    group = as.integer(stats::cutree(
      stats::hclust(stats::dist(x)),
      k = min(groups, nrow(t))
    ))
  )
}

# --------------------------------------------------------- how the model splits
#' Parts of the model that no relationship ties together
#'
#' Independent parts: groups of features that no relationship ties to the rest
#' (connected pieces of the three graphs taken together). As far as
#' relationships between two features go, each part can be configured, and
#' tested, on its own: a choice in one part never forces or forbids anything in
#' another.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `part`, `size` and `feature`, the largest parts first
#'   (a feature in no graph is a part alone).
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_independent_parts(band)
vp_independent_parts <- function(model) {
  nodes <- .vp_nodes(model)
  links <- dplyr::bind_rows(model$requires, model$excludes, model$atleastone)
  g <- igraph::graph_from_data_frame(links, directed = FALSE, vertices = nodes)
  comp <- igraph::components(g)
  ord <- order(-comp$csize[comp$membership], comp$membership, method = "radix")
  part <- match(comp$membership, unique(comp$membership[ord]))
  out <- tibble::tibble(
    part = part,
    size = as.integer(comp$csize[comp$membership]),
    feature = nodes
  )
  out[order(out$part, match(out$feature, nodes), method = "radix"), ]
}

#' Single features that hold two parts together
#'
#' Cut features: single features that hold two parts of the model together.
#' Removing one splits its part into several pieces. Computed on the minimal
#' form (skeleton, primitive conflicts and, with or_graph = TRUE, primitive
#' at-least-one lines), which is what was written, roughly; on the complete
#' graphs almost nothing is a cut.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `feature`, `pieces` (how many pieces its part falls
#'   into without it) and `largest_piece`.
#' @family patterns
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_cut_features(band)
vp_cut_features <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  links <- dplyr::bind_rows(
    vp_skeleton(model),
    vp_primitive_conflicts(model)[, c("from", "to")],
    if (!is.null(model$atleastone)) vp_primitive_atleastone(model)
  )
  g <- igraph::graph_from_data_frame(
    links,
    directed = FALSE,
    vertices = m$nodes
  )
  cut <- igraph::V(g)$name[as.integer(igraph::articulation_points(g))]
  if (length(cut) == 0) {
    return(tibble::tibble(
      feature = character(0),
      pieces = integer(0),
      largest_piece = integer(0)
    ))
  }
  memb <- igraph::components(g)$membership
  rows <- lapply(cut, function(f) {
    part <- igraph::V(g)$name[memb == memb[igraph::V(g)$name == f]]
    h <- igraph::delete_vertices(igraph::induced_subgraph(g, part), f)
    cs <- igraph::components(h)$csize
    tibble::tibble(
      feature = f,
      pieces = length(cs),
      largest_piece = as.integer(max(cs))
    )
  })
  out <- dplyr::bind_rows(rows)
  out[order(-out$pieces, out$largest_piece, method = "radix"), ]
}
