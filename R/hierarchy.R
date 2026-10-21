# ==============================================================================
# Topic 3. Layers and hierarchy: how the dependencies are organised
#
# "A requires B" never goes round in a circle, once the features that require
# each other (the atomic sets) count as one. So the requires graph is a
# hierarchy: some features need nothing, others need those, and so on. The
# functions of this file describe that hierarchy: its atomic sets, its skeleton
# (the arrows that do not follow from others), its levels, how deep and how wide
# it is, its chains, and the feature tree that it suggests.
#
# Everything here uses the requires graph only. A rule that ties three or more
# features (such as "A needs B or C") leaves no arrow, so it is invisible to
# every function of this file.
# ==============================================================================

#' Features always selected together
#'
#' The atomic sets: groups of features that require each other, so that a
#' product has all of them or none.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with one row per feature of a set of two or more: `set` (a
#'   number), `feature`, and `representative` (the first feature of the set,
#'   which stands for it in the skeleton).
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_atomic_sets(band)
vp_atomic_sets <- function(model) {
  if (identical(model$form, "minimal")) {
    return(model$sets)
  }
  a <- model$atomic
  if (nrow(a) == 0) {
    return(tibble::tibble(
      set = integer(0),
      feature = character(0),
      representative = character(0)
    ))
  }
  a$representative <- a$feature[!duplicated(a$set)][a$set]
  a
}

#' The arrows that do not follow from others
#'
#' The skeleton of the requires graph: the arrows that do not follow from a
#' chain of other arrows (its transitive reduction). Each atomic set appears
#' once, under its representative. It is the same as the file
#' __requires_skeleton.net of Strong4VM.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with the columns `from` and `to`.
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_skeleton(band)
vp_skeleton <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  if (nrow(m$requires) == 0) {
    return(m$requires)
  }
  dep_2 <- m$D %*% m$D
  i <- match(m$requires$from, m$nodes)
  j <- match(m$requires$to, m$nodes)
  m$requires[as.vector(dep_2[cbind(i, j)]) == 0, ]
}

#' The arrows that follow from others, and through what
#'
#' The arrows of the requires graph that follow from others, with one feature
#' through which each one passes.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with the columns `from`, `to` and `via`: from requires via,
#'   and via requires to.
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_implied_requires(band)
vp_implied_requires <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  dep_m <- m$D
  i <- match(m$requires$from, m$nodes)
  j <- match(m$requires$to, m$nodes)
  dep_2 <- dep_m %*% dep_m
  red <- which(as.vector(dep_2[cbind(i, j)]) > 0)
  via <- vapply(
    red,
    function(k) {
      mid <- which(dep_m[i[k], ] > 0 & dep_m[, j[k]] > 0)
      m$nodes[mid[1]]
    },
    ""
  )
  tibble::tibble(
    from = m$requires$from[red],
    to = m$requires$to[red],
    via = via
  )
}

#' The layer of each feature
#'
#' The level of each feature: the length of the longest chain of requirements
#' that starts from it. Level 0: it needs nothing; level 1: it needs only
#' features of level 0; and so on.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with the columns `feature` and `level`, for every variable
#'   feature (the members of an atomic set share the level of their set).
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_levels(band)
vp_levels <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  lv <- .vp_levels_merged(model)
  rep <- .vp_representative(model)
  tibble::tibble(feature = names(rep), level = unname(lv[rep]))
}

#' The length of the longest chain of requirements
#'
#' The depth of the model: the number of features in its longest chain of
#' requirements (one more than the highest level).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return An integer.
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_depth(band)
vp_depth <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  lv <- .vp_levels_merged(model)
  if (length(lv) == 0) {
    return(0L)
  }
  as.integer(max(lv) + 1)
}

#' One longest chain
#'
#' One longest chain of requirements: each feature requires the next one.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with the columns `step` and `feature`.
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_longest_chain(band)
vp_longest_chain <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  lv <- .vp_levels_merged(model)
  skel <- vp_skeleton(model)
  cur <- names(lv)[which.max(lv)]
  chain <- cur
  while (lv[cur] > 0) {
    nxt <- skel$to[skel$from == cur]
    cur <- nxt[which(lv[nxt] == lv[cur] - 1)[1]]
    chain <- c(chain, cur)
  }
  tibble::tibble(step = seq_along(chain), feature = chain)
}

#' The largest number of features none of which requires another
#'
#' The width of the model: the largest number of features none of which requires
#' another (atomic sets count as one). By Dilworth's theorem it is also the
#' smallest number of chains that cover all the features.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return An integer.
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_width(band)
vp_width <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  nrow(.vp_chain_cover(model)$antichain)
}

