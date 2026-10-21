# ==============================================================================
# Topic 6. Configuring: what a choice brings along, and what can go together
#
# Someone who configures a product takes decisions one by one: "I want A", "I do
# not want B". The graphs answer, with no solver, what each decision forces,
# whether a set of decisions can still be completed, and in which order to ask
# the questions. The kernel is a smaller map made for one of those questions:
# "can these features be together?". The last functions split the configuration
# among teams: where they interfere, in which order they decide, and which
# decisions, taken first, cut the model apart.
#
# THE LIMIT THAT MATTERS MOST HERE. The graphs hold every relationship between
# two features, and nothing about rules that tie three or more. So:
#   - a "no" is always right: two of the decisions, or two decisions they force,
#   cannot go together in any product; - a "yes" means "no two of them stand in
#   each other's way". A rule over three or more features can still forbid
#     the whole set. For a wish list of two features the "yes" is exact; for
#     longer ones, ask a solver when it matters (user manual, Part VI, "How to
#     be sure").
#   - decisions that leave features out need the at-least-one graph (use
#   vp_generate(or_graph = TRUE)); without it,
#     a "yes" to such decisions is even less certain.
# ==============================================================================

#' The four combinations of two features: which are possible
#'
#' Everything the graphs say about two features: which of the four combinations
#' (both, only the first, only the second, neither) can occur in a valid
#' product. For two features the answer is exact.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param a The name of a variable feature of the model.
#' @param b The name of another variable feature of the model.
#' @return A tibble with four rows: `combination`, `a`, `b` (TRUE = selected),
#'   `possible` and `ruled_out_by`. Without the at-least-one graph, the row
#'   "neither" has `possible` NA.
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_pair(band, "BLEv40", "BT40")
vp_pair <- function(model, a, b) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  .vp_check_features(model, c(a, b))
  dep_m <- .vp_matrix(model, "requires")
  conf_m <- .vp_matrix(model, "excludes")
  has_alo <- !is.null(model$atleastone)
  alo_m <- if (has_alo) .vp_matrix(model, "atleastone") else NULL
  no_both <- conf_m[a, b] > 0
  no_a_only <- dep_m[a, b] > 0
  no_b_only <- dep_m[b, a] > 0
  no_neither <- if (has_alo) alo_m[a, b] > 0 else NA
  ruled <- c(
    if (no_both) paste(a, "excludes", b) else "",
    if (no_a_only) paste(a, "requires", b) else "",
    if (no_b_only) paste(b, "requires", a) else "",
    if (is.na(no_neither)) {
      "unknown: use vp_generate(or_graph = TRUE)"
    } else if (no_neither) {
      paste("every product has", a, "or", b)
    } else {
      ""
    }
  )
  # built as a list first: inside tibble() the new columns `a` and `b` would
  # hide the arguments a and b
  tibble::as_tibble(list(
    combination = c("both", paste("only", a), paste("only", b), "neither"),
    a = c(TRUE, TRUE, FALSE, FALSE),
    b = c(TRUE, FALSE, TRUE, FALSE),
    possible = !c(no_both, no_a_only, no_b_only, no_neither),
    ruled_out_by = ruled
  ))
}

#' Can these features be in one product? (a wish list)
#'
#' Can these features be selected together in one product? (A wish list, or
#' partial configuration that only selects.)
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param wishes A character vector of features, or a list of such vectors to
#'   check several wish lists at once.
#' @return A tibble with one row per wish list: `wish`, `possible` (FALSE:
#'   certainly not; TRUE: no two features stand in each other's way, which a
#'   rule over three or more features can still contradict) and `reasons` (the
#'   root conflicts that forbid it, separated by ";").
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_can_go_together(band, c("TouchScreen", "HeartRateSensor"))
#' vp_can_go_together(band, list(c("Screen", "BT40"), c("Screen", "NFC")))
vp_can_go_together <- function(model, wishes) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  if (!is.list(wishes)) {
    wishes <- list(wishes)
  }
  m <- .vp_merged(model)
  prim <- vp_primitive_conflicts(model)
  need <- unique(unname(m$rep[.vp_check_features(model, unlist(wishes))]))
  # what each node of the wishes brings, at once
  skel <- Matrix::summary(m$D[need, , drop = FALSE])
  above <- split(m$nodes[skel$j], factor(need[skel$i], levels = need))
  above <- Map(c, need, above[need])
  rows <- lapply(wishes, function(w) {
    w <- .vp_check_features(model, w)
    up <- above[unname(m$rep[w])]
    rep <- unlist(up, use.names = FALSE)
    # each feature brought, and the wish that brings it
    by <- rep(w, lengths(up))
    keep <- !duplicated(rep)
    rep <- rep[keep]
    by <- by[keep]
    hit <- which(prim$from %in% rep & prim$to %in% rep)
    say <- function(x) {
      b <- by[match(x, rep)]
      ifelse(b == x, x, paste0(b, " (which brings ", x, ")"))
    }
    reasons <- if (length(hit)) {
      paste(say(prim$from[hit]), "excludes", say(prim$to[hit]))
    } else {
      character(0)
    }
    list(
      wish = paste(w, collapse = ", "),
      possible = length(hit) == 0,
      reasons = paste(reasons, collapse = "; ")
    )
  })
  tibble::tibble(
    wish = vapply(rows, `[[`, "", "wish"),
    possible = vapply(rows, `[[`, TRUE, "possible"),
    reasons = vapply(rows, `[[`, "", "reasons")
  )
}

