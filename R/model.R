# ==============================================================================
# Topic 4. The whole model in numbers
#
# One row of numbers per model: its size, how much of it is implicit (follows
# from other relationships), how dense it is, how deep and wide its hierarchy
# is, how concentrated its hubs are, and how much a selection decides. Rows of
# several models stack into one tibble, which makes models easy to compare.
#
# Every number describes the graphs, that is, the relationships between two
# features. A rule over three or more features changes none of them unless it
# implies a relationship between two.
# ==============================================================================

#' One row of numbers per model
#'
#' One row of numbers that describe a model. Give one model, or several (they
#' are stacked, one row each).
#'
#' The counts, densities, concentrations, isolated and coupling read the graphs
#' as they are given (on the minimal form, vp_minimal(), they describe the
#' written structure); the other numbers are inferences and use the complete
#' graphs.
#'
#' @param ... One or more models (from vp_read). Named arguments give the column
#'   `model` its values.
#' @return A tibble with one row per model and the columns model, features
#'   (variable), core, dead, atomic_sets, requires, excludes, atleastone (NA
#'   without or_graph = TRUE), skeleton (arrows), primitive_conflicts,
#'   implicit_requires (share of arrows that follow from others),
#'   implicit_excludes (share of conflicts that are inherited),
#'   density_requires, density_excludes, depth, width, cross_tree_share,
#'   hierarchy_share, gini_required_by, gini_excludes, mean_decision_power,
#'   isolated (features in no graph), coupling (share of features with at least
#'   one strong relationship), skeleton_per_feature (links of the skeleton per
#'   node: density by meaning), largest_atomic_set (the size of the largest
#'   group of mutually dependent features, Baldwin et al.'s "core"),
#'   largest_alternative_group, representativeness (the share of
#'   vp_representativeness(), NA when the run did not measure it).
#' @family whole model
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"))
#' axtls <- vp_generate(vp_example("axTLS.uvl"))
#' vp_summary(band = band, axTLS = axtls)
vp_summary <- function(...) {
  models <- list(...)
  if (
    length(models) == 1 &&
      is.list(models[[1]]) &&
      !inherits(models[[1]], "vp_model")
  ) {
    models <- models[[1]]
  }
  labels <- names(models)
  if (is.null(labels)) {
    labels <- rep("", length(models))
  }
  rows <- lapply(seq_along(models), function(k) {
    r <- .vp_summary_one(models[[k]])
    if (nzchar(labels[k])) {
      r$model <- labels[k]
    }
    r
  })
  dplyr::bind_rows(rows)
}

#' Are the files consistent?
#'
#' Check that the files are consistent: the properties that the graphs of any
#' model must have. A FALSE means that the files are incomplete or were damaged
#' (for example, filtered by hand in one graph and not in the other).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with one row per property: `property`, `holds` (TRUE/FALSE)
#'   and `violations` (how many cases break it).
#' @family whole model
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_check(band)
vp_check <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  dep_m <- .vp_matrix(model, "requires")
  conf_m <- .vp_matrix(model, "excludes")
  pos <- function(mat) {
    mat <- Matrix::drop0(methods::as(mat, "generalMatrix"))
    mat@x[] <- 1
    mat
  }
  offdiag <- function(mat) {
    mat <- methods::as(mat, "generalMatrix")
    Matrix::diag(mat) <- 0
    Matrix::drop0(mat)
  }
  count_missing <- function(implied, present) {
    sum(pos(offdiag(implied)) * (1 - present) > 0)
  }
  chain <- count_missing(dep_m %*% dep_m, dep_m)
  inher <- count_missing(dep_m %*% conf_m, conf_m)
  # f requires g and h, and g excludes h
  dead <- sum(pos(dep_m %*% conf_m) * dep_m > 0)
  # a pair that is both a requirement and a conflict
  both <- sum(dep_m * conf_m > 0)
  rows <- tibble::tibble(
    property = c(
      "requires is complete: A -> B and B -> C give A -> C",
      "conflicts are inherited: A -> B and B excludes C give A excludes C",
      "no feature requires two features that exclude each other",
      "no pair both requires and excludes"
    ),
    violations = c(chain, inher, dead, both)
  )
  if (!is.null(model$atleastone)) {
    alo_m <- .vp_matrix(model, "atleastone")
    up <- count_missing(alo_m %*% dep_m, alo_m)
    der <- count_missing(conf_m %*% alo_m, dep_m)
    rows <- dplyr::bind_rows(
      rows,
      tibble::tibble(
        property = c(
          "at-least-one is inherited upwards: A or B, and B -> C give A or C",
          "A excludes B and (B or C) give A -> C"
        ),
        violations = c(up, der)
      )
    )
  }
  rows$holds <- rows$violations == 0
  rows[, c("property", "holds", "violations")]
}

