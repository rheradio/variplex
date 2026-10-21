# ==============================================================================
# Topic 5. Conflicts: where they come from, and how they group
#
# Most conflicts are inherited: if A requires B and B excludes C, then A
# excludes C too. The few conflicts that are not inherited are the primitive
# ones, and every other conflict is an echo of one of them along a chain of
# requirements. This file finds the primitive conflicts, explains any conflict
# (or requirement) by a chain of links, and looks at the shape of the excludes
# graph: groups of alternatives, the largest set of compatible features,
# colourings, and features that behave identically.
#
# A conflict is a relationship between two features. A rule such as "A, B and C
# cannot all be selected" is no conflict between any two of them, so it is in
# none of these results. And an explanation is made of links of the graphs, not
# of the rules of the model: it says which relationships combine, not which line
# of the model to edit.
# ==============================================================================

#' The conflicts from which all others follow
#'
#' The primitive conflicts: the conflicts that are not inherited through a
#' requirement. Every other conflict follows from one of them. The same as the
#' file __excludes_primitive.net of Strong4VM.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `from`, `to` and `reach`: how many conflicts of the
#'   excludes graph (atomic sets counted as one feature) this primitive conflict
#'   produces, itself included.
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_primitive_conflicts(band)
vp_primitive_conflicts <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  if (nrow(m$excludes) == 0) {
    return(tibble::tibble(
      from = character(0),
      to = character(0),
      reach = integer(0)
    ))
  }
  inh <- m$D %*% m$C
  i <- match(m$excludes$from, m$nodes)
  j <- match(m$excludes$to, m$nodes)
  derived <- as.vector(inh[cbind(i, j)]) > 0 | as.vector(inh[cbind(j, i)]) > 0
  below <- Matrix::colSums(m$D) + 1
  p <- m$excludes[!derived, ]
  p$reach <- as.integer(below[p$from] * below[p$to])
  p
}

#' Why two features exclude each other
#'
#' Why do two features exclude each other? The answer is a chain: the first
#' feature requires some feature x, the second requires some feature y, and x
#' and y have a primitive conflict. When several primitive conflicts can explain
#' it, each one is an `origin` of its own (all of them must be removed for the
#' conflict to disappear).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param a The name of a variable feature of the model.
#' @param b The name of another variable feature of the model.
#' @return A tibble with one row per link: `origin`, `step`, `from`, `link`
#'   ("requires" or "excludes") and `to`. No rows if the two features do not
#'   exclude each other.
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_explain_conflict(band, "TouchScreen", "BT40")
vp_explain_conflict <- function(model, a, b) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  .vp_check_features(model, c(a, b))
  conf_m <- .vp_matrix(model, "excludes")
  if (conf_m[a, b] == 0) {
    message(
      "\"",
      a,
      "\" and \"",
      b,
      "\" do not exclude each other: some valid product has both."
    )
    return(.vp_empty_explanation())
  }
  m <- .vp_merged(model)
  ra <- m$rep[[a]]
  rb <- m$rep[[b]]
  up <- function(r) c(r, m$nodes[m$D[r, ] > 0])
  prim <- vp_primitive_conflicts(model)
  ua <- up(ra)
  ub <- up(rb)
  hit <- prim[
    (prim$from %in% ua & prim$to %in% ub) |
      (prim$from %in% ub & prim$to %in% ua),
  ]
  rows <- lapply(seq_len(nrow(hit)), function(k) {
    x <- if (hit$from[k] %in% ua && hit$to[k] %in% ub) {
      hit$from[k]
    } else {
      hit$to[k]
    }
    y <- if (x == hit$from[k]) hit$to[k] else hit$from[k]
    links <- dplyr::bind_rows(
      .vp_chain_rows(model, a, x),
      tibble::tibble(from = x, link = "excludes", to = y),
      .vp_chain_rows(model, b, y)
    )
    tibble::tibble(origin = k, step = seq_len(nrow(links)), links)
  })
  dplyr::bind_rows(rows)
}