#' One such set
#'
#' One largest set of features none of which requires another.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with the column `feature` (representatives of atomic sets).
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_largest_unrelated_set(band)
vp_largest_unrelated_set <- function(model) {
  .vp_chain_cover(.vp_complete(model))$antichain
}

#' The fewest chains that cover all features
#'
#' The smallest set of chains that covers all the features (Dilworth's theorem):
#' each chain goes from a feature to one it requires, and so on. There are as
#' many chains as the width.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with the columns `chain`, `position` and `feature`.
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_chains(band)
vp_chains <- function(model) .vp_chain_cover(.vp_complete(model))$chains

#' Features that need nothing
#'
#' Features that need nothing (the foundations, level 0).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with the column `feature` (representatives of atomic sets).
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_foundations(band)
vp_foundations <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  tibble::tibble(feature = m$nodes[Matrix::rowSums(m$D) == 0])
}

#' Features that nothing needs
#'
#' Features that nothing needs (the leaves). They can be removed without
#' breaking any other feature.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with the column `feature` (representatives of atomic sets).
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_leaves(band)
vp_leaves <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  tibble::tibble(feature = m$nodes[Matrix::colSums(m$D) == 0])
}

#' What some features bring along
#'
#' What some features need: the features themselves and every feature they
#' require (their "up-set").
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param features One feature or several.
#' @return A tibble with the columns `feature` and `brought_by` (the first given
#'   feature that brings it; a given feature is brought by itself).
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_upset(band, "TouchScreen")
vp_upset <- function(model, features) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  features <- .vp_check_features(model, features)
  dep_m <- .vp_matrix(model, "requires")
  out <- lapply(features, function(f) {
    tibble::tibble(feature = colnames(dep_m)[dep_m[f, ] > 0], brought_by = f)
  })
  # a given feature is brought by itself
  given <- tibble::tibble(feature = features, brought_by = features)
  (function(x) x[!duplicated(x$feature), ])(dplyr::bind_rows(given, out))
}

#' What depends on some features
#'
#' What depends on some features: the features themselves and every feature that
#' requires one of them (their "down-set", or impact set).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param features The names of one or more variable features of the model.
#' @return A tibble with the columns `feature` and `depends_on` (the first given
#'   feature that it depends on; a given feature depends on itself).
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_downset(band, "Screen")
vp_downset <- function(model, features) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  features <- .vp_check_features(model, features)
  dep_m <- .vp_matrix(model, "requires")
  out <- lapply(features, function(f) {
    tibble::tibble(feature = rownames(dep_m)[dep_m[, f] > 0], depends_on = f)
  })
  # a given feature stands for itself
  given <- tibble::tibble(feature = features, depends_on = features)
  (function(x) x[!duplicated(x$feature), ])(dplyr::bind_rows(given, out))
}

#' What two features both need
#'
#' The features that two features both require (shared infrastructure).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param a The name of a variable feature of the model.
#' @param b The name of another variable feature of the model.
#' @return A tibble with the column `feature`.
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_common_requirements(band, "TouchScreen", "MovementFilter")
vp_common_requirements <- function(model, a, b) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  .vp_check_features(model, c(a, b))
  dep_m <- .vp_matrix(model, "requires")
  tibble::tibble(feature = colnames(dep_m)[dep_m[a, ] > 0 & dep_m[b, ] > 0])
}

#' What needs both of two features
#'
#' The features that require both of two features (where two parts of the model
#' are tied together).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param a The name of a variable feature of the model.
#' @param b The name of another variable feature of the model.
#' @return A tibble with the column `feature`.
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_common_dependants(band, "Screen", "HeartRateSensor")
vp_common_dependants <- function(model, a, b) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  .vp_check_features(model, c(a, b))
  dep_m <- .vp_matrix(model, "requires")
  tibble::tibble(feature = rownames(dep_m)[dep_m[, a] > 0 & dep_m[, b] > 0])
}

#' A feature tree rebuilt from the skeleton
#'
#' A feature tree rebuilt from the skeleton: each feature gets as parent one of
#' the features it requires directly. When there are several candidates, the
#' least required one is chosen, and the others become cross-tree arrows.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with the columns `feature`, `parent` (NA for a feature that
#'   needs nothing), `candidates` (how many features it requires directly) and
#'   `cross_tree` (the candidates that were not chosen, separated by commas).
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_feature_tree(band)
vp_feature_tree <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  skel <- vp_skeleton(model)
  required_by <- Matrix::colSums(m$D)
  rows <- lapply(m$nodes, function(f) {
    p <- skel$to[skel$from == f]
    if (length(p) == 0) {
      return(tibble::tibble(
        feature = f,
        parent = NA_character_,
        candidates = 0L,
        cross_tree = ""
      ))
    }
    best <- p[order(required_by[p], match(p, m$nodes), method = "radix")][1]
    tibble::tibble(
      feature = f,
      parent = best,
      candidates = length(p),
      cross_tree = paste(setdiff(p, best), collapse = ", ")
    )
  })
  .vp_rows(
    rows,
    tibble::tibble(
      feature = character(0),
      parent = character(0),
      candidates = integer(0),
      cross_tree = character(0)
    )
  )
}

