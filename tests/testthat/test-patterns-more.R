test_that(
  paste0(
    "Patterns, deeper: the order-keeping shuffle of a hierarchy, triangle ",
    "significance, communities over several graphs,"
  ),
  {
    # ==========================================================================
    # Patterns, deeper: the order-keeping shuffle of a hierarchy, triangle
    # significance, communities over several graphs, and the baseline built on
    # that shuffle.
    # ==========================================================================
    section(
      "patterns, deeper: shuffles, triangle significance, communities, baseline"
    )
    withr::local_seed(11)

    # --- the shuffle keeps every in- and out-degree, the order, and makes no
    # repeated arrow
    for (trial in 1:5) {
      n <- 40
      pos <- sample(n) # a random order
      pairs <- t(combn(n, 2))
      pairs <- pairs[sample(nrow(pairs), 120), ]
      e <- cbind(
        ifelse(pos[pairs[, 1]] < pos[pairs[, 2]], pairs[, 1], pairs[, 2]),
        ifelse(pos[pairs[, 1]] < pos[pairs[, 2]], pairs[, 2], pairs[, 1])
      )
      r <- .vp_swap_dag(e, pos, n, niter = 2000)
      check(
        paste("shuffle", trial, ": same out- and in-degrees"),
        identical(tabulate(r[, 1], n), tabulate(e[, 1], n)) &&
          identical(tabulate(r[, 2], n), tabulate(e[, 2], n))
      )
      check(
        paste(
          "shuffle",
          trial,
          ": every arrow follows the order, none repeated, something moved"
        ),
        all(pos[r[, 1]] < pos[r[, 2]]) &&
          !anyDuplicated(paste(r[, 1], r[, 2])) &&
          !setequal(paste(e[, 1], e[, 2]), paste(r[, 1], r[, 2]))
      )
    }
    check(
      "shuffle: one arrow or none is left as it is",
      identical(
        .vp_swap_dag(matrix(c(1L, 2L), 1), c(1L, 2L), 2, 10),
        matrix(c(1L, 2L), 1)
      )
    )

    # --- triangle counts against brute force over every triple
    brute_triangles <- function(dep_m, conf_m) {
      n <- nrow(dep_m)
      imm <- (dep_m | t(dep_m))
      out <- c(0, 0, 0, 0, 0)
      if (n >= 3) {
        for (tr in combn(n, 3, simplify = FALSE)) {
          pr <- combn(tr, 2)
          rel <- apply(pr, 2, function(p) imm[p[1], p[2]])
          con <- apply(pr, 2, function(p) conf_m[p[1], p[2]])
          if (!(all(rel | con) && !any(rel & con))) {
            next
          }
          k <- sum(con) + 1
          if (k == 2) {
            # one conflict: g # h, and f the third feature
            gh <- pr[, con]
            f <- setdiff(tr, gh)
            # not a common requirement: some feature would be dead
            if (!(dep_m[gh[1], f] && dep_m[gh[2], f])) k <- 5
          }
          out[k] <- out[k] + 1
        }
      }
      out
    }
    for (trial in 1:5) {
      n <- 9
      dep_m <- matrix(FALSE, n, n)
      dep_m[upper.tri(dep_m)] <- runif(n * (n - 1) / 2) < 0.25
      conf_m <- matrix(FALSE, n, n)
      conf_m[upper.tri(conf_m)] <- runif(n * (n - 1) / 2) < 0.25 &
        !dep_m[upper.tri(dep_m)]
      conf_m <- conf_m | t(conf_m)
      got <- .vp_triangle_counts(
        Matrix::Matrix(dep_m * 1, sparse = TRUE),
        Matrix::Matrix(conf_m * 1, sparse = TRUE)
      )
      check(
        paste("triangle counts", trial, "= brute force over every triple"),
        all(got == brute_triangles(dep_m, conf_m))
      )
    }

    # --- triangle significance
    for (n in c("miband3", "miband8", "uclibc")) {
      m <- models[[n]]
      ts <- vp_triangle_significance(m, runs = 30)
      check(
        paste0(n, ": observed triangles = vp_triangles on the minimal form"),
        all(ts$observed == vp_triangles(m, minimal = TRUE)$count)
      )
      check(
        paste0(
          n,
          ": shares between 0 and 1, every shuffle kept or fewer, z consistent"
        ),
        all(
          ts$p_more >= 0 & ts$p_more <= 1 & ts$p_fewer >= 0 & ts$p_fewer <= 1
        ) &&
          attr(ts, "runs") <= 30 &&
          attr(ts, "runs") > 0 &&
          all(
            is.na(ts$z) |
              abs(ts$z - (ts$observed - ts$random_mean) / ts$random_sd) < 1e-9
          )
      )
      check(
        paste0(n, ": the same seed gives the same answer"),
        identical(ts, vp_triangle_significance(m, runs = 30))
      )
    }
    alt <- model_from_links(
      c("p", "a", "b", "c", "q", "x", "y"),
      data.frame(from = c("a", "b", "c", "x"), to = c("p", "p", "p", "q")),
      data.frame(from = c("a", "a", "b"), to = c("b", "c", "c")),
      name = "alt"
    )
    ta <- vp_triangle_significance(alt, runs = 50)
    check(
      paste0(
        "by hand: three alternatives under one parent are 3 triangles 'one ",
        "conflict' and 1 'three conflicts'"
      ),
      ta$observed[ta$kind == "one conflict"] == 3 &&
        ta$observed[ta$kind == "three conflicts"] == 1
    )

    # --- communities over several graphs
    m3 <- models$miband3
    check(
      "communities: the default is the skeleton alone",
      identical(vp_communities(m3), vp_communities(m3, graphs = "requires"))
    )
    ca <- vp_communities(m3, graphs = c("requires", "excludes", "atleastone"))
    check(
      "communities with all graphs: BT40 joins the screen (its opposite)",
      ca$community[ca$feature == "BT40"] == ca$community[ca$feature == "Screen"]
    )
    g_und <- local({
      mm <- .vp_merged(m3)
      l <- dplyr::bind_rows(
        vp_skeleton(m3)[, c("from", "to")],
        vp_primitive_conflicts(m3)[, c("from", "to")],
        vp_primitive_atleastone(m3)
      )
      igraph::simplify(igraph::graph_from_data_frame(
        l,
        directed = FALSE,
        vertices = mm$nodes
      ))
    })
    memb <- ca$community[match(igraph::V(g_und)$name, ca$feature)]
    check(
      paste0(
        "communities with all graphs: the modularity is that of the split on ",
        "the union graph"
      ),
      abs(attr(ca, "modularity") - igraph::modularity(g_und, memb)) < 1e-9
    )
    check(
      "communities: one graph alone, the conflicts",
      nrow(vp_communities(m3, graphs = "excludes")) == nrow(vp_communities(m3))
    )
    check(
      "communities: the at-least-one graph without --or-graph is an error",
      fails_with(
        vp_communities(
          model_from_links(
            c("a", "b"),
            data.frame(from = "a", to = "b"),
            name = "noalo2"
          ),
          graphs = "atleastone"
        ),
        "or-graph|at-least-one"
      )
    )

    # --- baseline on the order-keeping shuffle
    bl <- vp_baseline(m3, runs = 40)
    check(
      paste0(
        paste0(
          "baseline: every shuffle kept, each implies at least the arrows of ",
          "the "
        ),
        "skeleton, observed values unchanged"
      ),
      nrow(bl) == 40 &&
        all(bl$arrows >= nrow(vp_skeleton(m3))) &&
        attr(bl, "observed")[["arrows"]] == nrow(.vp_merged(m3)$requires)
    )
    check(
      "baseline: works where cycles used to throw every shuffle away (uClibc)",
      nrow(vp_baseline(models$uclibc, runs = 10)) == 10
    )
  }
)
