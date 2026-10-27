# ==============================================================================
# Topic 9. Following a model through time
#
# A product line lives for years, and each version of its model is a run of
# Strong4VM. Read the runs with vp_read_history() (oldest first) and this file
# compares them: what changed between two versions, how the model grew, where
# new features attach, whether the hubs stay the same, which steps were
# disruptions, how long new links last, how features move between variable,
# core, dead and absent, and how well the next version can be predicted.
#
# Features are matched by name, so a renamed feature looks like one removed and
# one added. Links are compared only among the features that are variable in
# both versions (the "kept" ones), as `strong4vm diff` does.
#
# LIMITS. Everything here compares relationships between two features. A change
# that only touches a rule over three or more features leaves every graph as it
# was, so it is invisible (user manual, "diff cannot see it either").
# ==============================================================================

#' What changed between two versions
#'
#' What changed between two versions: one row per graph, as the command
#' `strong4vm diff` reports it.
#'
#' @param old The older version of a model (from [vp_generate()] or
#'   [vp_read()]).
#' @param new The newer version of the same model.
#' @return A tibble with `graph`, `kept`, `added`, `removed` (variable
#'   features), `old_links` and `new_links` (among the kept features), `gained`,
#'   `lost`, `jaccard` (links in both / links in either; 1 when nothing changed)
#'   and `spearman` (for requires: how alike the order of the kept features by
#'   in-degree is; NA for the others).
#' @family evolution
#' @export
#' @examples
#' old <- vp_generate(vp_example("miband3_planned.uvl"), or_graph = TRUE)
#' new <- vp_generate(vp_example("miband3_realized.uvl"), or_graph = TRUE)
#' vp_compare(old, new)
vp_compare <- function(old, new) {
  kept <- intersect(.vp_nodes(old), .vp_nodes(new))
  graphs <- c(
    "requires",
    "excludes",
    if (!is.null(old$atleastone) && !is.null(new$atleastone)) "atleastone"
  )
  rows <- lapply(graphs, function(g) {
    a <- .vp_keys(old, g, kept)
    b <- .vp_keys(new, g, kept)
    both <- length(intersect(a, b))
    either <- length(union(a, b))
    rho <- if (g == "requires") .vp_spearman_in(old, new, kept) else NA_real_
    tibble::tibble(
      graph = g,
      kept = length(kept),
      added = length(setdiff(.vp_nodes(new), .vp_nodes(old))),
      removed = length(setdiff(.vp_nodes(old), .vp_nodes(new))),
      old_links = length(a),
      new_links = length(b),
      gained = length(setdiff(b, a)),
      lost = length(setdiff(a, b)),
      jaccard = if (either == 0) 1 else both / either,
      spearman = rho
    )
  })
  dplyr::bind_rows(rows)
}

#' The links gained and lost
#'
#' The links that changed between two versions, among the kept features.
#'
#' @param old The older version of a model (from [vp_generate()] or
#'   [vp_read()]).
#' @param new The newer version of the same model.
#' @param graph Which graph: `"requires"`, `"excludes"` or `"atleastone"` (the
#'   last one needs `or_graph = TRUE` in [vp_generate()]).
#' @return A tibble with `from`, `to` and `change` ("gained" or "lost").
#' @family evolution
#' @export
#' @examples
#' old <- vp_generate(vp_example("miband3_planned.uvl"), or_graph = TRUE)
#' new <- vp_generate(vp_example("miband3_realized.uvl"), or_graph = TRUE)
#' vp_changed_links(old, new, "requires")
vp_changed_links <- function(
  old,
  new,
  graph = c("requires", "excludes", "atleastone")
) {
  graph <- match.arg(graph)
  kept <- intersect(.vp_nodes(old), .vp_nodes(new))
  a <- .vp_keys(old, graph, kept)
  b <- .vp_keys(new, graph, kept)
  g <- c(setdiff(b, a), setdiff(a, b))
  p <- strsplit(g, "\t", fixed = TRUE)
  tibble::tibble(
    from = vapply(p, `[`, "", 1),
    to = vapply(p, `[`, "", 2),
    change = rep(
      c("gained", "lost"),
      c(length(setdiff(b, a)), length(setdiff(a, b)))
    )
  )
}

#' The features whose links changed most
#'
#' The features whose links changed most between two versions: where to start
#' explaining a big change.
#'
#' @param old The older version of a model (from [vp_generate()] or
#'   [vp_read()]).
#' @param new The newer version of the same model.
#' @param graph Which graph: `"requires"`, `"excludes"` or `"atleastone"` (the
#'   last one needs `or_graph = TRUE` in [vp_generate()]).
#' @param n How many rows to return.
#' @return A tibble with `feature`, `gained`, `lost` and `total`, the largest
#'   changes first.
#' @family evolution
#' @export
#' @examples
#' old <- vp_generate(vp_example("miband3_planned.uvl"), or_graph = TRUE)
#' new <- vp_generate(vp_example("miband3_realized.uvl"), or_graph = TRUE)
#' vp_top_movers(old, new, "excludes", n = 5)
vp_top_movers <- function(
  old,
  new,
  graph = c("requires", "excludes", "atleastone"),
  n = 10
) {
  ch <- vp_changed_links(old, new, match.arg(graph))
  long <- tibble::tibble(
    feature = c(ch$from, ch$to),
    change = c(ch$change, ch$change)
  )
  if (nrow(long) == 0) {
    return(tibble::tibble(
      feature = character(0),
      gained = integer(0),
      lost = integer(0),
      total = integer(0)
    ))
  }
  t <- as.data.frame.matrix(table(
    long$feature,
    factor(long$change, levels = c("gained", "lost"))
  ))
  out <- tibble::tibble(
    feature = rownames(t),
    gained = as.integer(t$gained),
    lost = as.integer(t$lost)
  )
  out$total <- out$gained + out$lost
  utils::head(out[order(-out$total, method = "radix"), ], n)
}

#' Features that appeared, disappeared or changed status
#'
#' Features that appeared, disappeared or changed status between two versions.
#'
#' @param old The older version of a model (from [vp_generate()] or
#'   [vp_read()]).
#' @param new The newer version of the same model.
#' @return A tibble with `feature`, `before` and `after`, each "variable",
#'   "core", "dead" or "absent".
#' @family evolution
#' @export
#' @examples
#' old <- vp_generate(vp_example("miband3_planned.uvl"), or_graph = TRUE)
#' new <- vp_generate(vp_example("miband3_realized.uvl"), or_graph = TRUE)
#' vp_state_moves(old, new)
vp_state_moves <- function(old, new) {
  f <- union(old$features$feature, new$features$feature)
  st <- function(m) {
    s <- m$features$status[match(f, m$features$feature)]
    as.character(ifelse(is.na(s), "absent", s))
  }
  out <- tibble::tibble(feature = f, before = st(old), after = st(new))
  out[out$before != out$after, ]
}