#' Is this mix of selected and left-out features possible?
#'
#' Is a mix of decisions possible: some features selected and others left out?
#' The graphs say what each decision forces; the mix is impossible when it
#' forces a feature both in and out.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param selected Features that the product must have.
#' @param deselected Features that the product must not have.
#' @return A list with `possible` (TRUE or FALSE) and `explanation`: a tibble
#'   with one row per feature that the decisions force both in and out, with
#'   `feature`, `in_because` and `out_because` (the decision that forces it in,
#'   and out: "your choice" when it is one of the decisions given, else the
#'   decision that forces it, "A" for "A selected" and "not A" for "A left out")
#'   and `reason` (the same, as a sentence). No rows when the mix is possible.
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_partial_configuration(
#'   band,
#'   selected = "TouchScreen",
#'   deselected = "HeartRateSensor"
#' )
vp_partial_configuration <- function(
  model,
  selected = character(0),
  deselected = character(0)
) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  f <- vp_consequences(model, selected, deselected)
  clash <- intersect(
    f$feature[f$value == "selected"],
    f$feature[f$value == "left out"]
  )
  why <- function(x, value) {
    by <- f$forced_by[f$feature == x & f$value == value][1]
    if (by == x || by == paste("not", x)) "your choice" else by
  }
  said <- function(b) ifelse(b == "your choice", b, paste("forced by", b))
  ins <- vapply(clash, why, "", value = "selected", USE.NAMES = FALSE)
  outs <- vapply(clash, why, "", value = "left out", USE.NAMES = FALSE)
  list(
    possible = length(clash) == 0,
    explanation = tibble::tibble(
      feature = as.character(clash),
      in_because = ins,
      out_because = outs,
      reason = paste0(
        clash,
        " would be both in (",
        said(ins),
        ") and out (",
        said(outs),
        ")"
      )[seq_along(clash)]
    )
  )
}

#' What some decisions force
#'
#' What some decisions force. Selecting a feature selects what it requires and
#' leaves out what it excludes; leaving a feature out leaves out what requires
#' it and selects what it is joined to in the at-least-one graph.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param selected Features that the product must have.
#' @param deselected Features that the product must not have.
#' @return A tibble with `feature`, `value` ("selected" or "left out") and
#'   `forced_by` (the decision that forces it, written as "A" for "A selected"
#'   and "not A" for "A left out"; a decision you gave is forced by itself).
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_consequences(band, selected = "TouchScreen")
vp_consequences <- function(
  model,
  selected = character(0),
  deselected = character(0)
) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  .vp_check_features(model, c(selected, deselected))
  if (length(deselected) > 0 && is.null(model$atleastone)) {
    warning(
      paste0(
        "Without the at-least-one graph (or_graph = TRUE), what leaving a ",
        "feature out forces is incomplete."
      ),
      call. = FALSE
    )
  }
  dep_m <- .vp_matrix(model, "requires")
  conf_m <- .vp_matrix(model, "excludes")
  alo_m <- if (!is.null(model$atleastone)) {
    .vp_matrix(model, "atleastone")
  } else {
    NULL
  }
  out <- list()
  for (s in selected) {
    out[[length(out) + 1]] <- tibble::tibble(
      feature = c(
        s,
        colnames(dep_m)[dep_m[s, ] > 0],
        colnames(conf_m)[conf_m[s, ] > 0]
      ),
      value = c(
        "selected",
        rep("selected", sum(dep_m[s, ] > 0)),
        rep("left out", sum(conf_m[s, ] > 0))
      ),
      forced_by = s
    )
  }
  for (d in deselected) {
    on <- if (is.null(alo_m)) character(0) else colnames(alo_m)[alo_m[d, ] > 0]
    out[[length(out) + 1]] <- tibble::tibble(
      feature = c(d, rownames(dep_m)[dep_m[, d] > 0], on),
      value = c(
        "left out",
        rep("left out", sum(dep_m[, d] > 0)),
        rep("selected", length(on))
      ),
      forced_by = paste("not", d)
    )
  }
  if (length(out) == 0) {
    return(tibble::tibble(
      feature = character(0),
      value = character(0),
      forced_by = character(0)
    ))
  }
  res <- dplyr::bind_rows(out)
  res[!duplicated(res[, c("feature", "value")]), ]
}