#' Why one feature requires another
#'
#' Why does a feature require another? The first route is a chain of arrows of
#' the skeleton. When the run has the at-least-one graph, further routes may
#' appear: a excludes g, and every product has g or b, so a product with a has
#' b.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param a The name of a variable feature of the model.
#' @param b The name of another variable feature of the model.
#' @param max_routes How many routes of the second kind to show at most.
#' @return A tibble like that of vp_explain_conflict(), with `route` instead of
#'   `origin`; the link "atleastone" means "every product has from or to".
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_explain_requires(band, "TouchScreen", "OLED")
vp_explain_requires <- function(model, a, b, max_routes = 3) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  .vp_check_features(model, c(a, b))
  dep_m <- .vp_matrix(model, "requires")
  if (dep_m[a, b] == 0) {
    message(
      "\"",
      a,
      "\" does not require \"",
      b,
      "\": some valid product has ",
      a,
      " without ",
      b,
      "."
    )
    return(.vp_empty_explanation(route = TRUE))
  }
  routes <- list(.vp_chain_rows(model, a, b))
  if (!is.null(model$atleastone)) {
    conf_m <- .vp_matrix(model, "excludes")
    alo_m <- .vp_matrix(model, "atleastone")
    g <- colnames(conf_m)[conf_m[a, ] > 0 & alo_m[, b] > 0]
    for (x in utils::head(g, max_routes)) {
      routes[[length(routes) + 1]] <- tibble::tibble(
        from = c(a, x),
        link = c("excludes", "atleastone"),
        to = c(x, b)
      )
    }
  }
  dplyr::bind_rows(lapply(seq_along(routes), function(k) {
    tibble::tibble(route = k, step = seq_len(nrow(routes[[k]])), routes[[k]])
  }))
}

#' Groups of any features that all exclude each other (at most one per product)
#'
#' Groups of features that all exclude one another (cliques of the excludes
#' graph): at most one of each group can be in a product. They are groups of
#' alternatives, whether or not the model declares them as such.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param min_size The smallest group to report (3 by default; every conflict is
#'   a group of 2).
#' @return A tibble with `group`, `size` and `feature`, the largest groups
#'   first.
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_alternative_groups(band)
vp_alternative_groups <- function(model, min_size = 3) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  g <- vp_igraph(model, "excludes")
  cl <- igraph::max_cliques(g, min = min_size)
  if (length(cl) == 0) {
    return(tibble::tibble(
      group = integer(0),
      size = integer(0),
      feature = character(0)
    ))
  }
  cl <- cl[order(-lengths(cl), method = "radix")]
  dplyr::bind_rows(lapply(seq_along(cl), function(k) {
    tibble::tibble(
      group = k,
      size = length(cl[[k]]),
      feature = igraph::V(g)$name[as.integer(cl[[k]])]
    )
  }))
}

#' The most features without a conflict among them
#'
#' The largest set of features with no conflict among them. No product can have
#' more variable features selected than this. Exact for small models; for large
#' ones (more than `exact_limit` features) a quick greedy search gives a set
#' that is as large as it could find, so the true largest set may be larger.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param exact_limit Up to this number of variable features the search is
#'   exact; above it, a greedy search is used.
#' @return A tibble with the column `feature`.
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_largest_compatible_set(band)
vp_largest_compatible_set <- function(model, exact_limit = 60) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  g <- vp_igraph(model, "excludes")
  if (igraph::vcount(g) <= exact_limit) {
    s <- igraph::largest_ivs(g)[[1]]
    return(tibble::tibble(feature = igraph::V(g)$name[as.integer(s)]))
  }
  message(
    "More than ",
    exact_limit,
    " features: greedy search; the true largest set may be larger."
  )
  left <- seq_len(igraph::vcount(g))
  chosen <- integer(0)
  adj <- igraph::as_adj_list(g)
  deg <- igraph::degree(g)
  while (length(left) > 0) {
    v <- left[which.min(deg[left])]
    chosen <- c(chosen, v)
    left <- setdiff(left, c(v, as.integer(adj[[v]])))
  }
  tibble::tibble(feature = igraph::V(g)$name[chosen])
}

#' The features split into groups without conflicts
#'
#' The features split into groups (colours) so that no two features of a group
#' exclude each other. Each product fits in one colour, so testing every feature
#' at least once needs at least as many products as colours. The colouring is
#' quick, not always the smallest possible.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `feature` and `colour` (a number).
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_colouring(band)
vp_colouring <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  g <- vp_igraph(model, "excludes")
  col <- igraph::greedy_vertex_coloring(g)
  tibble::tibble(feature = igraph::V(g)$name, colour = as.integer(col))
}