#' The state of every feature in every version
#'
#' The state of every feature in every version, in long format (one row per
#' feature and version).
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @return A tibble with `version`, `feature` and `state` ("variable", "core",
#'   "dead" or "absent").
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_feature_states(history)
vp_feature_states <- function(history) {
  f <- unique(unlist(lapply(history$model, function(m) m$features$feature)))
  dplyr::bind_rows(lapply(seq_len(nrow(history)), function(k) {
    m <- history$model[[k]]
    s <- m$features$status[match(f, m$features$feature)]
    tibble::tibble(
      version = history$version[k],
      feature = f,
      state = as.character(ifelse(is.na(s), "absent", s))
    )
  }))
}

#' The size of every version
#'
#' The size of every version of a history.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @return A tibble with `version`, `features`, `core`, `dead`, `requires`,
#'   `excludes`, `atleastone`, `skeleton`, `primitive_conflicts`, `depth`,
#'   `implicit_requires` and `implicit_excludes`.
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_history_sizes(history)
vp_history_sizes <- function(history) {
  dplyr::bind_rows(lapply(seq_len(nrow(history)), function(k) {
    m <- history$model[[k]]
    st <- table(factor(
      m$features$status,
      levels = c("variable", "core", "dead")
    ))
    mm <- .vp_merged(.vp_complete(m))
    skel <- nrow(vp_skeleton(m))
    prim <- nrow(vp_primitive_conflicts(m))
    tibble::tibble(
      version = history$version[k],
      features = as.integer(st[["variable"]]),
      core = as.integer(st[["core"]]),
      dead = as.integer(st[["dead"]]),
      requires = nrow(m$requires),
      excludes = nrow(m$excludes),
      atleastone = if (is.null(m$atleastone)) {
        NA_integer_
      } else {
        nrow(m$atleastone)
      },
      skeleton = skel,
      primitive_conflicts = prim,
      depth = vp_depth(m),
      implicit_requires = if (nrow(mm$requires)) {
        1 - skel / nrow(mm$requires)
      } else {
        0
      },
      implicit_excludes = if (nrow(mm$excludes)) {
        1 - prim / nrow(mm$excludes)
      } else {
        0
      }
    )
  }))
}

#' What changed at every step
#'
#' What changed at every step of a history (each version against the one
#' before).
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @return The rows of vp_compare() for every step, with the columns `from` and
#'   `to` (the two versions) in front.
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_history_changes(history)
vp_history_changes <- function(history) {
  .vp_rows(
    lapply(seq_len(nrow(history) - 1), function(k) {
      r <- vp_compare(history$model[[k]], history$model[[k + 1]])
      tibble::tibble(
        step = k,
        from = history$version[k],
        to = history$version[k + 1],
        r
      )
    }),
    tibble::tibble(
      step = integer(0),
      from = history$version[0],
      to = history$version[0],
      graph = character(0),
      kept = integer(0),
      added = integer(0),
      removed = integer(0),
      old_links = integer(0),
      new_links = integer(0),
      gained = integer(0),
      lost = integer(0),
      jaccard = numeric(0),
      spearman = numeric(0)
    )
  )
}

#' How fast links grow with features
#'
#' Growth laws: how fast each kind of link grows with the number of features. A
#' straight line is fitted to log(links) against log(features); its slope is 1
#' when links grow in step with features, above 1 when faster. Versions with no
#' features, or with none of the links of a kind, are left out of that kind
#' (log(0) does not exist).
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @return A tibble with `links` (the kind), `slope` and `r_squared` (how well a
#'   straight line fits; 1 is perfect); both NA for a kind with fewer than three
#'   versions left.
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_growth(history)
vp_growth <- function(history) {
  s <- vp_history_sizes(history)
  kinds <- c("requires", "excludes", "skeleton", "primitive_conflicts")
  dplyr::bind_rows(lapply(kinds, function(k) {
    ok <- s[[k]] > 0 & s$features > 0
    if (sum(ok) < 3) {
      return(tibble::tibble(links = k, slope = NA_real_, r_squared = NA_real_))
    }
    fit <- stats::lm(log(s[[k]][ok]) ~ log(s$features[ok]))
    tibble::tibble(
      links = k,
      slope = unname(stats::coef(fit)[2]),
      r_squared = suppressWarnings(summary(fit)$r.squared)
    ) # a perfect fit warns, but 1 is the answer
  }))
}

#' Where new features attach
#'
#' Where new features attach: for each step and each kept feature, how many
#' direct dependants it had (in the skeleton) and how many of the new features
#' require it directly in the new version.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @return A tibble with `step`, `version` (the new one), `feature`,
#'   `direct_dependants` and `new_dependants`.
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_attachment(history)
vp_attachment <- function(history) {
  .vp_rows(
    lapply(seq_len(nrow(history) - 1), function(k) {
      a <- history$model[[k]]
      b <- history$model[[k + 1]]
      kept <- intersect(.vp_nodes(a), .vp_nodes(b))
      newf <- setdiff(.vp_nodes(b), .vp_nodes(a))
      ra <- .vp_representative(a)
      rb <- .vp_representative(b)
      skel_a <- vp_skeleton(a)
      skel_b <- vp_skeleton(b)
      before <- table(factor(skel_a$to, levels = unique(ra)))
      newreps <- unique(rb[newf])
      hits <- skel_b[skel_b$from %in% newreps, ]
      gain <- table(factor(hits$to, levels = unique(rb)))
      tibble::tibble(
        step = k,
        version = history$version[k + 1],
        feature = kept,
        direct_dependants = as.integer(before[ra[kept]]),
        new_dependants = as.integer(gain[rb[kept]])
      )
    }),
    tibble::tibble(
      step = integer(0),
      version = history$version[0],
      feature = character(0),
      direct_dependants = integer(0),
      new_dependants = integer(0)
    )
  )
}

#' Are the hubs the same from version to version?
#'
#' Are the hubs the same from one version to the next? For each step: the rank
#' correlation of how many features require each kept feature, and how many of
#' the `top` most required stay among the `top` most required.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param top How many of the most required features count as hubs.
#' @return A tibble with `step`, `from`, `to`, `spearman` and `top_kept`.
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_hub_stability(history, top = 5)
vp_hub_stability <- function(history, top = 50) {
  .vp_rows(
    lapply(seq_len(nrow(history) - 1), function(k) {
      a <- history$model[[k]]
      b <- history$model[[k + 1]]
      sa <- Matrix::colSums(.vp_matrix(a, "requires"))
      sb <- Matrix::colSums(.vp_matrix(b, "requires"))
      kept <- intersect(names(sa), names(sb))
      topn <- function(s) {
        names(.vp_sort(s, decreasing = TRUE))[seq_len(min(top, length(s)))]
      }
      tibble::tibble(
        step = k,
        from = history$version[k],
        to = history$version[k + 1],
        spearman = if (length(kept) > 1) {
          suppressWarnings(stats::cor(sa[kept], sb[kept], method = "spearman"))
        } else {
          NA_real_
        },
        top_kept = length(intersect(topn(sa), topn(sb)))
      )
    }),
    tibble::tibble(
      step = integer(0),
      from = history$version[0],
      to = history$version[0],
      spearman = numeric(0),
      top_kept = integer(0)
    )
  )
}

#' Steps that changed far more than usual
#'
#' Disruptions: the steps that changed a graph far more than usual. The change
#' of a step is 1 - jaccard; a step is flagged when its change is more than
#' `threshold` robust standard deviations above the median of all steps. (The
#' robust standard deviation is the MAD; when more than half of the steps change
#' nothing, the MAD is 0 and the ordinary standard deviation is used instead.)
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param threshold How many robust standard deviations above the median a
#'   change must be to count as a disruption.
#' @return The rows of vp_history_changes() with two more columns: `score` and
#'   `disruption` (TRUE/FALSE).
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_disruptions(history)
vp_disruptions <- function(history, threshold = 3.5) {
  ch <- vp_history_changes(history)
  ch$score <- NA_real_
  for (g in unique(ch$graph)) {
    x <- 1 - ch$jaccard[ch$graph == g]
    s <- stats::mad(x)
    if (s == 0) {
      s <- stats::sd(x)
    }
    ch$score[ch$graph == g] <- if (is.na(s) || s == 0) {
      0
    } else {
      (x - stats::median(x)) / s
    }
  }
  ch$disruption <- ch$score > threshold
  ch
}

#' How long new links last
#'
#' How long new links last. A link is followed from the version in which it
#' appears between two features that both existed before; the share still
#' present is measured 1, 2, ... `horizon` versions later.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param graph Which graph: `"requires"`, `"excludes"` or `"atleastone"` (the
#'   last one needs `or_graph = TRUE` in [vp_generate()]).
#' @param horizon How many versions to follow each link.
#' @return A tibble with `age` (versions after it appeared), `followed` (links
#'   that can be followed that far), `still_present` and `share`.
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_link_lifetime(history, "requires", horizon = 2)
vp_link_lifetime <- function(
  history,
  graph = c("excludes", "requires", "atleastone"),
  horizon = 5
) {
  graph <- match.arg(graph)
  keys <- lapply(history$model, function(m) .vp_keys(m, graph, .vp_nodes(m)))
  nodes <- lapply(history$model, .vp_nodes)
  n_versions <- nrow(history)
  res <- matrix(0, horizon, 2)
  for (t in seq_len(n_versions)[-1]) {
    born <- setdiff(keys[[t]], keys[[t - 1]])
    ends <- strsplit(born, "\t", fixed = TRUE)
    old <- vapply(ends, function(e) all(e %in% nodes[[t - 1]]), TRUE)
    born <- born[old]
    if (length(born) == 0) {
      next
    }
    for (k in seq_len(horizon)) {
      if (t + k <= n_versions) {
        res[k, 1] <- res[k, 1] + length(born)
        res[k, 2] <- res[k, 2] + sum(born %in% keys[[t + k]])
      }
    }
  }
  tibble::tibble(
    age = seq_len(horizon),
    followed = res[, 1],
    still_present = res[, 2],
    share = ifelse(res[, 1] > 0, res[, 2] / res[, 1], NA_real_)
  )
}

#' How features move between variable, core, dead, absent
#'
#' The life cycle of features: how often a feature in one state is in each state
#' one version later, over the whole history.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @return A tibble with `before`, `after`, `n` (moves) and `share` (of the
#'   features that were in state `before`).
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_life_cycle(history)
vp_life_cycle <- function(history) {
  st <- vp_feature_states(history)
  v <- levels(history$version)
  pairs <- .vp_rows(
    lapply(seq_len(length(v) - 1), function(k) {
      a <- st[st$version == v[k], ]
      b <- st[st$version == v[k + 1], ]
      tibble::tibble(
        before = a$state,
        after = b$state[match(a$feature, b$feature)]
      )
    }),
    tibble::tibble(before = character(0), after = character(0))
  )
  if (nrow(pairs) == 0) {
    return(tibble::tibble(
      before = character(0),
      after = character(0),
      n = integer(0),
      share = numeric(0)
    ))
  }
  pairs <- pairs[!(pairs$before == "absent" & pairs$after == "absent"), ]
  t <- as.data.frame(
    table(before = pairs$before, after = pairs$after),
    stringsAsFactors = FALSE
  )
  t <- t[t$Freq > 0, ]
  out <- tibble::tibble(
    before = t$before,
    after = t$after,
    n = as.integer(t$Freq)
  )
  tot <- tapply(out$n, out$before, sum)
  out$share <- as.vector(out$n / tot[out$before])
  out[order(out$before, -out$n, method = "radix"), ]
}

#' Do communities stay the same?
#'
#' Do communities stay the same? For each step: how alike the communities of two
#' consecutive versions are (on the features they share), and, as a yardstick,
#' how alike two runs of the algorithm on the same version are. If the second
#' number is not clearly higher than the first, the change cannot be told apart
#' from the randomness.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param seed The seed of the random numbers, so that the result can be
#'   repeated. The random state of the session is left as it was.
#' @return A tibble with `step`, `from`, `to`, `between_versions` and
#'   `same_version_two_runs`.
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_community_history(history)
vp_community_history <- function(history, seed = 1) {
  com <- lapply(history$model, vp_communities, seed = seed)
  .vp_rows(
    lapply(seq_len(nrow(history) - 1), function(k) {
      again <- vp_communities(history$model[[k]], seed = seed + 1)
      tibble::tibble(
        step = k,
        from = history$version[k],
        to = history$version[k + 1],
        between_versions = vp_compare_groupings(com[[k]], com[[k + 1]]),
        same_version_two_runs = vp_compare_groupings(com[[k]], again)
      )
    }),
    tibble::tibble(
      step = integer(0),
      from = history$version[0],
      to = history$version[0],
      between_versions = numeric(0),
      same_version_two_runs = numeric(0)
    )
  )
}

#' One row per feature and version, for predictions
#'
#' One row per feature and version, with measures taken in that version (the
#' predictors) and what happened to the feature afterwards (the outcomes): the
#' table that a prediction model learns from.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param horizon How many versions ahead `gone_later` looks.
#' @return A tibble with `version`, `feature`, `age` (versions since it could
#'   first vary), the measures `required_by`, `requires`, `excludes`, `level`,
#'   `direct_dependants`, `betweenness`, and the outcomes `gone_next` (absent in
#'   the next version), `gone_later` (absent `horizon` versions later; NA near
#'   the end) and `new_dependants` (new features that require it directly in the
#'   next version).
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_prediction_table(history, horizon = 2)
vp_prediction_table <- function(history, horizon = 3) {
  n_versions <- nrow(history)
  first <- list()
  att <- vp_attachment(history)
  rows <- lapply(seq_len(n_versions - 1), function(t) {
    m <- history$model[[t]]
    ft <- vp_feature_table(m)
    for (f in ft$feature) {
      if (is.null(first[[f]])) first[[f]] <<- t
    }
    present <- function(k) {
      if (k <= n_versions) history$model[[k]]$features$feature else NULL
    }
    a <- att[att$step == t, ]
    tibble::tibble(
      version = history$version[t],
      feature = ft$feature,
      age = t - vapply(ft$feature, function(f) first[[f]], 0),
      required_by = ft$required_by,
      requires = ft$requires,
      excludes = ft$excludes,
      level = ft$level,
      direct_dependants = ft$direct_required_by,
      betweenness = ft$betweenness,
      gone_next = !(ft$feature %in% present(t + 1)),
      gone_later = if (t + horizon <= n_versions) {
        !(ft$feature %in% present(t + horizon))
      } else {
        NA
      },
      new_dependants = a$new_dependants[match(ft$feature, a$feature)]
    )
  })
  .vp_rows(
    rows,
    tibble::tibble(
      version = history$version[0],
      feature = character(0),
      age = numeric(0),
      required_by = integer(0),
      requires = integer(0),
      excludes = integer(0),
      level = integer(0),
      direct_dependants = integer(0),
      betweenness = numeric(0),
      gone_next = logical(0),
      gone_later = logical(0),
      new_dependants = integer(0)
    )
  )
}

#' How good a ranking is (area under the curve)
#'
#' The area under the ROC curve of a score: the chance that a case with the
#' outcome gets a higher score than a case without it. 0.5 is a coin toss, 1 a
#' perfect ranking.
#'
#' @param score A numeric score of each case (higher: the outcome is predicted
#'   more strongly).
#' @param outcome A logical vector: whether each case had the outcome.
#' @return A number between 0 and 1, or `NA` when `outcome` has only one value.
#' @family evolution
#' @export
#' @examples
#' vp_auc(c(0.9, 0.8, 0.3, 0.1), c(TRUE, TRUE, FALSE, FALSE))
#' vp_auc(c(0.1, 0.8, 0.3, 0.9), c(TRUE, TRUE, FALSE, FALSE))
vp_auc <- function(score, outcome) {
  ok <- !is.na(score) & !is.na(outcome)
  score <- score[ok]
  y <- as.logical(outcome[ok])
  n1 <- sum(y)
  n0 <- sum(!y)
  if (n1 == 0 || n0 == 0) {
    return(NA_real_)
  }
  r <- rank(score)
  (sum(r[y]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

#' Forecast the size of later versions
#'
#' Forecast the number of links of later versions from their number of features.
#' The growth law is fitted on the first `train` versions; a cruder rule ("links
#' per feature stay as in the last known version") is given beside it.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param train How many of the first versions to fit the growth law on (at
#'   least 3, and fewer than the versions of the history).
#' @return A tibble with `version`, `links`, `observed`, `growth_law`,
#'   `same_ratio` and the errors of both, as shares.
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_forecast_size(history, train = 3)
vp_forecast_size <- function(history, train) {
  s <- vp_history_sizes(history)
  if (train < 3 || train >= nrow(s)) {
    stop(
      "train must be at least 3 and less than the number of versions.",
      call. = FALSE
    )
  }
  kinds <- c("requires", "excludes", "skeleton", "primitive_conflicts")
  test <- (train + 1):nrow(s)
  dplyr::bind_rows(lapply(kinds, function(k) {
    tr <- s[seq_len(train), ]
    ok <- tr[[k]] > 0
    law <- rep(NA_real_, length(test))
    if (sum(ok) >= 3) {
      fit <- stats::lm(log(tr[[k]][ok]) ~ log(tr$features[ok]))
      law <- exp(
        stats::coef(fit)[1] + stats::coef(fit)[2] * log(s$features[test])
      )
    }
    ratio <- tr[[k]][train] / tr$features[train] * s$features[test]
    obs <- s[[k]][test]
    tibble::tibble(
      version = s$version[test],
      links = k,
      observed = obs,
      growth_law = unname(law),
      same_ratio = ratio,
      error_growth_law = abs(law - obs) / obs,
      error_same_ratio = abs(ratio - obs) / obs
    )
  }))
}

# ------------------------------------------------------------- internal helpers
# Links of a graph among some features, as text keys "from<TAB>to" (undirected
# links with the two names sorted).
.vp_keys <- function(model, graph, among) {
  l <- model[[graph]]
  if (is.null(l)) {
    return(character(0))
  }
  l <- l[l$from %in% among & l$to %in% among, ]
  if (graph == "requires") {
    return(paste(l$from, l$to, sep = "\t"))
  }
  paste(pmin(l$from, l$to), pmax(l$from, l$to), sep = "\t")
}

.vp_spearman_in <- function(old, new, kept) {
  if (length(kept) < 2) {
    return(NA_real_)
  }
  ia <- Matrix::colSums(.vp_matrix(old, "requires"))[kept]
  ib <- Matrix::colSums(.vp_matrix(new, "requires"))[kept]
  if (stats::sd(ia) == 0 || stats::sd(ib) == 0) {
    return(NA_real_)
  }
  stats::cor(ia, ib, method = "spearman")
}

# ------------------------------------------------------------ more on histories
#' Did a step restrict the model, relax it, or both?
#'
#' The type of each step, after Thuem et al.: a step that removes products is a
#' specialisation, one that adds products a generalisation, one that does both
#' an arbitrary edit, and one that changes nothing a refactoring. The graphs
#' give necessary conditions, on the kept features: links only gained is
#' necessary for a specialisation, links only lost for a generalisation, and no
#' change at all for a refactoring.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @return A tibble with `step`, `from`, `to`, `gained`, `lost` (all graphs
#'   together) and `type`: "refactoring?", "specialisation?", "generalisation?"
#'   (each one only possible, not proved) or "arbitrary edit" (certain).
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_edit_type(history)
vp_edit_type <- function(history) {
  # products are decided by the complete graphs
  history$model <- lapply(history$model, .vp_complete)
  ch <- vp_history_changes(history)
  steps <- unique(ch$step)
  .vp_rows(
    lapply(steps, function(s) {
      r <- ch[ch$step == s, ]
      g <- sum(r$gained)
      l <- sum(r$lost)
      type <- if (g == 0 && l == 0) {
        "refactoring?"
      } else if (l == 0) {
        "specialisation?"
      } else if (g == 0) {
        "generalisation?"
      } else {
        "arbitrary edit"
      }
      tibble::tibble(
        step = s,
        from = r$from[1],
        to = r$to[1],
        gained = as.integer(g),
        lost = as.integer(l),
        type = type
      )
    }),
    tibble::tibble(
      step = integer(0),
      from = history$version[0],
      to = history$version[0],
      gained = integer(0),
      lost = integer(0),
      type = character(0)
    )
  )
}

#' Features that change state back and forth
#'
#' Features that flip: they change state (variable, core, dead, absent) back and
#' forth, at least `min_moves` times. Something in their conditions is edited
#' again and again; they are worth a closer look.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param min_moves The smallest number of changes of state to report.
#' @return A tibble with `feature`, `moves` and `path` (the states in order,
#'   without repetitions).
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_flip_flops(history, min_moves = 1)
vp_flip_flops <- function(history, min_moves = 2) {
  st <- vp_feature_states(history)
  st <- st[order(st$feature, as.integer(st$version), method = "radix"), ]
  rows <- lapply(split(st$state, st$feature), function(s) {
    # ignore the time before it first appears
    s <- s[s != "absent" | seq_along(s) > min(which(s != "absent"))]
    r <- rle(s)$values
    c(moves = length(r) - 1, path = paste(r, collapse = " > "))
  })
  out <- tibble::tibble(
    feature = names(rows),
    moves = as.integer(vapply(rows, `[[`, "", "moves")),
    path = vapply(rows, `[[`, "", "path")
  )
  out <- out[out$moves >= min_moves, ]
  out[order(-out$moves, out$feature, method = "radix"), ]
}

#' Features that were probably renamed
#'
#' Features that may have been renamed between two versions. Features are
#' matched by name, so a renamed feature looks like one removed and one added.
#' This function pairs each removed feature with the added feature whose links
#' to the kept features are most alike (Jaccard index of their typed
#' neighbours), one to one (a maximum matching). With `file`, the pairs whose
#' names are alike too (name_similarity >= `name_threshold`) are written to it,
#' one `old<tab>new` per line, ready for [vp_rename()] (and for the command
#' `strong4vm diff --rename`).
#'
#' @param old The older version of a model (from [vp_generate()] or
#'   [vp_read()]).
#' @param new The newer version of the same model.
#' @param threshold The smallest similarity (of the links) to report.
#' @param file A file to write the accepted renames to; NULL (the default)
#'   writes nothing.
#' @param name_threshold The smallest name_similarity of a pair written to
#'   `file`.
#' @return A tibble with `old`, `new`, `similarity` (of their links, 1 = the
#'   same) and `name_similarity` (of the names, 1 = equal), the most similar
#'   first.
#' @family evolution
#' @export
#' @examples
#' old <- vp_generate(vp_example("miband3_planned.uvl"), or_graph = TRUE)
#' new <- vp_generate(vp_example("miband3_realized.uvl"), or_graph = TRUE)
#' vp_rename_candidates(old, new, threshold = 0.3)
vp_rename_candidates <- function(
  old,
  new,
  threshold = 0.5,
  file = NULL,
  name_threshold = 0.7
) {
  if (
    !is.numeric(name_threshold) ||
      length(name_threshold) != 1 ||
      is.na(name_threshold) ||
      name_threshold < 0 ||
      name_threshold > 1
  ) {
    stop("name_threshold must be a number between 0 and 1.", call. = FALSE)
  }
  if (
    !is.null(file) &&
      (!is.character(file) || length(file) != 1 || is.na(file) || !nzchar(file))
  ) {
    stop(
      "file must be the name of a file, such as \"renames.txt\".",
      call. = FALSE
    )
  }
  out <- .vp_rename_pairs(old, new, threshold)
  if (!is.null(file)) {
    keep <- out[out$name_similarity >= name_threshold, ]
    writeLines(
      c(
        sprintf(
          paste0(
            "# renames from vp_rename_candidates(): link similarity >= %s, ",
            "name similarity >= %s"
          ),
          threshold,
          name_threshold
        ),
        if (nrow(keep) > 0) paste(keep$old, keep$new, sep = "\t")
      ),
      file,
      useBytes = TRUE
    )
  }
  out
}

#' Rename features of a model
#'
#' Features are matched by name when two versions are compared, so a feature
#' that changed its name looks like one removed and one added, and its links
#' drop out of the comparison. `vp_rename()` gives the features of a version the
#' names they have in the other one, before comparing (it does what the option
#' `--rename` of the command `strong4vm diff` does). [vp_rename_candidates()]
#' suggests the renames.
#'
#' @param model A model, from [vp_generate()] or [vp_read()].
#' @param renames The renames: a named character vector (`c(old = "new")`), a
#'   data frame with the columns `old` and `new` (such as the answer of
#'   [vp_rename_candidates()]), or the path of a file with one rename per line
#'   (the old name, a space, the new name; a tab instead of the space when a
#'   name has spaces; lines that start with `#` and empty lines are ignored),
#'   such as the file that [vp_rename_candidates()] writes.
#' @return The model with the features renamed in its features, graphs and
#'   atomic sets. A rename whose old name is not a feature of the model changes
#'   nothing, with a warning.
#' @family evolution
#' @export
#' @examples
#' old <- vp_generate(vp_example("miband3_planned_old.uvl"), or_graph = TRUE)
#' new <- vp_generate(vp_example("miband3_realized.uvl"), or_graph = TRUE)
#' vp_compare(old, new) # BLEv40Old and BLEv40 look different
#' vp_compare(vp_rename(old, c(BLEv40Old = "BLEv40")), new)
vp_rename <- function(model, renames) {
  if (
    is.character(renames) && length(renames) == 1 && is.null(names(renames))
  ) {
    if (!file.exists(renames)) {
      stop("There is no file of renames \"", renames, "\".", call. = FALSE)
    }
    l <- trimws(readLines(renames, warn = FALSE, encoding = "UTF-8"), "right")
    l <- l[nzchar(trimws(l)) & !startsWith(trimws(l), "#")]
    parts <- lapply(l, function(x) {
      if (grepl("\t", x)) {
        strsplit(x, "\t", fixed = TRUE)[[1]]
      } else {
        strsplit(trimws(x), " +")[[1]]
      }
    })
    bad <- lengths(parts) != 2
    if (any(bad)) {
      stop(
        paste0(
          "Each line of a file of renames is the old name, a space (or a ",
          "tab), and the new name: "
        ),
        paste0("\"", l[bad], "\"", collapse = ", "),
        call. = FALSE
      )
    }
    renames <- stats::setNames(
      vapply(parts, `[`, "", 2),
      vapply(parts, `[`, "", 1)
    )
  } else if (is.data.frame(renames)) {
    if (!all(c("old", "new") %in% names(renames))) {
      stop(
        "A data frame of renames needs the columns old and new.",
        call. = FALSE
      )
    }
    renames <- stats::setNames(
      as.character(renames$new),
      as.character(renames$old)
    )
  }
  if (
    !is.character(renames) ||
      is.null(names(renames)) ||
      anyNA(renames) ||
      any(!nzchar(names(renames)))
  ) {
    stop(
      paste0(
        "`renames` must be c(old = \"new\"), a data frame with old and new, ",
        "or a file."
      ),
      call. = FALSE
    )
  }
  if (anyDuplicated(names(renames))) {
    stop(
      "An old name is given twice: ",
      names(renames)[duplicated(names(renames))][1],
      call. = FALSE
    )
  }
  if (anyDuplicated(renames)) {
    stop(
      "Two old names get the same new name: ",
      renames[duplicated(renames)][1],
      call. = FALSE
    )
  }
  unused <- setdiff(names(renames), model$features$feature)
  if (length(unused)) {
    warning(
      "Not features of the model, so not renamed: ",
      paste(unused, collapse = ", "),
      call. = FALSE
    )
  }
  renames <- renames[!names(renames) %in% unused]
  clash <- intersect(renames, setdiff(model$features$feature, names(renames)))
  if (length(clash)) {
    stop(
      "The new name is already a feature of the model: ",
      paste(clash, collapse = ", "),
      call. = FALSE
    )
  }
  if (!length(renames)) {
    return(model)
  }
  r <- function(x) {
    i <- match(x, names(renames))
    x[!is.na(i)] <- unname(renames[i[!is.na(i)]])
    x
  }
  model$features$feature <- r(model$features$feature)
  for (g in c("requires", "excludes", "atleastone")) {
    if (!is.null(model[[g]])) {
      model[[g]]$from <- r(model[[g]]$from)
      model[[g]]$to <- r(model[[g]]$to)
    }
  }
  if (!is.null(model$atomic)) {
    model$atomic$feature <- r(model$atomic$feature)
  }
  if (!is.null(model$sets)) {
    model$sets$feature <- r(model$sets$feature)
    model$sets$representative <- r(model$sets$representative)
  }
  if (!is.null(model$node_order)) {
    model$node_order <- r(model$node_order)
  }
  model$prefix <- paste0(
    model$prefix,
    "#renamed:",
    paste(names(renames), renames, sep = ">", collapse = ",")
  )
  model
}

.vp_rename_pairs <- function(old, new, threshold) {
  kept <- intersect(.vp_nodes(old), .vp_nodes(new))
  gone <- setdiff(.vp_nodes(old), new$features$feature)
  came <- setdiff(.vp_nodes(new), old$features$feature)
  empty <- tibble::tibble(
    old = character(0),
    new = character(0),
    similarity = numeric(0),
    name_similarity = numeric(0)
  )
  if (length(gone) == 0 || length(came) == 0) {
    return(empty)
  }
  neighbours <- function(m, f) {
    r <- m$requires
    e <- m$excludes
    a <- m$atleastone
    c(
      paste0("needs:", r$to[r$from == f & r$to %in% kept]),
      paste0("needed by:", r$from[r$to == f & r$from %in% kept]),
      paste0(
        "excludes:",
        c(
          e$to[e$from == f & e$to %in% kept],
          e$from[e$to == f & e$from %in% kept]
        )
      ),
      if (!is.null(a)) {
        paste0(
          "or:",
          c(
            a$to[a$from == f & a$to %in% kept],
            a$from[a$to == f & a$from %in% kept]
          )
        )
      }
    )
  }
  ng <- lapply(gone, neighbours, m = old)
  nc <- lapply(came, neighbours, m = new)
  jac <- outer(
    seq_along(gone),
    seq_along(came),
    Vectorize(function(i, j) {
      u <- length(union(ng[[i]], nc[[j]]))
      if (u == 0) 0 else length(intersect(ng[[i]], nc[[j]])) / u
    })
  )
  ok <- which(jac >= threshold, arr.ind = TRUE)
  if (nrow(ok) == 0) {
    return(empty)
  }
  g <- igraph::make_bipartite_graph(
    c(rep(FALSE, length(gone)), rep(TRUE, length(came))),
    as.vector(rbind(ok[, 1], length(gone) + ok[, 2])),
    directed = FALSE
  )
  mt <- igraph::max_bipartite_match(g, weights = jac[ok])$matching[seq_along(
    gone
  )]
  i <- which(!is.na(mt))
  j <- mt[i] - length(gone)
  nd <- 1 -
    diag(utils::adist(gone[i], came[j]), names = FALSE) /
      pmax(nchar(gone[i]), nchar(came[j]))
  out <- tibble::tibble(
    old = gone[i],
    new = came[j],
    similarity = jac[cbind(i, j)],
    name_similarity = nd
  )
  out[order(-out$similarity, -out$name_similarity, method = "radix"), ]
}

# -------------------------------------------------------- deeper into histories
#' Any measure, version by version
#'
#' Applies a function to every version of a history and binds the answers, one
#' block per version. The function takes a model and returns a number (one
#' column `value`), a named vector (one column per name) or a tibble (its rows).
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param f A function of a model, such as vp_depth, or function(m)
#'   vp_gini(vp_feature_table(m)$required_by).
#' @param ... More arguments for `f`.
#' @return A tibble with `version` and the columns of the answers.
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_history_apply(history, vp_depth)
#' vp_history_apply(
#'   history,
#'   function(m) vp_gini(vp_feature_table(m)$required_by)
#' )
vp_history_apply <- function(history, f, ...) {
  f <- match.fun(f)
  out <- lapply(seq_len(nrow(history)), function(k) {
    r <- f(history$model[[k]], ...)
    r <- if (is.data.frame(r)) {
      tibble::as_tibble(r)
    } else if (is.atomic(r) && length(r) == 1 && is.null(names(r))) {
      tibble::tibble(value = r)
    } else if (is.atomic(r) && !is.null(names(r))) {
      tibble::as_tibble(as.list(r))
    } else {
      stop(
        "f must return a number, a named vector or a tibble (version ",
        history$version[k],
        ")"
      )
    }
    tibble::tibble(version = rep(history$version[k], nrow(r)), r)
  })
  dplyr::bind_rows(out)
}

#' How many consequences each written change had
#'
#' The ripple of each step: how many links of the complete graphs changed for
#' each link of the minimal form (what was written, roughly) that changed. A
#' ripple of 10 means that each written change had, on average, ten
#' consequences: features far from the edit gained or lost dependencies or
#' conflicts. Count the graphs together (the default): a written requirement
#' also makes conflicts, which are inherited downwards (property P2).
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param by_graph FALSE: one row per step, the graphs added up; TRUE: one row
#'   per step and graph.
#' @return A tibble with `step`, `from`, `to`, (`graph`,) `written_gained`,
#'   `written_lost` (in the minimal forms), `gained`, `lost` (in the complete
#'   graphs) and `ripple` (complete changes over written changes; NA when
#'   nothing written changed).
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_ripple(history)
vp_ripple <- function(history, by_graph = FALSE) {
  full <- vp_history_changes(dplyr::mutate(
    history,
    model = lapply(model, .vp_complete)
  ))
  mini <- vp_history_changes(dplyr::mutate(
    history,
    model = lapply(model, vp_minimal)
  ))
  w <- mini[c("step", "graph", "gained", "lost")]
  names(w)[3:4] <- c("written_gained", "written_lost")
  r <- dplyr::left_join(
    full[c("step", "from", "to", "graph", "gained", "lost")],
    w,
    by = c("step", "graph")
  )
  r$written_gained[is.na(r$written_gained)] <- 0L
  r$written_lost[is.na(r$written_lost)] <- 0L
  r <- r[c(
    "step",
    "from",
    "to",
    "graph",
    "written_gained",
    "written_lost",
    "gained",
    "lost"
  )]
  if (!by_graph) {
    r <- dplyr::summarise(
      dplyr::group_by(r, step, from, to),
      dplyr::across(c(written_gained, written_lost, gained, lost), sum),
      .groups = "drop"
    )
    r <- r[order(r$step, method = "radix"), ]
  }
  written <- r$written_gained + r$written_lost
  r$ripple <- ifelse(
    written > 0,
    (r$gained + r$lost) / pmax(written, 1),
    NA_real_
  )
  r
}

#' Combinations of two features a step made possible or impossible (and the
#' tests they touch)
#'
#' The combinations of two features that a step made possible or impossible.
#' Among the features that can vary in both versions, a combination of two
#' features is possible exactly when no link forbids it (property P3), so a
#' gained link forbids one combination and a lost link allows one: a lost "a
#' requires b" allows "a without b", a lost conflict allows "a and b", a lost
#' at-least-one line allows "neither". With a sample of configurations (the
#' tests of the old version), `in_sample` counts the configurations that have
#' the combination: a test with a combination now impossible is no longer valid;
#' a combination now possible with in_sample 0 is a new interaction that no test
#' exercises.
#'
#' @param old The older version of a model (from [vp_generate()] or
#'   [vp_read()]).
#' @param new The newer version of the same model.
#' @param sample Optional: a data frame with one 0/1 (or FALSE/TRUE) column per
#'   feature, one row per configuration.
#' @return A tibble with `feature_1`, `value_1`, `feature_2`, `value_2` (TRUE =
#'   selected), `change` ("now possible" or "now impossible"), `graph` (the link
#'   that changed) and, with a sample, `in_sample`.
#' @family evolution
#' @export
#' @examples
#' old <- vp_generate(vp_example("miband3_planned.uvl"), or_graph = TRUE)
#' new <- vp_generate(vp_example("miband3_realized.uvl"), or_graph = TRUE)
#' vp_interaction_changes(old, new)
vp_interaction_changes <- function(old, new, sample = NULL) {
  old <- .vp_complete(old)
  new <- .vp_complete(new) # combinations are decided by the complete graphs
  graphs <- c(
    "requires",
    "excludes",
    if (!is.null(old$atleastone) && !is.null(new$atleastone)) "atleastone"
  )
  rows <- lapply(graphs, function(g) {
    ch <- vp_changed_links(old, new, g)
    if (nrow(ch) == 0) {
      return(NULL)
    }
    tibble::tibble(
      feature_1 = ch$from,
      value_1 = g != "atleastone",
      feature_2 = ch$to,
      value_2 = g == "excludes",
      change = ifelse(ch$change == "gained", "now impossible", "now possible"),
      graph = g
    )
  })
  r <- .vp_rows(
    rows,
    tibble::tibble(
      feature_1 = character(0),
      value_1 = logical(0),
      feature_2 = character(0),
      value_2 = logical(0),
      change = character(0),
      graph = character(0)
    )
  )
  if (!is.null(sample)) {
    miss <- setdiff(unique(c(r$feature_1, r$feature_2)), names(sample))
    if (length(miss) > 0) {
      stop(
        "The sample has no column for: ",
        paste(miss, collapse = ", "),
        call. = FALSE
      )
    }
    s <- as.data.frame(sample)
    if (!all(unlist(s[unique(c(r$feature_1, r$feature_2))]) %in% c(0, 1))) {
      stop("The sample must hold 0/1 or FALSE/TRUE.", call. = FALSE)
    }
    r$in_sample <- vapply(
      seq_len(nrow(r)),
      function(k) {
        sum(
          as.numeric(s[[r$feature_1[k]]]) == r$value_1[k] &
            as.numeric(s[[r$feature_2[k]]]) == r$value_2[k]
        )
      },
      0L
    )
  }
  r
}

#' The features that changed most over a history (hotspots)
#'
#' How much each feature changed over a history: the links of the chosen graphs
#' it gained or lost, step by step (among the features that can vary on both
#' sides of each step, as in vp_compare()). The features that change most are
#' the hotspots of the history; a hotspot that many features require is a risky
#' foundation.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param graphs The graphs whose links count.
#' @return A tibble with `feature`, `versions` (in how many it can vary),
#'   `steps_changed`, `gained`, `lost`, `churn` (gained + lost) and
#'   `required_by` (in the last version where it can vary), the most changed
#'   first.
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_feature_churn(history)
vp_feature_churn <- function(
  history,
  graphs = c("requires", "excludes", "atleastone")
) {
  graphs <- match.arg(graphs, several.ok = TRUE)
  steps <- .vp_step_touches(history, graphs)
  feats <- unique(unlist(lapply(history$model, .vp_nodes)))
  if (length(feats) == 0) {
    return(tibble::tibble(
      feature = character(0),
      versions = integer(0),
      steps_changed = integer(0),
      gained = integer(0),
      lost = integer(0),
      churn = integer(0),
      required_by = integer(0)
    ))
  }
  gained <- lost <- nsteps <- stats::setNames(integer(length(feats)), feats)
  for (s in steps) {
    if (length(s$gained)) {
      t <- table(s$gained)
      gained[names(t)] <- gained[names(t)] + as.integer(t)
    }
    if (length(s$lost)) {
      t <- table(s$lost)
      lost[names(t)] <- lost[names(t)] + as.integer(t)
    }
    u <- unique(c(s$gained, s$lost))
    nsteps[u] <- nsteps[u] + 1L
  }
  versions <- vapply(
    feats,
    function(f) {
      sum(vapply(history$model, function(m) f %in% .vp_nodes(m), TRUE))
    },
    0L
  )
  rb <- stats::setNames(rep(NA_integer_, length(feats)), feats)
  for (k in seq_len(nrow(history))) {
    m <- .vp_complete(history$model[[k]])
    v <- .vp_nodes(m)
    if (length(v)) {
      rb[v] <- as.integer(Matrix::colSums(.vp_matrix(m, "requires"))[v])
    }
  }
  r <- tibble::tibble(
    feature = feats,
    versions = unname(versions),
    steps_changed = unname(nsteps),
    gained = unname(gained),
    lost = unname(lost),
    churn = unname(gained + lost),
    required_by = unname(rb)
  )
  r[order(-r$churn, -r$steps_changed, r$feature, method = "radix"), ]
}

#' Features whose links change in the same steps
#'
#' Features that change together: pairs of features whose links change in the
#' same steps, as version histories of code reveal files that are always edited
#' together. Two features that change together without a link between them may
#' be tied by something the graphs do not hold (a rule over three features,
#' shared code, the same developer).
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param graphs Which graphs: any of `"requires"`, `"excludes"` and
#'   `"atleastone"`.
#' @param min_together Keep the pairs that changed together in at least this
#'   many steps.
#' @return A tibble with `feature_1`, `feature_2`, `together` (steps in which
#'   both changed), `steps_1`, `steps_2`, `jaccard` (together over the steps in
#'   which either changed), `through_their_link` (steps in which a link between
#'   the two themselves changed) and `linked` (a link joins them in the last
#'   version that has both; NA if none has).
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_co_change(history, min_together = 1)
vp_co_change <- function(
  history,
  graphs = c("requires", "excludes", "atleastone"),
  min_together = 2
) {
  graphs <- match.arg(graphs, several.ok = TRUE)
  empty <- tibble::tibble(
    feature_1 = character(0),
    feature_2 = character(0),
    together = integer(0),
    steps_1 = integer(0),
    steps_2 = integer(0),
    jaccard = numeric(0),
    through_their_link = integer(0),
    linked = logical(0)
  )
  steps <- .vp_step_touches(history, graphs)
  feats <- .vp_sort(unique(unlist(lapply(steps, function(s) {
    c(s$gained, s$lost)
  }))))
  if (length(steps) == 0 || length(feats) < 2) {
    return(empty)
  }
  rows <- unlist(lapply(seq_along(steps), function(k) {
    rep(k, length(unique(c(steps[[k]]$gained, steps[[k]]$lost))))
  }))
  cols <- match(
    unlist(lapply(steps, function(s) unique(c(s$gained, s$lost)))),
    feats
  )
  mat <- Matrix::sparseMatrix(
    i = rows,
    j = cols,
    x = 1,
    dims = c(length(steps), length(feats)),
    dimnames = list(NULL, feats)
  )
  conf_m <- as.matrix(Matrix::crossprod(mat))
  ij <- which(upper.tri(conf_m) & conf_m >= min_together, arr.ind = TRUE)
  if (nrow(ij) == 0) {
    return(empty)
  }
  # steps in which the link between the two changed
  own <- table(unlist(lapply(steps, function(s) unique(s$pairs))))
  key <- paste(feats[ij[, 1]], feats[ij[, 2]], sep = "\t")
  last_link <- vapply(
    seq_len(nrow(ij)),
    function(k) {
      a <- feats[ij[k, 1]]
      b <- feats[ij[k, 2]]
      for (v in rev(seq_len(nrow(history)))) {
        m <- .vp_complete(history$model[[v]])
        if (a %in% .vp_nodes(m) && b %in% .vp_nodes(m)) {
          return(any(vapply(
            c("requires", "excludes", "atleastone"),
            function(g) {
              l <- m[[g]]
              !is.null(l) &&
                any((l$from == a & l$to == b) | (l$from == b & l$to == a))
            },
            TRUE
          )))
        }
      }
      NA
    },
    NA
  )
  s1 <- diag(conf_m)[ij[, 1]]
  s2 <- diag(conf_m)[ij[, 2]]
  tg <- conf_m[ij]
  r <- tibble::tibble(
    feature_1 = feats[ij[, 1]],
    feature_2 = feats[ij[, 2]],
    together = as.integer(tg),
    steps_1 = as.integer(s1),
    steps_2 = as.integer(s2),
    jaccard = tg / (s1 + s2 - tg),
    through_their_link = as.integer(ifelse(is.na(own[key]), 0L, own[key])),
    linked = last_link
  )
  r[
    order(-r$together, -r$jaccard, r$feature_1, r$feature_2, method = "radix"),
  ]
}

#' How far apart every two versions are
#'
#' How far apart every two versions are: the Jaccard similarity of one graph
#' among the features that can vary in both (the measure of vp_compare()), for
#' every pair of versions, not only consecutive ones. A version much closer to
#' an older one than to the one just before it reverted a change.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param graph Which graph: `"requires"`, `"excludes"` or `"atleastone"` (the
#'   last one needs `or_graph = TRUE` in [vp_generate()]).
#' @return A tibble with `from`, `to` (every pair, the older first), `kept`,
#'   `jaccard` and `distance` (1 - jaccard).
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_version_distance(history)
vp_version_distance <- function(
  history,
  graph = c("requires", "excludes", "atleastone")
) {
  graph <- match.arg(graph)
  n <- nrow(history)
  ms <- lapply(history$model, .vp_complete)
  if (n < 2) {
    return(tibble::tibble(
      from = history$version[0],
      to = history$version[0],
      kept = integer(0),
      jaccard = numeric(0),
      distance = numeric(0)
    ))
  }
  pr <- utils::combn(n, 2)
  rows <- lapply(seq_len(ncol(pr)), function(k) {
    a <- ms[[pr[1, k]]]
    b <- ms[[pr[2, k]]]
    kept <- intersect(.vp_nodes(a), .vp_nodes(b))
    x <- .vp_keys(a, graph, kept)
    y <- .vp_keys(b, graph, kept)
    u <- length(union(x, y))
    j <- if (u == 0) 1 else length(intersect(x, y)) / u
    tibble::tibble(kept = length(kept), jaccard = j)
  })
  r <- dplyr::bind_rows(rows)
  tibble::tibble(
    from = history$version[pr[1, ]],
    to = history$version[pr[2, ]],
    kept = r$kept,
    jaccard = r$jaccard,
    distance = 1 - r$jaccard
  )
}

#' The history split into runs of alike versions
#'
#' The eras of a history: the split of its versions into k runs of consecutive
#' versions that are as alike as possible inside each run. Exact (dynamic
#' programming) for the criterion of k-means: the sum, over the eras, of the
#' distances between every two versions of the era (vp_version_distance())
#' divided by the number of its versions. A boundary between two eras is where
#' the model changed course.
#'
#' @param history A history: the versions of a model, from [vp_read_history()]
#'   or [vp_history()], oldest first.
#' @param k The number of eras.
#' @param graph Which graph: `"requires"`, `"excludes"` or `"atleastone"` (the
#'   last one needs `or_graph = TRUE` in [vp_generate()]).
#' @return A tibble with `version`, `era` (1 to k) and `spread` (the mean
#'   distance between the versions of its era).
#' @family evolution
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens,
#'   or_graph = TRUE
#' )
#' vp_eras(history, k = 2)
vp_eras <- function(
  history,
  k = 3,
  graph = c("requires", "excludes", "atleastone")
) {
  graph <- match.arg(graph)
  n <- nrow(history)
  if (k < 1 || k > n || k != round(k)) {
    stop(
      "k must be a whole number between 1 and the number of versions (",
      n,
      ")."
    )
  }
  dep_m <- matrix(0, n, n)
  if (n > 1) {
    vd <- vp_version_distance(history, graph)
    idx <- t(utils::combn(n, 2))
    dep_m[idx] <- vd$distance
    dep_m[idx[, 2:1, drop = FALSE]] <- vd$distance
  }
  skel <- apply(dep_m, 2, cumsum)
  skel <- t(apply(skel, 1, cumsum)) # S[i, j]: sum of D over 1..i x 1..j
  block <- function(i, j) {
    # sum of D[a, b] over i <= a, b <= j
    s <- skel[j, j]
    if (i > 1) {
      s <- s - skel[i - 1, j] - skel[j, i - 1] + skel[i - 1, i - 1]
    }
    s
  }
  # the criterion of k-means, with distances
  cost <- function(i, j) block(i, j) / 2 / (j - i + 1)
  mean_d <- function(i, j) {
    m <- j - i + 1
    if (m < 2) 0 else block(i, j) / (m * (m - 1))
  } # the mean distance of two versions
  best <- matrix(Inf, k, n)
  from <- matrix(NA_integer_, k, n)
  for (j in seq_len(n)) {
    best[1, j] <- cost(1, j)
  }
  if (k > 1) {
    for (e in 2:k) {
      for (j in e:n) {
        for (i in e:j) {
          v <- best[e - 1, i - 1] + cost(i, j)
          if (v < best[e, j] - 1e-12) {
            best[e, j] <- v
            from[e, j] <- i
          }
        }
      }
    }
  }
  era <- integer(n)
  j <- n
  for (e in k:1) {
    i <- if (e == 1) 1L else from[e, j]
    era[i:j] <- e
    j <- i - 1L
  }
  spread <- vapply(
    seq_len(k),
    function(e) {
      w <- which(era == e)
      mean_d(min(w), max(w))
    },
    0
  )
  tibble::tibble(version = history$version, era = era, spread = spread[era])
}

# The features touched by the changed links of every step: list(gained = <one
# name per end of each gained link>, lost = ..., pairs = <"a\tb" for every
# changed link, the two names sorted>).
.vp_step_touches <- function(history, graphs) {
  lapply(seq_len(max(0, nrow(history) - 1)), function(k) {
    a <- history$model[[k]]
    b <- history$model[[k + 1]]
    gs <- graphs[vapply(
      graphs,
      function(g) !is.null(a[[g]]) && !is.null(b[[g]]),
      TRUE
    )]
    ch <- dplyr::bind_rows(lapply(gs, function(g) vp_changed_links(a, b, g)))
    if (nrow(ch) == 0) {
      return(list(
        gained = character(0),
        lost = character(0),
        pairs = character(0)
      ))
    }
    list(
      gained = c(ch$from[ch$change == "gained"], ch$to[ch$change == "gained"]),
      lost = c(ch$from[ch$change == "lost"], ch$to[ch$change == "lost"]),
      pairs = paste(pmin(ch$from, ch$to), pmax(ch$from, ch$to), sep = "\t")
    )
  })
}