#' The kernel: a small map for 'can these go together?'
#'
#' The kernel: the features grouped into classes that behave alike for the
#' question "can these be together?". The class of the trouble-free features
#' (they exclude nothing, by themselves or through what they bring) is marked.
#' The same as the file __kernel_classes.txt of Strong4VM (vp_generate(kernel =
#' TRUE)).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `class` (a number), `label` (the first feature of the
#'   class), `feature` and `trouble_free`.
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"))
#' vp_kernel(band)
vp_kernel <- function(model) .vp_kernel(.vp_complete(model))$classes

#' The arrows and red lines of the kernel
#'
#' The links of the kernel between its classes: "requires" (a class brings
#' another along) and "excludes" (a root conflict). The same as
#' __kernel_requires.net and __kernel_excludes.net.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `from`, `link` and `to` (class labels).
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"))
#' vp_kernel_links(band)
vp_kernel_links <- function(model) .vp_kernel(.vp_complete(model))$links

#' A safe order for asking about features, in rounds
#'
#' A safe order for asking about the features, in rounds: round 1 asks about the
#' features that need nothing, round 2 about those that need only features of
#' round 1, and so on. Nobody is asked about a feature before everything it
#' requires has been decided, and no order of this kind has fewer rounds
#' (Mirsky's theorem).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `round` and `feature`.
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_rounds(band)
vp_rounds <- function(model) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  lv <- vp_levels(model)
  lv <- lv[order(lv$level, match(lv$feature, lv$feature), method = "radix"), ]
  tibble::tibble(round = lv$level + 1L, feature = lv$feature)
}

#' The features whose selection decides the most
#'
#' The features whose selection decides the most (decision power). They describe
#' the model; they are not necessarily the best questions to ask first, because
#' the answer can be "no": the order that needs the fewest questions follows the
#' entropy of each question (Heradio et al., Entropy 2014), which needs the
#' probabilities of the features, beyond what the graphs give.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param n How many rows to return.
#' @return The columns feature, decision_power, requires and excludes of
#'   vp_feature_table(), the `n` largest first.
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_most_decisive(band, n = 5)
vp_most_decisive <- function(model, n = 10) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  t <- vp_feature_table(model)
  t <- t[
    order(-t$decision_power, method = "radix"),
    c("feature", "decision_power", "requires", "excludes")
  ]
  utils::head(t, n)
}

#' How many products the graphs allow (small models)
#'
#' How many products the graphs allow, by trying every selection of the variable
#' features. Only for small models (`max_features`, 20 by default). It shows how
#' much of the model the graphs capture: compare the last number with the number
#' of valid configurations of the model, when it is known.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param max_features The largest number of variable features to try (2^n
#'   selections).
#' @param products The number of valid products of the model, if you know it
#'   (from a model counter): then two more columns say how much of the model the
#'   graphs explain, on a scale of yes/no choices (bits).
#' @return One row: `selections` (2^n), `respect_requires`, `and_excludes`,
#'   `and_atleastone` (NA without or_graph = TRUE); with `products`, also
#'   `bits_model` (how many of the n yes/no choices the model takes away: n -
#'   log2(products)) and `explained` (the share of them that the graphs take
#'   away).
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_count_graph_products(band)
vp_count_graph_products <- function(model, max_features = 20, products = NULL) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  n <- length(.vp_nodes(model))
  if (n > max_features) {
    stop(
      "The model has ",
      n,
      " variable features: 2^",
      n,
      " selections are too many to try.",
      call. = FALSE
    )
  }
  grid <- as.matrix(expand.grid(rep(list(0:1), n)))
  dep_m <- as.matrix(.vp_matrix(model, "requires"))
  conf_m <- as.matrix(.vp_matrix(model, "excludes"))
  dep_ok <- rowSums((grid %*% dep_m) * (1 - grid)) == 0
  conf_ok <- rowSums((grid %*% conf_m) * grid) == 0
  alo_ok <- if (is.null(model$atleastone)) {
    NA
  } else {
    rowSums(
      ((1 - grid) %*% as.matrix(.vp_matrix(model, "atleastone"))) * (1 - grid)
    ) ==
      0
  }
  out <- tibble::tibble(
    selections = 2^n,
    respect_requires = sum(dep_ok),
    and_excludes = sum(dep_ok & conf_ok),
    and_atleastone = if (anyNA(alo_ok)) {
      NA_integer_
    } else {
      sum(dep_ok & conf_ok & alo_ok)
    }
  )
  if (!is.null(products)) {
    allowed <- if (is.na(out$and_atleastone)) {
      out$and_excludes
    } else {
      out$and_atleastone
    }
    out$bits_model <- n - log2(products)
    out$explained <- (n - log2(allowed)) / (n - log2(products))
  }
  out
}