# ------------------------------------------------------------- internal helpers

# Level of each node of the merged graph, by one pass in topological order (fast
# even for Linux).
.vp_levels_merged <- function(model) {
  m <- .vp_merged(model)
  g <- m$graph
  # the features that need nothing come first
  order <- rev(as.integer(igraph::topo_sort(g, mode = "out")))
  out <- igraph::as_adj_list(g, mode = "out")
  lv <- integer(length(m$nodes))
  for (v in order) {
    nb <- as.integer(out[[v]])
    lv[v] <- if (length(nb) == 0) 0L else max(lv[nb]) + 1L
  }
  stats::setNames(lv, m$nodes)
}

# Dilworth: a maximum matching in the bipartite graph "f requires g" gives the
# smallest chain cover; Koenig's theorem gives, from the same matching, a
# largest antichain.
.vp_chain_cover <- function(model) {
  m <- .vp_merged(model)
  n <- length(m$nodes)
  if (n == 0) {
    return(list(
      chains = tibble::tibble(
        chain = integer(0),
        position = integer(0),
        feature = character(0)
      ),
      antichain = tibble::tibble(feature = character(0))
    ))
  }
  # i requires j (the merged graph is transitively closed)
  arcs <- Matrix::summary(m$D)
  bip <- igraph::make_bipartite_graph(
    rep(c(FALSE, TRUE), each = n),
    as.vector(rbind(arcs$i, n + arcs$j)),
    directed = FALSE
  )
  # partner of each vertex, NA if unmatched
  mt <- igraph::max_bipartite_match(bip)$matching
  nxt <- mt[seq_len(n)] - n # the next feature in the chain of each one
  prv <- rep(NA_integer_, n)
  prv[nxt[!is.na(nxt)]] <- which(!is.na(nxt))
  starts <- which(is.na(prv))
  chains <- lapply(seq_along(starts), function(k) {
    v <- starts[k]
    path <- v
    while (!is.na(nxt[v])) {
      v <- nxt[v]
      path <- c(path, v)
    }
    tibble::tibble(
      chain = k,
      position = seq_along(path),
      feature = m$nodes[path]
    )
  })
  # Koenig: Z = vertices reachable from unmatched left vertices by alternating
  # paths
  adj <- split(arcs$j, factor(arcs$i, levels = seq_len(n)))
  in_zl <- is.na(nxt)
  in_zr <- rep(FALSE, n)
  queue <- which(in_zl)
  while (length(queue) > 0) {
    u <- queue[1]
    queue <- queue[-1]
    for (r in adj[[u]]) {
      if (!in_zr[r]) {
        in_zr[r] <- TRUE
        l <- prv[r]
        if (!is.na(l) && !in_zl[l]) {
          in_zl[l] <- TRUE
          queue <- c(queue, l)
        }
      }
    }
  }
  list(
    chains = dplyr::bind_rows(chains),
    antichain = tibble::tibble(feature = m$nodes[in_zl & !in_zr])
  )
}

# -------------------------------------------------------- with the feature tree
# The graphs have no tree. When the model has one (a UVL model: read it with
# vp_read_uvl_tree()), these functions compare the two.

#' Optional features that are not really optional
#'
#' False-optional features: optional features that are not really optional. Two
#' definitions are in use: the feature is in every product (Benavides et al.; it
#' is then core), or it is selected whenever its parent is (Nieke et al.; the
#' parent then requires it). The graphs decide both exactly.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param tree The feature tree, from vp_read_uvl_tree().
#' @return A tibble with one row per optional feature that is false-optional by
#'   either definition: `feature`, `parent`, `in_every_product` (first
#'   definition) and `whenever_parent` (second; NA when the parent is not in the
#'   graphs, for example because it is abstract).
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' tree <- vp_read_uvl_tree(vp_example("miband3.uvl"))
#' vp_false_optional(band, tree)
vp_false_optional <- function(model, tree) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  opt <- tree[!is.na(tree$relation) & tree$relation == "optional", ]
  status <- function(f) model$features$status[match(f, model$features$feature)]
  dep_m <- .vp_matrix(model, "requires")
  nodes <- .vp_nodes(model)
  in_every <- status(opt$feature) %in% "core"
  whenever <- vapply(
    seq_len(nrow(opt)),
    function(k) {
      p <- opt$parent[k]
      c <- opt$feature[k]
      if (in_every[k]) {
        return(TRUE)
      }
      if (!(p %in% nodes) || !(c %in% nodes)) {
        return(NA)
      }
      dep_m[p, c] > 0
    },
    NA
  )
  out <- tibble::tibble(
    feature = opt$feature,
    parent = opt$parent,
    in_every_product = in_every,
    whenever_parent = whenever
  )
  out[
    out$in_every_product | (!is.na(out$whenever_parent) & out$whenever_parent),
  ]
}