#' How many features have each degree
#'
#' How many features have each degree in one graph: the data of a
#' degree-distribution plot.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param graph "requires", "excludes", "atleastone" or "skeleton".
#' @param direction For requires and skeleton: "in" (how many require the
#'   feature) or "out" (how many it requires).
#' @return A tibble with `degree` and `features` (how many features have that
#'   degree).
#' @family whole model
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_degree_distribution(band, "requires", "in")
vp_degree_distribution <- function(
  model,
  graph = c("requires", "excludes", "atleastone", "skeleton"),
  direction = c("in", "out")
) {
  graph <- match.arg(graph)
  direction <- match.arg(direction)
  deg <- if (graph == "skeleton") {
    m <- .vp_merged(model)
    skel <- vp_skeleton(model)
    tabulate(
      match(if (direction == "in") skel$to else skel$from, m$nodes),
      length(m$nodes)
    )
  } else {
    mat <- .vp_matrix(model, graph)
    if (graph == "requires" && direction == "in") {
      Matrix::colSums(mat)
    } else {
      Matrix::rowSums(mat)
    }
  }
  t <- as.data.frame(table(deg = as.integer(deg)), stringsAsFactors = FALSE)
  tibble::tibble(degree = as.integer(t$deg), features = as.integer(t$Freq))
}

#' How unevenly a quantity is spread
#'
#' The Gini coefficient of a vector of numbers: 0 when all are equal, close to 1
#' when one holds almost everything.
#'
#' @param x A numeric vector.
#' @return A number between 0 and 1.
#' @family whole model
#' @export
#' @examples
#' vp_gini(c(1, 1, 1, 1))
#' vp_gini(c(0, 0, 0, 10))
vp_gini <- function(x) {
  x <- .vp_sort(x)
  k <- length(x)
  if (k == 0 || sum(x) == 0) {
    return(0)
  }
  sum((2 * seq_len(k) - k - 1) * x) / (k * sum(x))
}

# ------------------------------------------------------------- internal helpers
.vp_summary_one <- function(x) {
  # every value is computed first: inside tibble() a column such as `requires`
  # would hide a variable of that name
  comp <- .vp_complete(x) # the structural numbers are inferences
  nodes <- .vp_nodes(x)
  n <- length(nodes)
  m <- .vp_merged(comp)
  st <- table(factor(x$features$status, levels = c("variable", "core", "dead")))
  skel <- vp_skeleton(comp)
  prim <- vp_primitive_conflicts(comp)
  dep_c <- .vp_matrix(comp, "requires")
  conf_c <- .vp_matrix(comp, "excludes")
  nc <- length(.vp_nodes(comp))
  dep_m <- .vp_matrix(x, "requires")
  conf_m <- .vp_matrix(x, "excludes")
  in_deg <- Matrix::colSums(dep_m)
  out_deg <- Matrix::rowSums(dep_m)
  conf_deg <- Matrix::rowSums(conf_m)
  roots <- sum(Matrix::rowSums(m$D) == 0)
  has_alo <- !is.null(x$atleastone)
  alo_deg <- if (has_alo) Matrix::rowSums(.vp_matrix(x, "atleastone")) else 0
  values <- list(
    model = x$name,
    form = if (identical(x$form, "minimal")) "minimal" else "complete",
    features = n,
    core = as.integer(st[["core"]]),
    dead = as.integer(st[["dead"]]),
    atomic_sets = length(unique(comp$atomic$set)),
    requires = nrow(x$requires),
    excludes = nrow(x$excludes),
    atleastone = if (has_alo) nrow(x$atleastone) else NA_integer_,
    skeleton = nrow(skel),
    primitive_conflicts = nrow(prim),
    implicit_requires = if (nrow(m$requires) > 0) {
      1 - nrow(skel) / nrow(m$requires)
    } else {
      0
    },
    implicit_excludes = if (nrow(m$excludes) > 0) {
      1 - nrow(prim) / nrow(m$excludes)
    } else {
      0
    },
    density_requires = if (n > 1) nrow(x$requires) / (n * (n - 1)) else 0,
    density_excludes = if (n > 1) nrow(x$excludes) / (n * (n - 1) / 2) else 0,
    depth = vp_depth(comp),
    width = vp_width(comp),
    cross_tree_share = if (nrow(skel) > 0) {
      1 - (length(m$nodes) - roots) / nrow(skel)
    } else {
      0
    },
    hierarchy_share = if (length(m$nodes) > 1) {
      nrow(m$requires) / choose(length(m$nodes), 2)
    } else {
      0
    },
    gini_required_by = vp_gini(in_deg),
    gini_excludes = vp_gini(conf_deg),
    mean_decision_power = if (nc > 1) {
      mean((Matrix::rowSums(dep_c) + Matrix::rowSums(conf_c)) / (nc - 1))
    } else {
      0
    },
    isolated = sum(in_deg + out_deg + conf_deg + alo_deg == 0),
    coupling = if (n > 0) {
      mean(in_deg + out_deg + conf_deg + alo_deg > 0)
    } else {
      0
    },
    skeleton_per_feature = if (length(m$nodes) > 0) {
      nrow(skel) / length(m$nodes)
    } else {
      0
    },
    largest_atomic_set = if (nrow(comp$atomic) > 0) {
      max(table(comp$atomic$set))
    } else {
      1L
    },
    largest_alternative_group = if (nrow(comp$excludes) > 0) {
      igraph::clique_num(vp_igraph(comp, "excludes"))
    } else {
      1L
    },
    representativeness = vp_representativeness(x)$share
  )
  tibble::as_tibble(values)
}