#' Features that behave identically
#'
#' Twins: features with exactly the same requirements, dependants and conflicts
#' (and at-least-one links). For the graphs they are interchangeable.
#' "alternatives" exclude each other; "extras" do not.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `group`, `kind` and `feature`.
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_twins(band)
vp_twins <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  if (length(.vp_nodes(model)) < 2) {
    return(tibble::tibble(
      group = integer(0),
      kind = character(0),
      feature = character(0)
    ))
  }
  dep_m <- .vp_matrix(model, "requires")
  conf_m <- .vp_matrix(model, "excludes")
  parts <- list(dep_m, Matrix::t(dep_m))
  if (!is.null(model$atleastone)) {
    parts <- c(parts, list(.vp_matrix(model, "atleastone")))
  }
  key <- function(mat) apply(as.matrix(mat), 1, paste, collapse = "")
  base <- do.call(cbind, parts)
  find <- function(mat, kind) {
    groups <- split(rownames(dep_m), key(cbind(base, mat)))
    groups <- unname(groups[lengths(groups) > 1])
    if (kind == "alternatives") {
      groups <- Filter(
        function(g) all(conf_m[g, g][upper.tri(diag(length(g)))] > 0),
        groups
      )
    }
    lapply(groups, function(g) tibble::tibble(kind = kind, feature = g))
  }
  out <- c(
    find(conf_m, "extras"),
    find(conf_m + Matrix::Diagonal(nrow(conf_m)), "alternatives")
  )
  if (length(out) == 0) {
    return(tibble::tibble(
      group = integer(0),
      kind = character(0),
      feature = character(0)
    ))
  }
  out <- lapply(seq_along(out), function(k) tibble::tibble(group = k, out[[k]]))
  dplyr::bind_rows(out)
}

# ------------------------------------------------------------- internal helpers
.vp_empty_explanation <- function(route = FALSE) {
  t <- tibble::tibble(
    origin = integer(0),
    step = integer(0),
    from = character(0),
    link = character(0),
    to = character(0)
  )
  if (route) {
    names(t)[1] <- "route"
  }
  t
}

# The chain of requirements from feature f to feature x (any member of an atomic
# set): f to its representative, then the skeleton to the representative of x,
# then x itself if it is another member of that atomic set.
.vp_chain_rows <- function(model, f, x) {
  m <- .vp_merged(model)
  rows <- tibble::tibble(
    from = character(0),
    link = character(0),
    to = character(0)
  )
  r <- m$rep[[f]]
  rx <- if (x %in% names(m$rep)) m$rep[[x]] else x
  if (r != f) {
    rows <- tibble::tibble(from = f, link = "requires", to = r)
  }
  if (r != rx) {
    skel <- vp_skeleton(model)
    skel_g <- igraph::graph_from_data_frame(
      skel,
      directed = TRUE,
      vertices = m$nodes
    )
    path <- names(igraph::shortest_paths(skel_g, r, rx, mode = "out")$vpath[[
      1
    ]])
    rows <- dplyr::bind_rows(
      rows,
      tibble::tibble(
        from = utils::head(path, -1),
        link = "requires",
        to = path[-1]
      )
    )
  }
  if (rx != x) {
    rows <- dplyr::bind_rows(
      rows,
      tibble::tibble(from = rx, link = "requires", to = x)
    )
  }
  rows
}

# --------------------------------------------------------- with the third graph
#' The at-least-one lines from which all others follow
#'
#' The primitive at-least-one lines: those that do not follow from another one.
#' "Every product has f or g" and "g requires h" give "every product has f or
#' h": at-least-one lines are inherited upwards, the mirror image of conflicts.
#' The same as the file __atleastone_primitive.net of Strong4VM
#' (vp_generate(or_graph = TRUE)).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `from` and `to` (atomic sets as their representative).
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_primitive_atleastone(band)
vp_primitive_atleastone <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  if (is.null(model$atleastone)) {
    stop(.vp_no_alo(model), call. = FALSE)
  }
  m <- .vp_merged(model)
  if (nrow(m$atleastone) == 0) {
    return(m$atleastone)
  }
  alo_dep <- m$A %*% m$D
  i <- match(m$atleastone$from, m$nodes)
  j <- match(m$atleastone$to, m$nodes)
  m$atleastone[
    !(as.vector(alo_dep[cbind(i, j)]) > 0 |
      as.vector(alo_dep[cbind(j, i)]) > 0),
  ]
}

#' Pairs of which every product has exactly one
#'
#' Opposites: pairs of features of which every product has exactly one. They
#' exclude each other and every product has one of them, so one is selected
#' exactly when the other is not. Atomic sets are features that are always
#' equal; opposites are always different. Needs the at-least-one graph.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `feature_1` and `feature_2`.
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_opposites(band)
vp_opposites <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  if (is.null(model$atleastone)) {
    stop(.vp_no_alo(model), call. = FALSE)
  }
  k <- paste(model$atleastone$from, model$atleastone$to)
  both <- model$excludes[paste(model$excludes$from, model$excludes$to) %in% k, ]
  tibble::tibble(feature_1 = both$from, feature_2 = both$to)
}

