# ==============================================================================
# Topic 2. Measuring each feature
#
# One row per feature, one column per measure: how many features need it, how
# many it needs, how many it excludes, how much of the model selecting it
# decides, where it sits in the hierarchy, and whether it is a gateway through
# which requirements pass. The table is a tibble, so dplyr::arrange(), filter()
# and ggplot2 work on it directly.
#
# Every count comes from the graphs, so it counts relationships between two
# features. A feature constrained only by a rule over three or more features
# (such as "A needs B or C") gets zeros where the rule would add something.
# ==============================================================================

#' Every measure of every feature, one row each
#'
#' A table of measures, one row per variable feature.
#'
#' The counts (required_by, requires, excludes, atleastone, isolated) read the
#' graphs of the model as they are: on the minimal form (vp_minimal()) they
#' count direct links only. Decision power and the positions in the hierarchy
#' are inferences and always use the complete graphs.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with the columns:
#'
#' * `feature`: the name
#' * `required_by`: how many features require it (its sensitivity: the size of
#'   its impact set)
#' * `requires`: how many features it requires
#' * `excludes`: how many features it excludes (its conflict degree)
#' * `atleastone`: how many features it is joined to in the at-least-one graph
#'   (NA without or_graph = TRUE)
#' * `decision_power`: the share of the other features that selecting it
#'   decides: (requires + excludes) / (n - 1)
#' * `decision_power_off`: the same for leaving it out: (required_by +
#'   atleastone) / (n - 1) (NA without or_graph = TRUE)
#' * `level`: its level in the hierarchy (0: it needs nothing)
#' * `direct_required_by`, `direct_requires`: the same counts in the skeleton
#'   (written arrows, roughly)
#' * `betweenness`: on the skeleton: how many chains of requirements pass
#'   through it (gateways)
#' * `closeness_out`: on the skeleton: 1 / average number of steps to what it
#'   requires (NA if it requires nothing)
#' * `closeness_in`: on the skeleton: 1 / average number of steps from what
#'   requires it (NA if nothing does)
#' * `harmonic`: on the skeleton: the sum of 1 / steps to each feature it
#'   requires (0 if none); unlike closeness, it also grows with how many
#'   features it requires
#' * `atomic_set`: the representative of its atomic set, or NA
#' * `isolated`: TRUE when it is in no graph at all
#' @family features
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_feature_table(band)
vp_feature_table <- function(model) {
  nodes <- .vp_nodes(model)
  n <- length(nodes)
  dep_m <- .vp_matrix(model, "requires")
  conf_m <- .vp_matrix(model, "excludes")
  has_alo <- !is.null(model$atleastone)
  alo_m <- if (has_alo) .vp_matrix(model, "atleastone") else NULL
  required_by <- Matrix::colSums(dep_m)
  requires <- Matrix::rowSums(dep_m)
  excludes <- Matrix::rowSums(conf_m)
  alo <- if (has_alo) Matrix::rowSums(alo_m) else rep(NA_real_, n)

  comp <- .vp_complete(model) # decision power and positions are inferences
  dep_c <- .vp_matrix(comp, "requires")
  conf_c <- .vp_matrix(comp, "excludes")
  m <- .vp_merged(comp)
  skel <- vp_skeleton(comp)
  skel_g <- igraph::graph_from_data_frame(
    skel,
    directed = TRUE,
    vertices = m$nodes
  )
  rep <- stats::setNames(nodes, nodes)
  rc <- .vp_representative(comp)
  rep[intersect(names(rc), nodes)] <- rc[intersect(names(rc), nodes)]
  lv <- .vp_levels_merged(comp)
  btw <- igraph::betweenness(skel_g, directed = TRUE)
  clo <- suppressWarnings(igraph::closeness(
    skel_g,
    mode = "out",
    normalized = TRUE
  ))
  clo[igraph::degree(skel_g, mode = "out") == 0] <- NA
  clo_in <- suppressWarnings(igraph::closeness(
    skel_g,
    mode = "in",
    normalized = TRUE
  ))
  clo_in[igraph::degree(skel_g, mode = "in") == 0] <- NA
  harm <- igraph::harmonic_centrality(skel_g, mode = "out")
  sk_in <- igraph::degree(skel_g, mode = "in")
  sk_out <- igraph::degree(skel_g, mode = "out")

  atomic <- vp_atomic_sets(comp)
  power <- if (n > 1) {
    (Matrix::rowSums(dep_c) + Matrix::rowSums(conf_c))[nodes] /
      (length(.vp_nodes(comp)) - 1)
  } else {
    0
  }
  power_off <- if (has_alo && n > 1) {
    (Matrix::colSums(dep_c) + Matrix::rowSums(.vp_matrix(comp, "atleastone")))[
      nodes
    ] /
      (length(.vp_nodes(comp)) - 1)
  } else {
    NA_real_
  }
  values <- list(
    feature = nodes,
    required_by = as.integer(required_by),
    requires = as.integer(requires),
    excludes = as.integer(excludes),
    atleastone = as.integer(alo),
    decision_power = unname(power),
    decision_power_off = unname(power_off),
    level = unname(lv[rep[nodes]]),
    direct_required_by = as.integer(unname(sk_in[rep[nodes]])),
    direct_requires = as.integer(unname(sk_out[rep[nodes]])),
    betweenness = unname(btw[rep[nodes]]),
    closeness_out = unname(clo[rep[nodes]]),
    closeness_in = unname(clo_in[rep[nodes]]),
    harmonic = unname(harm[rep[nodes]]),
    atomic_set = atomic$representative[match(nodes, atomic$feature)],
    isolated = required_by + requires + excludes + (if (has_alo) alo else 0) ==
      0
  )
  tibble::as_tibble(values)
}