# ------------------------------------------------------------- internal helpers
# The kernel, following the recipe of Strong4VM (user manual, "The kernel"):
# from the merged graphs, delete every arrow into a node that excludes nothing;
# give each node the set of nodes it still requires, itself included if it
# excludes something; merge the nodes with the same set; keep the arrows between
# classes and the primitive conflicts.
.vp_kernel <- function(model) {
  m <- .vp_merged(model)
  if (length(m$nodes) == 0) {
    # no feature can vary: an empty kernel
    return(list(
      classes = tibble::tibble(
        class = integer(0),
        label = character(0),
        feature = character(0),
        trouble_free = logical(0)
      ),
      links = tibble::tibble(
        from = character(0),
        link = character(0),
        to = character(0)
      )
    ))
  }
  has_conf <- Matrix::rowSums(m$C) > 0
  kern_m <- m$D
  if (any(!has_conf)) {
    kern_m[, !has_conf] <- 0
  } # (an empty assignment fails in Matrix)
  need <- vapply(
    seq_along(m$nodes),
    function(i) {
      paste(
        .vp_sort(c(if (has_conf[i]) i, which(kern_m[i, ] > 0))),
        collapse = " "
      )
    },
    ""
  )
  cls <- as.integer(factor(need, levels = unique(need)))
  label <- m$nodes[!duplicated(cls)]
  members <- lapply(seq_along(m$nodes), function(i) {
    r <- m$nodes[i]
    c(r, setdiff(names(m$rep)[m$rep == r], r))
  })
  classes <- dplyr::bind_rows(lapply(seq_along(m$nodes), function(i) {
    tibble::tibble(
      class = cls[i],
      label = label[cls[i]],
      feature = members[[i]],
      trouble_free = need[i] == ""
    )
  }))
  classes <- classes[order(classes$class, method = "radix"), ]
  kern_ij <- Matrix::summary(kern_m)
  arrows <- unique(data.frame(from = cls[kern_ij$i], to = cls[kern_ij$j]))
  arrows <- arrows[arrows$from != arrows$to, ]
  prim <- vp_primitive_conflicts(model)
  ex <- unique(data.frame(
    from = pmin(cls[match(prim$from, m$nodes)], cls[match(prim$to, m$nodes)]),
    to = pmax(cls[match(prim$from, m$nodes)], cls[match(prim$to, m$nodes)])
  ))
  arrows <- arrows[order(arrows$from, arrows$to, method = "radix"), ]
  ex <- ex[order(ex$from, ex$to, method = "radix"), ]
  links <- tibble::tibble(
    from = label[c(arrows$from, ex$from)],
    link = rep(c("requires", "excludes"), c(nrow(arrows), nrow(ex))),
    to = label[c(arrows$to, ex$to)]
  )
  list(classes = classes, links = links)
}