#' Requirements explained by a conflict and an at-least-one line
#'
#' Requirements that follow from a conflict and an at-least-one line: if f
#' excludes g, and every product has g or h, then f requires h. The skeleton
#' keeps such an arrow when no chain of arrows explains it; with the three
#' graphs it is explained after all. Needs the at-least-one graph.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with one row per arrow between different atomic sets that
#'   has such an explanation: `from`, `to`, `via` (one g) and `in_skeleton`
#'   (TRUE when no chain of arrows explains it: only this route does).
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_requires_from_conflicts(band)
vp_requires_from_conflicts <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  if (is.null(model$atleastone)) {
    stop(.vp_no_alo(model), call. = FALSE)
  }
  m <- .vp_merged(model)
  conf_alo <- m$C %*% m$A
  i <- match(m$requires$from, m$nodes)
  j <- match(m$requires$to, m$nodes)
  hit <- which(as.vector(conf_alo[cbind(i, j)]) > 0)
  skel <- vp_skeleton(model)
  sk <- paste(skel$from, skel$to)
  via <- vapply(
    hit,
    function(k) m$nodes[m$C[i[k], ] > 0 & m$A[, j[k]] > 0][1],
    ""
  )
  tibble::tibble(
    from = m$requires$from[hit],
    to = m$requires$to[hit],
    via = via,
    in_skeleton = paste(m$requires$from[hit], m$requires$to[hit]) %in% sk
  )
}

# ------------------------------------------------------- groups of alternatives
#' Mutually exclusive children of one parent: the alternative groups a feature
#' model would declare
#'
#' Candidate alternative groups: for each feature, its direct dependants (in the
#' skeleton) that exclude one another. In a feature model this is the shape of
#' an alternative group under a common parent, so the result suggests groups
#' that a model rebuilt from the graphs could declare, whether or not the
#' original model declares them.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param min_size The smallest group (2 by default).
#' @return A tibble with `parent`, `group`, `size` and `feature`.
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_candidate_groups(band)
vp_candidate_groups <- function(model, min_size = 2) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  skel <- vp_skeleton(model)
  conf_g <- igraph::graph_from_data_frame(
    m$excludes,
    directed = FALSE,
    vertices = m$nodes
  )
  rows <- list()
  g <- 0
  for (p in unique(skel$to)) {
    kids <- skel$from[skel$to == p]
    if (length(kids) < min_size) {
      next
    }
    cl <- igraph::max_cliques(
      igraph::induced_subgraph(conf_g, kids),
      min = min_size
    )
    for (c in cl) {
      g <- g + 1
      rows[[g]] <- tibble::tibble(
        parent = p,
        group = as.integer(g),
        size = length(c),
        feature = names(c)
      )
    }
  }
  if (g == 0) {
    return(tibble::tibble(
      parent = character(0),
      group = integer(0),
      size = integer(0),
      feature = character(0)
    ))
  }
  dplyr::bind_rows(rows)
}

#' The fewest 'at most one of' groups that state every conflict
#'
#' The primitive conflicts written as few "at most one of these" groups: a
#' greedy cover of the primitive conflicts by groups of features that all
#' exclude one another. Each group could be one declaration of the model ("at
#' most one of"), and together they state every primitive conflict, so every
#' conflict of the model follows from them and the requirements. The number of
#' groups says how many such declarations a modeller would need.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `group`, `size`, `feature` and `primitive_conflicts`
#'   (how many of them the group states).
#' @family conflicts
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_conflict_cover(band)
vp_conflict_cover <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  prim <- vp_primitive_conflicts(model)
  if (nrow(prim) == 0) {
    return(tibble::tibble(
      group = integer(0),
      size = integer(0),
      feature = character(0),
      primitive_conflicts = integer(0)
    ))
  }
  conf_m <- m$C
  key <- function(a, b) paste(pmin(a, b), pmax(a, b), sep = "\t")
  todo <- key(prim$from, prim$to)
  rows <- list()
  g <- 0
  while (length(todo) > 0) {
    e <- strsplit(todo[1], "\t", fixed = TRUE)[[1]]
    clique <- e
    repeat {
      cand <- m$nodes[
        Matrix::colSums(conf_m[clique, , drop = FALSE] > 0) == length(clique)
      ]
      cand <- setdiff(cand, clique)
      if (length(cand) == 0) {
        break
      }
      gain <- vapply(cand, function(x) sum(key(x, clique) %in% todo), 0)
      if (max(gain) == 0) {
        break
      }
      clique <- c(clique, cand[which.max(gain)])
    }
    pairs <- utils::combn(clique, 2)
    covered <- intersect(todo, key(pairs[1, ], pairs[2, ]))
    todo <- setdiff(todo, covered)
    g <- g + 1
    rows[[g]] <- tibble::tibble(
      group = as.integer(g),
      size = length(clique),
      feature = clique,
      primitive_conflicts = length(covered)
    )
  }
  dplyr::bind_rows(rows)
}