#' What requires a feature (its impact set)
#'
#' The features that require a given feature: its impact set. Changing or
#' removing the feature affects all of them.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param feature The name of a variable feature of the model.
#' @return A tibble with the column `feature`.
#' @family features
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_required_by(band, "Screen")
vp_required_by <- function(model, feature) {
  .vp_check_features(model, feature)
  dep_m <- .vp_matrix(model, "requires")
  tibble::tibble(feature = rownames(dep_m)[dep_m[, feature] > 0])
}

#' What a feature requires
#'
#' The features that a given feature requires: selecting it selects all of them.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param feature The name of a variable feature of the model.
#' @return A tibble with the column `feature`.
#' @family features
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_requirements(band, "TouchScreen")
vp_requirements <- function(model, feature) {
  .vp_check_features(model, feature)
  dep_m <- .vp_matrix(model, "requires")
  tibble::tibble(feature = colnames(dep_m)[dep_m[feature, ] > 0])
}

#' What a feature excludes
#'
#' The features that a given feature excludes: selecting it rules all of them
#' out.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param feature The name of a variable feature of the model.
#' @return A tibble with the column `feature`.
#' @family features
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_conflicts_of(band, "BT40")
vp_conflicts_of <- function(model, feature) {
  .vp_check_features(model, feature)
  conf_m <- .vp_matrix(model, "excludes")
  tibble::tibble(feature = colnames(conf_m)[conf_m[feature, ] > 0])
}

#' What leaving a feature out forces
#'
#' The features joined to a given feature in the at-least-one graph: leaving it
#' out forces all of them in.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param feature The name of a variable feature of the model.
#' @return A tibble with the column `feature`.
#' @family features
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_atleastone_of(band, "BT40")
vp_atleastone_of <- function(model, feature) {
  .vp_check_features(model, feature)
  if (is.null(model$atleastone)) {
    stop(.vp_no_alo(model), call. = FALSE)
  }
  alo_m <- .vp_matrix(model, "atleastone")
  tibble::tibble(feature = colnames(alo_m)[alo_m[feature, ] > 0])
}

#' The most required features, and whether that is their own merit
#'
#' Genuine hubs: the features that many others require in their own right, not
#' only because they sit below another feature that gathers their dependants. A
#' feature p dominates a feature q (Abate et al.'s strong dominance) when p
#' requires q and nearly all the other features that require q also require p:
#' then almost every dependant of q reaches q through p, and the importance of q
#' is borrowed from p. A hub that no feature dominates is genuine.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param top How many of the most required features to look at.
#' @param share What "nearly all" means: the share of the other dependants of q
#'   that must also require p (0.9 by default).
#' @return A tibble with `feature`, `required_by`, `dominated_by` (NA for a
#'   genuine hub), `share_through` (the share of the other dependants of the
#'   feature that also require its dominator; NA for a genuine hub) and
#'   `genuine`.
#' @family features
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_genuine_hubs(band, top = 5)
vp_genuine_hubs <- function(model, top = 10, share = 0.9) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  # On the merged graph: the members of an atomic set are one feature, so they
  # cannot dominate one another.
  m <- .vp_merged(model)
  dep_m <- m$D
  required_by <- Matrix::colSums(dep_m)
  k <- min(top, sum(required_by > 0))
  cand <- names(.vp_sort(
    required_by[required_by > 0],
    decreasing = TRUE
  ))[seq_len(k)]
  best <- lapply(cand, function(q) {
    users <- rownames(dep_m)[dep_m[, q] > 0] # what requires q
    through <- vapply(
      users,
      function(p) {
        # for each of them, the share of the others that also require it
        others <- setdiff(users, p)
        if (length(others) == 0) {
          1
        } else {
          sum(dep_m[others, p] > 0) / length(others)
        }
      },
      0
    )
    ok <- users[through >= share]
    if (!length(ok)) {
      return(list(p = NA_character_, s = NA_real_))
    }
    # the one that gathers the most
    p <- ok[order(-through[ok], -required_by[ok], method = "radix")][1]
    list(p = p, s = unname(through[p]))
  })
  tibble::tibble(
    feature = cand,
    required_by = as.integer(required_by[cand]),
    dominated_by = vapply(best, `[[`, "", "p"),
    share_through = vapply(best, `[[`, 0, "s"),
    genuine = is.na(vapply(best, `[[`, "", "p"))
  )
}

#' Features both highly required and highly dependent
#'
#' The warning zone: features that are among the most required and, at the same
#' time, among those that require most. Many things break when they change, and
#' many things can break them.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param top The share of features that counts as "among the most" (0.1: the
#'   top tenth).
#' @return The rows of vp_feature_table() of the features in the zone.
#' @family features
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_warning_zone(band, top = 0.3)
vp_warning_zone <- function(model, top = 0.1) {
  t <- vp_feature_table(model)
  hi <- function(x) x >= stats::quantile(x, 1 - top, names = FALSE) & x > 0
  t[hi(t$required_by) & hi(t$requires), ]
}
