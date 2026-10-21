test_that(
  paste0(
    "The graph algorithms against brute force: skeleton, primitive links, ",
    "levels, depth, width and chains, centralities,"
  ),
  {
    # ==========================================================================
    # The graph algorithms against brute force: skeleton, primitive links,
    # levels, depth, width and chains, centralities, triangles, parts and cuts;
    # on every fixture and on graphs written by hand whose answers are known.
    # ==========================================================================
    section("graphs: brute force on every fixture")

    closure <- function(nodes, arcs) {
      # reachability matrix (without the diagonal) of a directed graph
      n <- length(nodes)
      imm <- matrix(FALSE, n, n, dimnames = list(nodes, nodes))
      if (nrow(arcs)) {
        imm[cbind(match(arcs$from, nodes), match(arcs$to, nodes))] <- TRUE
      }
      for (k in seq_len(n)) {
        imm <- imm | outer(imm[, k], imm[k, ], `&`)
      }
      diag(imm) <- FALSE
      imm
    }
    distances_bf <- function(nodes, arcs) {
      # shortest numbers of steps, Inf when unreachable (BFS from each node)
      n <- length(nodes)
      dm <- matrix(Inf, n, n, dimnames = list(nodes, nodes))
      diag(dm) <- 0
      out <- split(
        match(arcs$to, nodes),
        factor(match(arcs$from, nodes), levels = seq_len(n))
      )
      for (s in seq_len(n)) {
        front <- s
        d <- 0
        while (length(front)) {
          d <- d + 1
          nxt <- unique(unlist(out[front]))
          nxt <- nxt[dm[s, nxt] == Inf]
          dm[s, nxt] <- d
          front <- nxt
        }
      }
      dm
    }
    betweenness_bf <- function(nodes, arcs) {
      # sum over s, t of the share of shortest chains through v
      dm <- distances_bf(nodes, arcs)
      n <- length(nodes)
      alo_m <- matrix(FALSE, n, n)
      if (nrow(arcs)) {
        alo_m[cbind(match(arcs$from, nodes), match(arcs$to, nodes))] <- TRUE
      }
      sigma <- matrix(0, n, n)
      diag(sigma) <- 1
      for (s in seq_len(n)) {
        for (d in seq_len(max(c(0, dm[s, is.finite(dm[s, ])])))) {
          for (t in which(dm[s, ] == d)) {
            sigma[s, t] <- sum(sigma[s, which(dm[s, ] == d - 1 & alo_m[, t])])
          }
        }
      }
      b <- numeric(n)
      for (s in seq_len(n)) {
        for (t in seq_len(n)) {
          if (s != t && is.finite(dm[s, t])) {
            for (v in seq_len(n)) {
              if (v != s && v != t && dm[s, v] + dm[v, t] == dm[s, t]) {
                b[v] <- b[v] + sigma[s, v] * sigma[v, t] / sigma[s, t]
              }
            }
          }
        }
      }
      setNames(b, nodes)
    }

    for (n in pick(names(models))) {
      m <- models[[n]]
      label <- function(what) paste0(n, ": ", what)
      mm <- .vp_merged(m)
      imm <- mm$nodes
      if (length(imm) == 0) {
        check(
          label("functions run on a model with no variable feature"),
          is.data.frame(vp_feature_table(m)) &&
            vp_depth(m) == 0 &&
            nrow(vp_skeleton(m)) == 0 &&
            is.data.frame(vp_summary(m))
        )
        next
      }
      skel <- vp_skeleton(m)
      full <- closure(imm, mm$requires)
      check(
        label(
          paste0(
            "the closure of the skeleton is the requires graph (atomic sets ",
            "merged)"
          )
        ),
        identical(closure(imm, skel), full)
      )
      check(
        label("no arrow of the skeleton follows from the others"),
        all(vapply(
          seq_len(nrow(skel)),
          function(k) !closure(imm, skel[-k, ])[skel$from[k], skel$to[k]],
          TRUE
        ))
      )
      ir <- vp_implied_requires(m)
      check(
        label(
          paste0(
            "implied requirements: not in the skeleton, and through a true ",
            "middle feature"
          )
        ),
        !any(paste(ir$from, ir$to) %in% paste(skel$from, skel$to)) &&
          all(full[cbind(ir$from, ir$via)] & full[cbind(ir$via, ir$to)])
      )
      # primitive conflicts: inherited downwards, they give back every conflict;
      # none follows from another
      prim <- vp_primitive_conflicts(m)
      down <- function(x) c(x, imm[full[, x]])
      up <- function(x) c(x, imm[full[x, ]])
      rebuilt <- unique(unlist(lapply(seq_len(nrow(prim)), function(k) {
        a <- down(prim$from[k])
        b <- down(prim$to[k])
        g <- expand.grid(a, b, stringsAsFactors = FALSE)
        paste(pmin(g[, 1], g[, 2]), pmax(g[, 1], g[, 2]), sep = "\t")
      })))
      check(
        label("primitive conflicts, inherited downwards, give every conflict"),
        setequal(rebuilt, keys(mm$excludes, TRUE))
      )
      check(
        label(
          paste0(
            paste0(
              "reach of a primitive conflict = (dependants of one end + 1) x ",
              "(of "
            ),
            "the other + 1)"
          )
        ),
        all(
          prim$reach ==
            vapply(
              seq_len(nrow(prim)),
              function(k) length(down(prim$from[k])) * length(down(prim$to[k])),
              0
            )
        )
      )
      if (!is.null(m$atleastone)) {
        pa <- vp_primitive_atleastone(m)
        rebuilt <- unique(unlist(lapply(seq_len(nrow(pa)), function(k) {
          g <- expand.grid(
            up(pa$from[k]),
            up(pa$to[k]),
            stringsAsFactors = FALSE
          )
          paste(pmin(g[, 1], g[, 2]), pmax(g[, 1], g[, 2]), sep = "\t")
        })))
        check(
          label(
            "primitive at-least-one lines, inherited upwards, give every line"
          ),
          setequal(rebuilt, keys(mm$atleastone, TRUE))
        )
      }
      # levels and depth
      lv <- setNames(vp_levels(m)$level, vp_levels(m)$feature)
      okl <- all(vapply(
        imm,
        function(f) {
          nx <- skel$to[skel$from == f]
          if (!length(nx)) lv[[f]] == 0 else lv[[f]] == 1 + max(lv[nx])
        },
        TRUE
      ))
      check(
        label(
          paste0(
            "level = 0 for no requirement, else 1 + the highest level of the ",
            "direct requirements"
          )
        ),
        okl
      )
      longest <- local({
        memo <- setNames(rep(NA_real_, length(imm)), imm)
        f <- function(v) {
          if (!is.na(memo[v])) {
            return(memo[v])
          }
          nx <- skel$to[skel$from == v]
          r <- if (!length(nx)) 1 else 1 + max(vapply(nx, f, 0))
          memo[v] <<- r
          r
        }
        max(vapply(imm, f, 0))
      })
      check(
        label("depth = number of features of the longest chain (by search)"),
        vp_depth(m) == longest
      )
      ch <- vp_longest_chain(m)
      check(
        label(
          "the longest chain is a chain of the skeleton, of depth features"
        ),
        nrow(ch) == vp_depth(m) &&
          (nrow(ch) < 2 ||
            all(
              paste(head(ch$feature, -1), ch$feature[-1]) %in%
                paste(skel$from, skel$to)
            ))
      )
      # width and chains (Dilworth): an antichain and a chain cover of the same
      # size certify each other
      w_mat <- vp_largest_unrelated_set(m)$feature
      conf_m <- vp_chains(m)
      check(
        label("the largest unrelated set has no requirement inside"),
        !any(full[w_mat, w_mat])
      )
      check(
        label("the chains cover every node once, and each is a chain"),
        setequal(conf_m$feature, imm) &&
          !anyDuplicated(conf_m$feature) &&
          all(vapply(
            split(conf_m$feature, conf_m$chain),
            function(c) length(c) < 2 || all(full[cbind(head(c, -1), c[-1])]),
            TRUE
          ))
      )
      check(
        label("width = size of the antichain = number of chains (Dilworth)"),
        vp_width(m) == length(w_mat) &&
          length(w_mat) == length(unique(conf_m$chain))
      )
      check(
        label("foundations need nothing, leaves are needed by nothing"),
        setequal(vp_foundations(m)$feature, imm[rowSums(full) == 0]) &&
          setequal(vp_leaves(m)$feature, imm[colSums(full) == 0])
      )
      # centralities on the skeleton
      ft <- vp_feature_table(m)
      rep <- .vp_representative(m)
      bt <- betweenness_bf(imm, skel)
      check(
        label(
          paste0(
            "betweenness = brute-force count of shortest chains through each ",
            "feature"
          )
        ),
        isTRUE(all.equal(unname(ft$betweenness), unname(bt[rep[ft$feature]])))
      )
      dm <- distances_bf(imm, skel)
      co <- vapply(
        imm,
        function(f) {
          d <- dm[f, -match(f, imm)]
          d <- d[is.finite(d)]
          if (!length(d)) NA else length(d) / sum(d)
        },
        0
      )
      ci <- vapply(
        imm,
        function(f) {
          d <- dm[-match(f, imm), f]
          d <- d[is.finite(d)]
          if (!length(d)) NA else length(d) / sum(d)
        },
        0
      )
      hm <- vapply(
        imm,
        function(f) {
          d <- dm[f, -match(f, imm)]
          sum(1 / d)
        },
        0
      )
      check(
        label(
          "closeness out, closeness in and harmonic centrality = brute force"
        ),
        isTRUE(all.equal(
          unname(ft$closeness_out),
          unname(co[rep[ft$feature]])
        )) &&
          isTRUE(all.equal(
            unname(ft$closeness_in),
            unname(ci[rep[ft$feature]])
          )) &&
          isTRUE(all.equal(unname(ft$harmonic), unname(hm[rep[ft$feature]])))
      )
      check(
        label("direct counts = arrows of the skeleton"),
        all(
          ft$direct_requires ==
            vapply(rep[ft$feature], function(r) sum(skel$from == r), 0)
        ) &&
          all(
            ft$direct_required_by ==
              vapply(rep[ft$feature], function(r) sum(skel$to == r), 0)
          )
      )
      # triangles on the merged graphs
      dg <- matrix(FALSE, length(imm), length(imm), dimnames = list(imm, imm))
      dg[cbind(mm$requires$from, mm$requires$to)] <- TRUE
      conf_g <- matrix(
        FALSE,
        length(imm),
        length(imm),
        dimnames = list(imm, imm)
      )
      if (nrow(mm$excludes)) {
        conf_g[cbind(mm$excludes$from, mm$excludes$to)] <- TRUE
        conf_g <- conf_g | t(conf_g)
      }
      pg <- dg | t(dg)
      cnt <- c(0, 0, 0, 0)
      if (length(imm) >= 3) {
        for (tr in asplit(utils::combn(length(imm), 3), 2)) {
          i <- tr[1]
          j <- tr[2]
          k <- tr[3]
          e <- c(
            pg[i, j] || conf_g[i, j],
            pg[j, k] || conf_g[j, k],
            pg[i, k] || conf_g[i, k]
          )
          if (all(e)) {
            nc <- conf_g[i, j] + conf_g[j, k] + conf_g[i, k]
            cnt[nc + 1] <- cnt[nc + 1] + 1
          }
        }
      }
      check(
        label(
          "the four kinds of triangle = brute-force count over all triples"
        ),
        all(vp_triangles(m)$count[1:4] == cnt)
      )
      check(
        label("no feature requires two features that exclude each other"),
        vp_triangles(m)$count[5] == 0
      )
      # parts and cuts
      links <- dplyr::bind_rows(
        skel,
        vp_primitive_conflicts(m)[, c("from", "to")],
        if (!is.null(m$atleastone)) vp_primitive_atleastone(m)
      )
      ncomp <- function(nodes, l) {
        l <- l[l$from %in% nodes & l$to %in% nodes, ]
        igraph::components(igraph::graph_from_data_frame(
          l,
          directed = FALSE,
          vertices = nodes
        ))$no
      }
      cf <- vp_cut_features(m)
      base <- ncomp(imm, links)
      check(
        label(
          paste0(
            "removing a cut feature splits its part into the number of pieces ",
            "reported"
          )
        ),
        all(vapply(
          seq_len(nrow(cf)),
          function(k) {
            ncomp(setdiff(imm, cf$feature[k]), links) == base - 1 + cf$pieces[k]
          },
          TRUE
        ))
      )
      noncut <- setdiff(imm, cf$feature)
      check(
        label("removing any other feature splits nothing"),
        all(vapply(
          noncut,
          function(f) ncomp(setdiff(imm, f), links) <= base,
          TRUE
        ))
      )
      # degree distribution, Gini, feature tree, communities, coreness,
      # robustness
      dd <- vp_degree_distribution(m, "requires")
      check(
        label("degree distribution sums to the number of features"),
        sum(dd$features) == nrow(ft) &&
          sum(dd$degree * dd$features) == nrow(m$requires)
      )
      tr <- vp_feature_tree(m)
      check(
        label(
          paste0(
            "the rebuilt tree: each parent is a direct requirement, the ",
            "cross-tree ones are the others"
          )
        ),
        all(vapply(
          seq_len(nrow(tr)),
          function(k) {
            cand <- skel$to[skel$from == tr$feature[k]]
            if (is.na(tr$parent[k])) {
              length(cand) == 0
            } else {
              tr$parent[k] %in% cand && tr$candidates[k] == length(cand)
            }
          },
          TRUE
        ))
      )
      c1 <- vp_communities(m, seed = 3)
      c2 <- vp_communities(m, seed = 3)
      check(
        label(
          paste0(
            "communities: every feature in one community, the same with the ",
            "same seed"
          )
        ),
        setequal(c1$feature, ft$feature) &&
          identical(c1, c2) &&
          (if (nrow(skel) == 0) {
            is.na(attr(c1, "modularity"))
          } else {
            attr(c1, "modularity") >= -0.5 && attr(c1, "modularity") <= 1
          })
      )
      if (nrow(m$excludes)) {
        vn <- vp_features(m) |>
          dplyr::filter(status == "variable") |>
          dplyr::pull(feature)
        cf_m <- matrix(FALSE, length(vn), length(vn), dimnames = list(vn, vn))
        cf_m[cbind(m$excludes$from, m$excludes$to)] <- TRUE
        cf_m <- cf_m | t(cf_m)
        core_bf <- setNames(rep(0, length(vn)), vn)
        left <- vn
        level <- 0
        while (length(left)) {
          deg <- rowSums(cf_m[left, left, drop = FALSE])
          level <- max(level, min(deg))
          rm <- left[deg <= level]
          core_bf[rm] <- level
          left <- setdiff(left, rm)
        }
        co2 <- vp_coreness(m)
        check(
          label("coreness of the conflicts = brute-force peeling"),
          all(setNames(co2$coreness, co2$feature)[vn] == core_bf[vn])
        )
      }
      gh <- vp_genuine_hubs(m, top = 50)
      okh <- all(vapply(
        seq_len(nrow(gh)),
        function(k) {
          q <- gh$feature[k]
          users <- imm[full[, q]]
          shares <- vapply(
            users,
            function(p) {
              o <- setdiff(users, p)
              if (!length(o)) 1 else mean(full[o, p])
            },
            0
          )
          if (gh$genuine[k]) {
            all(shares < 0.9)
          } else {
            full[gh$dominated_by[k], q] &&
              shares[[gh$dominated_by[k]]] >= 0.9 &&
              abs(gh$share_through[k] - shares[[gh$dominated_by[k]]]) < 1e-12
          }
        },
        TRUE
      ))
      check(
        label(
          paste0(
            "genuine hubs: a dominator requires the hub and 90 % of its other ",
            "dependants require the dominator; a genuine hub has none"
          )
        ),
        okh
      )
      rb <- vp_robustness(m, steps = min(3, length(imm) - 1))
      check(
        label(
          paste0(
            "robustness: links and the largest piece never grow as features ",
            "are removed"
          )
        ),
        all(diff(rb$links_left) <= 0) && all(diff(rb$largest_piece) <= 0)
      )
    }

    section("graphs: hand-made cases with known answers")
    diamond <- model_from_links(
      c("a", "b", "c", "d"),
      requires = data.frame(
        from = c("a", "a", "b", "c", "a"),
        to = c("b", "c", "d", "d", "d")
      ),
      excludes = data.frame(from = character(0), to = character(0)),
      name = "diamond"
    )
    ft <- vp_feature_table(diamond)
    check(
      paste0(
        paste0(
          "diamond: two shortest chains from a to d share the point: ",
          "betweenness "
        ),
        "0.5 for b and c"
      ),
      all(ft$betweenness == c(0, 0.5, 0.5, 0))
    )
    check(
      "diamond: skeleton drops a -> d",
      setequal(keys(vp_skeleton(diamond)), c("a\tb", "a\tc", "b\td", "c\td"))
    )
    check(
      "diamond: depth 3, width 2",
      vp_depth(diamond) == 3 && vp_width(diamond) == 2
    )
    check(
      "diamond: harmonic of a = 1 + 1 + 1/2, closeness out = 3/4",
      isTRUE(all.equal(ft$harmonic[1], 2.5)) &&
        isTRUE(all.equal(ft$closeness_out[1], 0.75))
    )
    cyc <- model_from_links(
      c("p", "q", "r"),
      requires = data.frame(
        from = c("p", "q", "p", "q", "r", "r"),
        to = c("q", "p", "r", "r", "p", "q")
      ),
      excludes = data.frame(from = character(0), to = character(0)),
      name = "cycle"
    )
    check(
      paste0(
        "three features that require each other: one atomic set computed from ",
        "the graph"
      ),
      nrow(vp_atomic_sets(cyc)) == 3 &&
        length(unique(vp_atomic_sets(cyc)$set)) == 1 &&
        vp_depth(cyc) == 1
    )
    check(
      "Gini: 0 for equal values, (n-1)/n when one has everything",
      vp_gini(c(3, 3, 3)) == 0 &&
        isTRUE(all.equal(vp_gini(c(0, 0, 0, 5)), 3 / 4)) &&
        vp_gini(numeric(0)) == 0
    )
    quoted <- model_from_links(
      c('Say "hi"', "with space", "naïve"),
      requires = data.frame(from = 'Say "hi"', to = "with space"),
      excludes = data.frame(from = "with space", to = "naïve"),
      name = "names"
    )
    check(
      "names with quotes, spaces and accents are read back exactly",
      setequal(
        vp_features(quoted)$feature,
        c('Say "hi"', "with space", "naïve")
      ) &&
        vp_requirements(quoted, 'Say "hi"')$feature == "with space"
    )
  }
)