#' The modal implication graph: every implication between two decisions
#'
#' The modal implication graph (MIG): every implication between two decisions
#' ("f selected" or "f left out") that the graphs give. It is the form of the
#' graphs best suited to reasoning (the implication graph of the SAT literature;
#' the modal implication graph of Krieter et al., restricted to what always
#' holds): following its arrows from some decisions gives everything they force,
#' which is what vp_consequences() does.
#'
#' It reads the graphs it is given. On the complete graphs every implication is
#' one arrow; on the minimal form (vp_mig(vp_minimal(model))) it is the compact
#' MIG: far fewer arrows, and following them still reaches every implication (a
#' conflict is inherited through the contrapositive of a requirement, an
#' at-least-one line through requirements), with one node per atomic set. The
#' compact one is the one to draw: vp_plot() draws a MIG directly, with nodes
#' "A" and "not A" and each arrow in the colour of the link it comes from.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with `from`, `from_selected`, `to`, `to_selected` and
#'   `because` ("requires", "excludes" or "atleastone"): deciding `from` as
#'   `from_selected` forces `to` to be `to_selected`.
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_mig(vp_minimal(band))
vp_mig <- function(model) {
  # reads the graphs given: on the minimal form, the compact MIG
  r <- model$requires
  e <- model$excludes
  a <- model$atleastone
  if (is.null(a)) {
    warning(
      paste0(
        "Without the at-least-one graph (or_graph = TRUE) some implications ",
        "of leaving features out are missing."
      ),
      call. = FALSE
    )
  }
  part <- function(f, fs, t, ts, why) {
    tibble::tibble(
      from = f,
      from_selected = fs,
      to = t,
      to_selected = ts,
      because = why
    )
  }
  dplyr::bind_rows(
    part(r$from, TRUE, r$to, TRUE, rep("requires", nrow(r))), # f on  => g on
    part(r$to, FALSE, r$from, FALSE, rep("requires", nrow(r))), # g off => f off
    part(e$from, TRUE, e$to, FALSE, rep("excludes", nrow(e))), # f on  => g off
    part(e$to, TRUE, e$from, FALSE, rep("excludes", nrow(e))),
    if (!is.null(a)) {
      part(a$from, FALSE, a$to, TRUE, rep("atleastone", nrow(a)))
    }, # f off => g on
    if (!is.null(a)) part(a$to, FALSE, a$from, TRUE, rep("atleastone", nrow(a)))
  )
}

# ------------------------------------------------------------------------ teams
# Splitting the configuration among teams. A team is a group of people who
# decide some of the features (those they know). Two teams interfere when a
# feature of one and a feature of the other are tied by a link of the graphs:
# then a decision of one team forces, forbids or needs a decision of the other.
# A split is given as a tibble with `feature` and `team` (or `feature` and any
# other column: its values are the teams), or as a named character vector.

# The team of every node of the graphs. Core and dead features are already
# decided and are ignored; a variable feature that no team owns goes to
# "(unassigned)", with a warning. On the minimal form, a node takes the team of
# any member of its atomic set.
.vp_team_of <- function(model, teams) {
  if (is.data.frame(teams)) {
    if (!"feature" %in% names(teams) || ncol(teams) < 2) {
      stop(
        paste0(
          "`teams` needs a column `feature` and a column with the team of ",
          "each feature."
        ),
        call. = FALSE
      )
    }
    col <- if ("team" %in% names(teams)) {
      "team"
    } else {
      setdiff(names(teams), "feature")[1]
    }
    tm <- stats::setNames(
      as.character(teams[[col]]),
      as.character(teams$feature)
    )
  } else if (is.character(teams) && !is.null(names(teams))) {
    tm <- teams
  } else {
    stop(
      paste0(
        "`teams` must be a tibble with `feature` and `team`, or a named ",
        "character vector (feature = team)."
      ),
      call. = FALSE
    )
  }
  if (any(is.na(tm))) {
    stop("Every feature of `teams` needs a team (NA found).", call. = FALSE)
  }
  dup <- unique(names(tm)[duplicated(names(tm))])
  if (length(dup) > 0) {
    stop(
      paste0("\"", dup, "\" is given to more than one team", collapse = "\n"),
      call. = FALSE
    )
  }
  nodes <- .vp_nodes(model)
  sets <- if (identical(model$form, "minimal") && !is.null(model$sets)) {
    model$sets
  } else {
    NULL
  }
  unknown <- setdiff(names(tm), c(model$features$feature, sets$feature))
  if (length(unknown) > 0) {
    stop(
      paste0(
        "\"",
        unknown,
        "\" is not a feature of the model (check the spelling)",
        collapse = "\n"
      ),
      call. = FALSE
    )
  }
  if (!is.null(sets) && nrow(sets) > 0) {
    # members of an atomic set stand for their node
    given <- sets[
      sets$feature %in% names(tm) & !sets$representative %in% names(tm),
    ]
    given <- given[!duplicated(given$representative), ]
    tm[given$representative] <- tm[given$feature]
  }
  out <- stats::setNames(unname(tm[nodes]), nodes)
  if (anyNA(out)) {
    warning(
      sum(is.na(out)),
      paste0(
        " variable feature(s) belong to no team; they form the team ",
        "\"(unassigned)\": "
      ),
      paste(utils::head(nodes[is.na(out)], 5), collapse = ", "),
      if (sum(is.na(out)) > 5) ", ...",
      call. = FALSE
    )
    out[is.na(out)] <- "(unassigned)"
  }
  out
}

