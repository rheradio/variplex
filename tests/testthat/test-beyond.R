test_that(
  paste0(
    "Beyond requirements: the largest pairwise-free set and the longest chain ",
    "of decisions, the counterparts of the width"
  ),
  {
    # ==========================================================================
    # Beyond requirements: the largest pairwise-free set and the longest chain
    # of decisions, the counterparts of the width and the depth with the three
    # graphs. Against the oracle, against brute force, and on models made by
    # hand.
    # ==========================================================================
    section(
      paste0(
        paste0(
          "beyond requirements: largest free set and longest chain of ",
          "decisions, "
        ),
        "against the oracle"
      )
    )

    # the largest clique of an adjacency matrix, by plain branch and bound (no
    # igraph)
    max_clique <- function(alo_m) {
      best <- integer(0)
      grow <- function(chosen, cand) {
        if (length(chosen) + length(cand) <= length(best)) {
          return(invisible())
        }
        if (!length(cand)) {
          best <<- chosen
          return(invisible())
        }
        for (k in seq_along(cand)) {
          v <- cand[k]
          if (length(chosen) + length(cand) - k + 1 <= length(best)) {
            break
          }
          grow(c(chosen, v), cand[-(1:k)][alo_m[v, cand[-(1:k)]]])
        }
      }
      grow(integer(0), seq_len(nrow(alo_m)))
      best
    }
    # literals "f" (selected) and "not f" (left out) of the variable features,
    # and the values each takes in every configuration
    literals <- function(x_mat) {
      chg <- cbind(x_mat, !x_mat)
      colnames(chg) <- c(colnames(x_mat), paste0("not ", colnames(x_mat)))
      chg
    }
    # the longest chain l1 => l2 => ... of classes of literals, by the
    # configurations alone: l => m when no configuration has l without m;
    # equivalent literals count as one
    longest_by_configs <- function(x_mat) {
      chg <- literals(x_mat)
      imp <- crossprod(chg, !chg) == 0 # imp[l, m]: l never holds without m
      diag(imp) <- TRUE
      eq <- imp & t(imp)
      cls <- apply(eq, 1, function(r) paste(which(r), collapse = ","))
      reps <- !duplicated(cls)
      # strict: l => m, not m => l
      prim <- imp[reps, reps, drop = FALSE] & !t(imp[reps, reps, drop = FALSE])
      n <- nrow(prim)
      len <- rep(NA_integer_, n)
      f <- function(v) {
        if (is.na(len[v])) {
          nb <- which(prim[v, ])
          len[v] <<- 1L + if (length(nb)) max(vapply(nb, f, 0L)) else 0L
        }
        len[v]
      }
      max(vapply(seq_len(n), f, 0L))
    }
    lit_values <- function(x_mat, d) {
      chg <- literals(x_mat)
      chg[, strsplit(d, " = ", fixed = TRUE)[[1]], drop = FALSE]
    }

    for (n in pick(names(oracle))) {
      m <- models[[n]]
      o <- oracle[[n]]
      x_mat <- o$T$X
      vars <- o$V
      label <- function(what) paste0(n, ": ", what)
      if (length(vars) == 0) {
        check(
          label(
            paste0(
              paste0(
                "no variable feature: empty free set and empty chain, with ",
                "their "
              ),
              "columns"
            )
          ),
          nrow(vp_largest_free_set(m)) == 0 &&
            "feature" %in% names(vp_largest_free_set(m)) &&
            nrow(vp_longest_decision_chain(m)) == 0 &&
            identical(
              names(vp_longest_decision_chain(m)),
              c("step", "decisions")
            )
        )
        next
      }
      # --- free set
      fs <- vp_largest_free_set(m)$feature
      check(
        label("free set: variable features, no repeats"),
        all(fs %in% vars) && !anyDuplicated(fs)
      )
      # the four combinations of the pair occur
      free <- o$T$tt & o$T$tf & t(o$T$tf) & o$T$ff
      diag(free) <- TRUE
      ix <- match(fs, vars)
      check(
        label(
          paste0(
            paste0(
              "free set: every two of its features take the four ",
              "combinations in "
            ),
            "valid configurations"
          )
        ),
        all(free[ix, ix])
      )
      check(
        label("free set: as large as the largest found by brute force"),
        length(fs) == length(max_clique(free))
      )
      check(
        label(
          "free set: no larger than the width (it is an antichain of requires)"
        ),
        length(fs) <= vp_width(m)
      )
      g <- suppressMessages(vp_largest_free_set(m, exact_limit = 0))$feature
      gx <- match(g, vars)
      check(
        label("free set, greedy: pairwise free, and no feature can be added"),
        all(free[gx, gx]) &&
          !any(vapply(
            setdiff(seq_along(vars), gx),
            function(v) all(free[v, gx]),
            TRUE
          ))
      )
      check(
        label("free set, greedy: says that it is greedy"),
        length(vars) == 0 ||
          inherits(
            tryCatch(
              vp_largest_free_set(m, exact_limit = 0),
              message = function(e) e
            ),
            "message"
          )
      )
      # --- longest chain of decisions
      ch <- vp_longest_decision_chain(m)
      check(
        label("decision chain: steps numbered 1..k"),
        identical(ch$step, seq_len(nrow(ch)))
      )
      check(
        label(
          paste0(
            "decision chain: the decisions of a step always go together ",
            "(equivalent)"
          )
        ),
        all(vapply(
          ch$decisions,
          function(d) {
            y_mat <- lit_values(x_mat, d)
            all(y_mat == y_mat[, 1])
          },
          TRUE
        ))
      )
      check(
        label(
          paste0(
            "decision chain: each step forces the next, and the next does not ",
            "force it back"
          )
        ),
        nrow(ch) < 2 ||
          all(vapply(
            seq_len(nrow(ch) - 1),
            function(k) {
              a <- lit_values(x_mat, ch$decisions[k])[, 1]
              b <- lit_values(x_mat, ch$decisions[k + 1])[, 1]
              !any(a & !b) && any(b & !a)
            },
            TRUE
          ))
      )
      check(
        label(
          "decision chain: every decision is possible (each feature can vary)"
        ),
        all(vapply(
          ch$decisions,
          function(d) {
            y <- lit_values(x_mat, d)[, 1]
            any(y) && any(!y)
          },
          TRUE
        ))
      )
      check(
        label(
          paste0(
            "decision chain: as long as the longest chain found from the ",
            "configurations"
          )
        ),
        nrow(ch) == longest_by_configs(x_mat)
      )
      check(
        label("decision chain: at least as long as the depth"),
        nrow(ch) >= vp_depth(m)
      )
      # --- the three forms give the same sizes
      mn <- vp_minimal(m)
      mr <- vp_read(fixtures[[n]]$prefix, form = "minimal")
      check(
        label(
          paste0(
            paste0(
              "free set and decision chain: same sizes from the minimal form ",
              "and "
            ),
            "its files"
          )
        ),
        nrow(vp_largest_free_set(mn)) == length(fs) &&
          nrow(vp_largest_free_set(mr)) == length(fs) &&
          nrow(vp_longest_decision_chain(mn)) == nrow(ch) &&
          nrow(vp_longest_decision_chain(mr)) == nrow(ch)
      )
    }

    section("beyond requirements: models made by hand")
    e0 <- data.frame(from = character(0), to = character(0))
    free3 <- model_from_links(c("a", "b", "c"), e0, e0, name = "free3")
    check(
      paste0(
        paste0(
          "no links: the three features are free; no decision forces ",
          "another, so "
        ),
        "the chain is one decision (like depth 1)"
      ),
      setequal(vp_largest_free_set(free3)$feature, c("a", "b", "c")) &&
        nrow(vp_longest_decision_chain(free3)) == 1 &&
        vp_depth(free3) == 1 &&
        identical(
          names(vp_longest_decision_chain(free3)),
          c("step", "decisions")
        )
    )
    # a requires b, b excludes c: depth 2, but a => b => not c is a chain of
    # three decisions
    x1 <- as.matrix(expand.grid(
      a = c(FALSE, TRUE),
      b = c(FALSE, TRUE),
      c = c(FALSE, TRUE)
    ))
    x1 <- x1[!(x1[, "a"] & !x1[, "b"]) & !(x1[, "b"] & x1[, "c"]), ]
    h1 <- model_from_configs(x1, "req_exc")
    c1 <- vp_longest_decision_chain(h1)
    check(
      "a requires b, b excludes c: depth 2, chain of decisions 3",
      vp_depth(h1) == 2 &&
        nrow(c1) == 3 &&
        (identical(c1$decisions, c("a", "b", "not c")) ||
          identical(c1$decisions, c("c", "not b", "not a")))
    )
    check(
      "a requires b, b excludes c: free set as large as brute force",
      length(vp_largest_free_set(h1)$feature) ==
        length(max_clique({
          t1 <- truth(x1)
          f <- t1$tt & t1$tf & t(t1$tf) & t1$ff
          diag(f) <- TRUE
          f
        }))
    )
    # alternatives: exactly one of x, y, z. Width 3, but no two of them are free
    # (each pair is a conflict)
    x2 <- diag(3) == 1
    colnames(x2) <- c("x", "y", "z")
    h2 <- model_from_configs(x2, "alt3")
    check(
      "exactly one of three: width 3, largest free set 1",
      vp_width(h2) == 3 && nrow(vp_largest_free_set(h2)) == 1
    )
    check(
      "exactly one of three: chain of decisions 2 (x => not y)",
      nrow(vp_longest_decision_chain(h2)) == 2
    )
    # an or of two (at least one): free set 1, chain "not p => q"
    x3 <- rbind(c(TRUE, FALSE), c(FALSE, TRUE), c(TRUE, TRUE))
    colnames(x3) <- c("p", "q")
    h3 <- model_from_configs(x3, "or2")
    check(
      paste0(
        "p or q: width 2, free set 1, chain of 2 decisions through the ",
        "at-least-one line"
      ),
      vp_width(h3) == 2 &&
        nrow(vp_largest_free_set(h3)) == 1 &&
        nrow(vp_longest_decision_chain(h3)) == 2 &&
        all(grepl("^not ", vp_longest_decision_chain(h3)$decisions[1]))
    )
    # an atomic set counts once: s and t always together, and both require u
    x4 <- rbind(
      c(FALSE, FALSE, FALSE),
      c(FALSE, FALSE, TRUE),
      c(TRUE, TRUE, TRUE)
    )
    colnames(x4) <- c("s", "t", "u")
    h4 <- model_from_configs(x4, "atomic")
    c4 <- vp_longest_decision_chain(h4)
    check(
      paste0(
        "atomic set {s, t} requires u: chain of 2, the first step has s and t ",
        "together"
      ),
      nrow(c4) == 2 &&
        (grepl("s = t", c4$decisions[1]) || grepl("not u", c4$decisions[1]))
    )
    check(
      paste0(
        "atomic set {s, t} requires u: free set 1 (s and t are never apart, u ",
        "is required)"
      ),
      nrow(vp_largest_free_set(h4)) == 1
    )

    section("beyond requirements: in the index")
    idx <- vp_functions()
    check(
      paste0(
        "vp_largest_free_set and vp_longest_decision_chain are in the index, ",
        "with their parameters"
      ),
      all(
        c("vp_largest_free_set", "vp_longest_decision_chain") %in% idx$name
      ) &&
        grepl("exact_limit", idx$parameters[idx$name == "vp_largest_free_set"])
    )
  }
)