#' Does the declared tree hide layers of requirements?
#'
#' How far the declared tree is from the meaning. For each feature whose
#' declared parent is in the graphs: does the feature require its parent
#' directly (the parent is one of its direct requirements in the skeleton), or
#' do other features stand in between (it requires something that requires the
#' parent)? Features in between mean that the tree hides a layer of the
#' hierarchy: a "hierarchy violation" by meaning (Berger and Guo).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param tree The feature tree of the model, from [vp_read_uvl_tree()].
#' @return A tibble with `feature`, `parent`, `direct` (TRUE/FALSE) and
#'   `in_between` (the features between them).
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' tree <- vp_read_uvl_tree(vp_example("miband3.uvl"))
#' vp_tree_agreement(band, tree)
vp_tree_agreement <- function(model, tree) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  nodes <- .vp_nodes(model)
  t <- tree[
    !is.na(tree$parent) & tree$feature %in% nodes & tree$parent %in% nodes,
  ]
  # a feature and its parent in one atomic set: nothing to say
  t <- t[m$rep[t$feature] != m$rep[t$parent], ]
  skel <- vp_skeleton(model)
  dep_m <- m$D
  rows <- lapply(seq_len(nrow(t)), function(k) {
    a <- m$rep[[t$feature[k]]]
    p <- m$rep[[t$parent[k]]]
    direct <- any(skel$from == a & skel$to == p)
    mid <- if (direct || dep_m[a, p] == 0) {
      character(0)
    } else {
      m$nodes[dep_m[a, ] > 0 & dep_m[, p] > 0]
    }
    tibble::tibble(
      feature = t$feature[k],
      parent = t$parent[k],
      direct = direct,
      in_between = paste(mid, collapse = ", ")
    )
  })
  if (length(rows) == 0) {
    return(tibble::tibble(
      feature = character(0),
      parent = character(0),
      direct = logical(0),
      in_between = character(0)
    ))
  }
  dplyr::bind_rows(rows)
}

#' Written requirements that follow from others
#'
#' Candidate redundant constraints: written requirements ("a requires b") that
#' follow from a chain of other requirements. Give the constraints of the model
#' that you want to examine; each one that is not in the skeleton is implied by
#' others, and a solver can confirm that removing it changes nothing.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param written A tibble with `from` and `to`: written requirements of the
#'   model.
#' @return The rows of `written` with `in_graphs` (the arrow holds), `redundant`
#'   (it follows from others) and `via`.
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' written <- data.frame(
#'   from = c("TouchScreen", "TouchScreen"),
#'   to = c("Screen", "OLED")
#' )
#' vp_redundant_candidates(band, written)
vp_redundant_candidates <- function(model, written) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  m <- .vp_merged(model)
  dep_m <- m$D
  skel <- vp_skeleton(model)
  nodes <- .vp_nodes(model)
  rows <- lapply(seq_len(nrow(written)), function(k) {
    a <- written$from[k]
    b <- written$to[k]
    if (!(a %in% nodes) || !(b %in% nodes)) {
      return(tibble::tibble(
        from = a,
        to = b,
        in_graphs = NA,
        redundant = NA,
        via = "not both variable features"
      ))
    }
    ra <- m$rep[[a]]
    rb <- m$rep[[b]]
    if (ra == rb) {
      return(tibble::tibble(
        from = a,
        to = b,
        in_graphs = TRUE,
        redundant = FALSE,
        via = "same atomic set"
      ))
    }
    held <- dep_m[ra, rb] > 0
    red <- held && !any(skel$from == ra & skel$to == rb)
    via <- if (red) m$nodes[dep_m[ra, ] > 0 & dep_m[, rb] > 0][1] else ""
    tibble::tibble(
      from = a,
      to = b,
      in_graphs = held,
      redundant = red,
      via = via
    )
  })
  dplyr::bind_rows(rows)
}