# Every link of the graphs given (requires, excludes and, if present,
# at-least-one), with the team of each end.
.vp_team_all_links <- function(model, team) {
  rows <- lapply(c("requires", "excludes", "atleastone"), function(g) {
    l <- model[[g]]
    if (is.null(l) || nrow(l) == 0) {
      return(NULL)
    }
    tibble::tibble(
      from = l$from,
      from_team = unname(team[l$from]),
      link = g,
      to = l$to,
      to_team = unname(team[l$to])
    )
  })
  .vp_rows(
    rows,
    tibble::tibble(
      from = character(0),
      from_team = character(0),
      link = character(0),
      to = character(0),
      to_team = character(0)
    )
  )
}

#' The links between features of different teams: where teams interfere
#'
#' The links between teams: every link of the graphs whose two features belong
#' to different teams. Each one is a place where a decision of one team forces,
#' forbids or needs a decision of another. A measure: on the complete graphs it
#' lists every pair of features of two teams that constrain each other; on the
#' minimal form, roughly what was written between them.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param teams A tibble with `feature` and `team`, or a named character vector
#'   (feature = team).
#' @return A tibble with `from`, `from_team`, `link` ("requires": `from`
#'   requires `to`; "excludes"; "atleastone") , `to` and `to_team`.
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' teams <- c(
#'   Screen = "display",
#'   TouchScreen = "display",
#'   OLED = "display",
#'   CapacityButton = "display",
#'   ContactlessPayment = "payments",
#'   NFC = "payments",
#'   MovementFilter = "sensors",
#'   HeartRateSensor = "sensors",
#'   BLEv40 = "radio",
#'   BLEv42 = "radio",
#'   BT40 = "radio"
#' )
#' vp_team_links(band, teams)
vp_team_links <- function(model, teams) {
  team <- .vp_team_of(model, teams)
  if (is.null(model$atleastone)) {
    warning(
      paste0(
        "Without the at-least-one graph (or_graph = TRUE), the links through ",
        "leaving features out are missing."
      ),
      call. = FALSE
    )
  }
  l <- .vp_team_all_links(model, team)
  l[l$from_team != l$to_team, ]
}

#' How independent each team is: links inside and outside, features it decides
#' alone
#'
#' How much each team depends on the others: its features, the links inside it
#' and towards other teams, how many teams it is linked to, and how many of its
#' features are free (no link to another team: the team decides them alone). A
#' measure, like vp_team_links().
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param teams The team of each feature: a tibble with the columns `feature`
#'   and `team`, or a named character vector (feature = team).
#' @return A tibble with `team`, `features`, `links_inside`, `links_outside`,
#'   `teams_linked`, `free_features` and `free_share` (free features /
#'   features).
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' teams <- c(
#'   Screen = "display",
#'   TouchScreen = "display",
#'   OLED = "display",
#'   CapacityButton = "display",
#'   ContactlessPayment = "payments",
#'   NFC = "payments",
#'   MovementFilter = "sensors",
#'   HeartRateSensor = "sensors",
#'   BLEv40 = "radio",
#'   BLEv42 = "radio",
#'   BT40 = "radio"
#' )
#' vp_teams(band, teams)
vp_teams <- function(model, teams) {
  team <- .vp_team_of(model, teams)
  l <- .vp_team_all_links(model, team)
  cross <- l[l$from_team != l$to_team, ]
  touched <- unique(c(cross$from, cross$to))
  ts <- .vp_sort(unique(unname(team)))
  rows <- lapply(ts, function(t) {
    mine <- names(team)[team == t]
    partners <- unique(c(
      cross$to_team[cross$from_team == t],
      cross$from_team[cross$to_team == t]
    ))
    free <- sum(!mine %in% touched)
    tibble::tibble(
      team = t,
      features = length(mine),
      links_inside = sum(l$from_team == t & l$to_team == t),
      links_outside = sum(cross$from_team == t | cross$to_team == t),
      teams_linked = length(partners),
      free_features = free,
      free_share = free / length(mine)
    )
  })
  .vp_rows(
    rows,
    tibble::tibble(
      team = character(0),
      features = integer(0),
      links_inside = integer(0),
      links_outside = integer(0),
      teams_linked = integer(0),
      free_features = integer(0),
      free_share = numeric(0)
    )
  )
}

#' Features with more links to another team than to their own
#'
#' Features that sit better in another team: those with more links to some other
#' team than to their own. Moving one removes links between teams (its links to
#' the other team become inside links, those to its own team become outside
#' links). A candidate for a person to judge: who knows the feature matters more
#' than where its links go.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param teams The team of each feature: a tibble with the columns `feature`
#'   and `team`, or a named character vector (feature = team).
#' @return A tibble with `feature`, `team`, `links_own` (links to features of
#'   its own team), `better_team` and `links_better`; the largest gains first.
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' teams <- c(
#'   Screen = "display",
#'   TouchScreen = "display",
#'   OLED = "display",
#'   CapacityButton = "display",
#'   ContactlessPayment = "payments",
#'   NFC = "payments",
#'   MovementFilter = "sensors",
#'   HeartRateSensor = "sensors",
#'   BLEv40 = "radio",
#'   BLEv42 = "radio",
#'   BT40 = "radio"
#' )
#' vp_team_moves(band, teams)
vp_team_moves <- function(model, teams) {
  team <- .vp_team_of(model, teams)
  l <- .vp_team_all_links(model, team)
  ends <- tibble::tibble(
    feature = c(l$from, l$to),
    other_team = c(l$to_team, l$from_team)
  )
  empty <- tibble::tibble(
    feature = character(0),
    team = character(0),
    links_own = integer(0),
    better_team = character(0),
    links_better = integer(0)
  )
  if (nrow(ends) == 0) {
    return(empty)
  }
  cnt <- dplyr::count(ends, feature, other_team)
  cnt$team <- unname(team[cnt$feature])
  own <- cnt[cnt$other_team == cnt$team, c("feature", "n")]
  best <- cnt[cnt$other_team != cnt$team, ]
  best <- best[
    order(best$feature, -best$n, best$other_team, method = "radix"),
  ]
  best <- best[!duplicated(best$feature), ]
  out <- tibble::tibble(
    feature = best$feature,
    team = best$team,
    links_own = as.integer(ifelse(
      is.na(match(best$feature, own$feature)),
      0L,
      own$n[match(best$feature, own$feature)]
    )),
    better_team = best$other_team,
    links_better = as.integer(best$n)
  )
  out <- out[out$links_better > out$links_own, ]
  if (nrow(out) == 0) {
    return(empty)
  }
  out[order(out$links_own - out$links_better, out$feature, method = "radix"), ]
}

#' In which order teams decide, which decide together, which must agree
#'
#' In which order the teams should decide. A team waits for another when one of
#' its features requires a feature of the other: the requirement is decided
#' first, as in vp_rounds(). Teams that wait for each other (directly or through
#' others) must decide together. Conflicts and at-least-one lines between teams
#' have no right order: whoever decides first narrows what the other can choose,
#' so those teams must agree.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param teams The team of each feature: a tibble with the columns `feature`
#'   and `team`, or a named character vector (feature = team).
#' @return A tibble with `team`, `round` (round 1 waits for nobody),
#'   `waits_for`, `decide_together_with` and `must_agree_with` (team names
#'   separated by commas; "" for none).
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' teams <- c(
#'   Screen = "display",
#'   TouchScreen = "display",
#'   OLED = "display",
#'   CapacityButton = "display",
#'   ContactlessPayment = "payments",
#'   NFC = "payments",
#'   MovementFilter = "sensors",
#'   HeartRateSensor = "sensors",
#'   BLEv40 = "radio",
#'   BLEv42 = "radio",
#'   BT40 = "radio"
#' )
#' vp_team_order(band, teams)
vp_team_order <- function(model, teams) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  team <- .vp_team_of(model, teams)
  cross <- .vp_team_all_links(model, team)
  cross <- cross[cross$from_team != cross$to_team, ]
  ts <- .vp_sort(unique(unname(team)))
  w <- dplyr::distinct(cross[
    cross$link == "requires",
    c("from_team", "to_team")
  ])
  g <- igraph::graph_from_data_frame(w, directed = TRUE, vertices = ts)
  # in the order of ts
  scc <- as.integer(igraph::components(g, mode = "strong")$membership)
  # the teams that decide together, as one node
  cg <- igraph::simplify(igraph::contract(g, scc))
  # those waited for come first
  ord <- as.integer(igraph::topo_sort(cg, mode = "in"))
  round <- integer(igraph::vcount(cg))
  for (v in ord) {
    later <- as.integer(igraph::neighbors(cg, v, mode = "out"))
    round[v] <- if (length(later) == 0) 1L else max(round[later]) + 1L
  }
  agree <- dplyr::distinct(cross[
    cross$link != "requires",
    c("from_team", "to_team")
  ])
  listing <- function(x) paste(.vp_sort(unique(x)), collapse = ", ")
  together <- function(k) ts[scc == scc[k]]
  out <- tibble::tibble(
    team = ts,
    round = round[scc],
    waits_for = vapply(
      seq_along(ts),
      function(k) {
        listing(setdiff(w$to_team[w$from_team == ts[k]], together(k)))
      },
      ""
    ),
    decide_together_with = vapply(
      seq_along(ts),
      function(k) listing(setdiff(together(k), ts[k])),
      ""
    ),
    must_agree_with = vapply(
      ts,
      function(t) {
        listing(c(
          agree$to_team[agree$from_team == t],
          agree$from_team[agree$to_team == t]
        ))
      },
      "",
      USE.NAMES = FALSE
    )
  )
  out[order(out$round, out$team, method = "radix"), ]
}