# ---------------------------------------------------------- beyond requirements
# Depth and width read the requires graph only. These two functions are their
# counterparts with the three graphs.

#' The most features that are pairwise free (all three graphs)
#'
#' The largest set of features that are pairwise free: for every two of them,
#' the four combinations (both, only one, only the other, neither) all occur in
#' valid products. The width counts features none of which requires another;
#' this set also excludes conflicts and at-least-one lines, so it is the number
#' of truly independent decisions, as far as pairs go.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param exact_limit Up to this number of variable features the search is
#'   exact; above it, a greedy search gives a large free set, and the largest
#'   one may be larger.
#' @return A tibble with the column `feature`.
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_largest_free_set(band)
vp_largest_free_set <- function(model, exact_limit = 60) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  vars <- .vp_nodes(model)
  if (length(vars) == 0) {
    return(tibble::tibble(feature = character(0)))
  }
  links <- dplyr::bind_rows(model$requires, model$excludes, model$atleastone)
  g <- igraph::simplify(igraph::graph_from_data_frame(
    links,
    directed = FALSE,
    vertices = vars
  ))
  if (length(vars) <= exact_limit) {
    return(tibble::tibble(
      feature = igraph::V(g)$name[as.integer(igraph::largest_ivs(g)[[1]])]
    ))
  }
  message(
    "More than ",
    exact_limit,
    " features: greedy search; the largest free set may be larger."
  )
  left <- seq_along(vars)
  chosen <- integer(0)
  adj <- igraph::as_adj_list(g)
  deg <- igraph::degree(g)
  while (length(left) > 0) {
    v <- left[which.min(deg[left])]
    chosen <- c(chosen, v)
    left <- setdiff(left, c(v, as.integer(adj[[v]])))
  }
  tibble::tibble(feature = vars[chosen])
}

#' The longest chain of forced decisions (all three graphs)
#'
#' The longest chain of decisions: each decision forces the next, by a
#' requirement, a conflict or an at-least-one line (the modal implication graph
#' of vp_mig()). Decisions that force each other count as one step (for example
#' "Screen left out" and "BT40 selected", which are opposites). It is the
#' counterpart of the depth with the three graphs: how long the longest
#' explanation of a forced decision can get, conflicts included.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `step` and `decisions` (the decisions of the step,
#'   written "A" for "A selected" and "not A" for "A left out", joined by " = "
#'   when they force each other). Its number of rows is the length of the chain;
#'   like the depth, it counts decisions, so a model whose features are all free
#'   has a chain of one.
#' @family hierarchy
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_longest_decision_chain(band)
vp_longest_decision_chain <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  # complete: every implication is an arrow
  dg <- suppressWarnings(vp_mig(model))
  if (nrow(dg) == 0) {
    # no decision forces another: any single decision is a chain
    vars <- .vp_nodes(model)
    return(tibble::tibble(
      step = seq_len(min(1, length(vars))),
      decisions = utils::head(vars, 1)
    ))
  }
  key <- function(f, v) paste0(ifelse(v, "", "not "), f)
  e <- unique(data.frame(
    from = key(dg$from, dg$from_selected),
    to = key(dg$to, dg$to_selected)
  ))
  g <- igraph::graph_from_data_frame(e)
  comp <- igraph::components(g, mode = "strong")
  q <- igraph::simplify(igraph::contract(
    g,
    comp$membership,
    vertex.attr.comb = list(name = function(x) {
      paste(.vp_sort(x), collapse = " = ")
    })
  ))
  alo_m <- igraph::as_adjacency_matrix(q, sparse = TRUE)
  alo_m@x[] <- 1
  adj_2 <- alo_m %*% alo_m
  adj_2@x[] <- 1
  # the immediate implications (the graph of decisions is complete)
  imm <- Matrix::drop0(alo_m - alo_m * adj_2)
  r <- igraph::graph_from_adjacency_matrix(imm, mode = "directed")
  ord <- rev(as.integer(igraph::topo_sort(r, mode = "out")))
  out <- igraph::as_adj_list(r, mode = "out")
  len <- integer(igraph::vcount(r))
  nxt <- rep(NA_integer_, igraph::vcount(r))
  for (v in ord) {
    nb <- as.integer(out[[v]])
    if (length(nb)) {
      k <- nb[which.max(len[nb])]
      len[v] <- len[k] + 1L
      nxt[v] <- k
    }
  }
  v <- which.max(len)
  path <- v
  while (!is.na(nxt[v])) {
    v <- nxt[v]
    path <- c(path, v)
  }
  tibble::tibble(step = seq_along(path), decisions = igraph::V(r)$name[path])
}