#' The independent parts of what is left after some decisions
#'
#' What is left to decide after some decisions, and how it splits: the
#' independent parts of the features that the decisions do not settle. A few
#' decisions taken first, together, can cut a model that is one piece into parts
#' that teams can then decide apart.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param selected,deselected The decisions taken first (as in
#'   vp_consequences()).
#' @return A tibble with `part`, `size` and `feature` (as
#'   vp_independent_parts()) over the undecided features; its attribute
#'   "decided" lists the features the decisions settle.
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_split_after(band, selected = "BT40")
vp_split_after <- function(
  model,
  selected = character(0),
  deselected = character(0)
) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  ok <- suppressWarnings(vp_partial_configuration(model, selected, deselected))
  if (!ok$possible) {
    stop(
      "These decisions cannot go together: ",
      paste(ok$explanation$reason, collapse = "; "),
      call. = FALSE
    )
  }
  decided <- unique(vp_consequences(model, selected, deselected)$feature)
  rest <- setdiff(.vp_nodes(model), decided)
  out <- if (length(rest) == 0) {
    tibble::tibble(part = integer(0), size = integer(0), feature = character(0))
  } else {
    vp_independent_parts(vp_subset(model, rest))
  }
  attr(out, "decided") <- decided
  out
}

#' Single decisions that split the model most, taken before the teams start
#'
#' Single decisions that split the model most: for each candidate feature,
#' selected and left out, how many features the decision settles and the size of
#' the largest part left (vp_split_after()). The best decisions to take first,
#' together, before the teams start. Every variable feature can be selected and
#' can be left out, so each decision is possible.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param candidates The features to try; by default all of them up to 200
#'   features, else the 50 with most links.
#' @return A tibble with `feature`, `decision` ("selected" or "left out"),
#'   `decided`, `parts` and `largest_part`; the smallest largest part first. Its
#'   attribute "largest_before" is the largest independent part with no
#'   decision.
#' @family configuration
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_splitting_decisions(band)
vp_splitting_decisions <- function(model, candidates = NULL) {
  model <- .vp_complete(model) # an inference: it needs the complete graphs
  nodes <- .vp_nodes(model)
  if (is.null(candidates)) {
    if (length(nodes) <= 200) {
      candidates <- nodes
    } else {
      deg <- table(c(
        model$requires$from,
        model$requires$to,
        model$excludes$from,
        model$excludes$to,
        model$atleastone$from,
        model$atleastone$to
      ))
      deg <- deg[names(deg) %in% nodes]
      candidates <- utils::head(names(.vp_sort(-deg)), 50)
    }
  }
  candidates <- .vp_check_features(model, candidates)
  rows <- lapply(candidates, function(f) {
    dplyr::bind_rows(lapply(c("selected", "left out"), function(d) {
      p <- suppressWarnings(
        if (d == "selected") {
          vp_split_after(model, selected = f)
        } else {
          vp_split_after(model, deselected = f)
        }
      )
      tibble::tibble(
        feature = f,
        decision = d,
        decided = length(attr(p, "decided")),
        parts = dplyr::n_distinct(p$part),
        largest_part = if (nrow(p) == 0) 0L else max(p$size)
      )
    }))
  })
  out <- .vp_rows(
    rows,
    tibble::tibble(
      feature = character(0),
      decision = character(0),
      decided = integer(0),
      parts = integer(0),
      largest_part = integer(0)
    )
  )
  out <- out[
    order(out$largest_part, -out$parts, out$feature, method = "radix"),
  ]
  ip <- vp_independent_parts(model)
  attr(out, "largest_before") <- if (nrow(ip) == 0) 0L else max(ip$size)
  out
}
