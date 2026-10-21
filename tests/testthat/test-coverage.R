test_that(
  paste0(
    "Every function that the other files test little, against brute force ",
    "computed from the valid configurations (the"
  ),
  {
    # ==========================================================================
    # Every function that the other files test little, against brute force
    # computed from the valid configurations (the oracle), on every model whose
    # configurations can be listed: the examples and the random formulas.
    # ==========================================================================
    section(
      paste0(
        "coverage: every remaining function against brute force, on every ",
        "model of the oracle"
      )
    )
    withr::local_seed(99)
    mclique <- function(alo_m) {
      # largest clique of a logical matrix, by branch and bound
      best <- integer(0)
      grow <- function(ch, cand) {
        if (length(ch) + length(cand) <= length(best)) {
          return(invisible())
        }
        if (!length(cand)) {
          best <<- ch
          return(invisible())
        }
        for (k in seq_along(cand)) {
          if (length(ch) + length(cand) - k + 1 <= length(best)) {
            break
          }
          v <- cand[k]
          rest <- cand[-(1:k)]
          grow(c(ch, v), rest[alo_m[v, rest]])
        }
      }
      grow(integer(0), seq_len(nrow(alo_m)))
      best
    }
    same_set <- function(a, b) setequal(a, b) && !anyDuplicated(a)

    for (n in pick(names(oracle))) {
      m <- models[[n]]
      o <- oracle[[n]]
      x_mat <- o$T$X
      vars <- o$V
      nv <- length(vars)
      label <- function(w) paste0(n, ": ", w)
      if (nv == 0) {
        next
      }
      imm <- !o$T$tf
      diag(imm) <- FALSE # R[a, b]: a requires b
      arcs <- !o$T$tt
      diag(arcs) <- FALSE # E[a, b]: a excludes b
      alo_m <- !o$T$ff
      diag(alo_m) <- FALSE # A[a, b]: every product has a or b
      cls <- match(
        apply(x_mat, 2, paste, collapse = ""),
        unique(apply(x_mat, 2, paste, collapse = ""))
      ) # atomic class of each feature
      names(cls) <- vars
      strict <- imm & !t(imm) # requires, between different classes

      # --- the lists of one feature, and the igraph objects
      ok <- all(vapply(
        vars,
        function(f) {
          same_set(vp_required_by(m, f)$feature, vars[imm[, f]]) &&
            same_set(vp_requirements(m, f)$feature, vars[imm[f, ]]) &&
            same_set(vp_conflicts_of(m, f)$feature, vars[arcs[f, ]]) &&
            same_set(vp_atleastone_of(m, f)$feature, vars[alo_m[f, ]])
        },
        TRUE
      ))
      check(
        label(
          paste0(
            "required_by, requirements, conflicts_of, atleastone_of = the ",
            "configurations, for every feature"
          )
        ),
        ok
      )
      ig <- vp_igraph(m, "requires")
      ie <- vp_igraph(m, "excludes")
      check(
        label("vp_igraph: the vertices are the features, the edges the links"),
        setequal(igraph::V(ig)$name, vars) &&
          igraph::ecount(ig) == sum(imm) &&
          igraph::ecount(ie) == sum(arcs) / 2 &&
          igraph::is_directed(ig) &&
          !igraph::is_directed(ie)
      )

      # --- foundations and leaves, up-sets, down-sets, common requirements and
      # dependants
      found <- unique(cls[vars[rowSums(strict) == 0]])
      leaf <- unique(cls[vars[colSums(strict) == 0]])
      check(
        label(
          paste0(
            "foundations and leaves: one per atomic set that requires nothing ",
            "/ that nothing requires"
          )
        ),
        same_set(cls[vp_foundations(m)$feature], found) &&
          same_set(cls[vp_leaves(m)$feature], leaf)
      )
      fs <- sample(vars, min(2, nv))
      up <- vp_upset(m, fs)
      dn <- vp_downset(m, fs)
      check(
        label(
          paste0(
            "up-set and down-set: the features and everything they require / ",
            "that requires them"
          )
        ),
        same_set(
          up$feature,
          unique(c(fs, vars[colSums(imm[fs, , drop = FALSE]) > 0]))
        ) &&
          same_set(
            dn$feature,
            unique(c(fs, vars[rowSums(imm[, fs, drop = FALSE]) > 0]))
          ) &&
          all(
            up$brought_by[up$feature %in% fs] == up$feature[up$feature %in% fs]
          ) &&
          all(
            dn$depends_on[dn$feature %in% fs] == dn$feature[dn$feature %in% fs]
          ) &&
          all(vapply(
            seq_len(nrow(up)),
            function(i) {
              up$feature[i] == up$brought_by[i] ||
                imm[up$brought_by[i], up$feature[i]]
            },
            TRUE
          ))
      )
      if (nv >= 2) {
        ab <- sample(vars, 2)
        check(
          label("common requirements and common dependants of two features"),
          same_set(
            vp_common_requirements(m, ab[1], ab[2])$feature,
            vars[imm[ab[1], ] & imm[ab[2], ]]
          ) &&
            same_set(
              vp_common_dependants(m, ab[1], ab[2])$feature,
              vars[imm[, ab[1]] & imm[, ab[2]]]
            )
        )
      }

      # --- depth, rounds, longest chain, width and largest unrelated set, by
      # brute force on the classes
      kern_m <- max(cls)
      sc <- matrix(FALSE, kern_m, kern_m)
      for (a in vars) {
        for (b in vars) {
          if (strict[a, b]) sc[cls[a], cls[b]] <- TRUE
        }
      }
      lev <- rep(NA_integer_, kern_m)
      chg <- function(c) {
        if (is.na(lev[c])) {
          nb <- which(sc[c, ])
          lev[c] <<- if (length(nb)) 1L + max(vapply(nb, chg, 0L)) else 0L
        }
        lev[c]
      }
      for (c in seq_len(kern_m)) {
        chg(c)
      }
      rd <- vp_rounds(m)
      check(
        label(
          paste0(
            "rounds: one round per level + 1; a feature always after what it ",
            "requires; as many rounds as the depth"
          )
        ),
        all(rd$round == lev[cls[rd$feature]] + 1) &&
          max(rd$round) == vp_depth(m) &&
          vp_depth(m) == max(lev) + 1 &&
          all(vapply(
            seq_len(nrow(rd)),
            function(i) {
              all(
                rd$round[i] >
                  rd$round[match(vars[strict[rd$feature[i], ]], rd$feature)]
              )
            },
            TRUE
          ))
      )
      lc <- vp_longest_chain(m)$feature
      check(
        label(
          paste0(
            "longest chain: each feature requires the next, and it is as long ",
            "as the depth"
          )
        ),
        length(lc) == vp_depth(m) &&
          (length(lc) < 2 ||
            all(vapply(
              seq_len(length(lc) - 1),
              function(i) strict[lc[i], lc[i + 1]],
              TRUE
            )))
      )
      inc <- !(sc | t(sc))
      diag(inc) <- TRUE
      w <- length(mclique(inc))
      us <- vp_largest_unrelated_set(m)$feature
      check(
        label(
          paste0(
            paste0(
              "width = the largest set of classes none of which requires ",
              "another "
            ),
            "(brute force), and the set is one"
          )
        ),
        vp_width(m) == w &&
          length(us) == w &&
          all(!strict[us, us]) &&
          !anyDuplicated(cls[us])
      )

      # --- compatible set, colouring, alternative groups
      cs <- vp_largest_compatible_set(m)$feature
      free_of_conflicts <- !arcs
      diag(free_of_conflicts) <- TRUE
      check(
        label(
          paste0(
            "largest compatible set: no conflict inside, as large as the ",
            "brute-force largest"
          )
        ),
        all(!arcs[cs, cs]) && length(cs) == length(mclique(free_of_conflicts))
      )
      co <- vp_colouring(m)
      check(
        label(
          paste0(
            "colouring: no two features of one colour exclude each other; at ",
            "least as many colours as the largest group of alternatives"
          )
        ),
        all(vapply(
          seq_len(nrow(co)),
          function(i) {
            !any(arcs[co$feature[i], co$feature[co$colour == co$colour[i]]])
          },
          TRUE
        )) &&
          max(co$colour) >= length(mclique(arcs | diag(nv) == 1))
      )

      # --- degree distribution, warning zone, most decisive, genuine hubs
      dd <- vp_degree_distribution(m, "requires")
      de <- vp_degree_distribution(m, "excludes")
      dout <- vp_degree_distribution(m, "requires", "out")
      check(
        label(
          paste0(
            "degree distributions: one entry per feature, and the degrees add ",
            "up to the links"
          )
        ),
        sum(dd$features) == nv &&
          sum(dd$degree * dd$features) == sum(imm) &&
          sum(de$degree * de$features) == sum(arcs) &&
          sum(dout$degree * dout$features) == sum(imm)
      )
      ft <- vp_feature_table(m)
      hi <- function(x, top = 0.1) {
        x >= stats::quantile(x, 1 - top, names = FALSE) & x > 0
      }
      check(
        label(
          paste0(
            "warning zone = the features in the top tenth of both required_by ",
            "and requires"
          )
        ),
        same_set(
          vp_warning_zone(m)$feature,
          ft$feature[hi(ft$required_by) & hi(ft$requires)]
        ) &&
          same_set(
            vp_warning_zone(m, top = 0.5)$feature,
            ft$feature[hi(ft$required_by, 0.5) & hi(ft$requires, 0.5)]
          )
      )
      md <- vp_most_decisive(m, 3)
      check(
        label(
          "most decisive: the largest decision powers, in decreasing order"
        ),
        nrow(md) == min(3, nv) &&
          !is.unsorted(rev(md$decision_power)) &&
          all(
            md$decision_power >=
              max(c(
                -Inf,
                sort(ft$decision_power, decreasing = TRUE)[-seq_len(nrow(md))]
              ))
          )
      )
      gh <- vp_genuine_hubs(m, top = 5)
      okh <- all(vapply(
        seq_len(nrow(gh)),
        function(i) {
          q <- gh$feature[i]
          users <- unique(cls[vars[strict[, q]]])
          rep_of <- function(c) vars[cls == c][1]
          if (gh$required_by[i] != length(users)) {
            return(FALSE)
          }
          sh <- vapply(
            users,
            function(p) {
              others <- setdiff(users, p)
              if (!length(others)) {
                1
              } else {
                mean(vapply(
                  others,
                  function(o) strict[rep_of(o), rep_of(p)],
                  TRUE
                ))
              }
            },
            0
          )
          if (gh$genuine[i]) {
            all(sh < 0.9)
          } else {
            abs(gh$share_through[i] - max(sh)) < 1e-12 && max(sh) >= 0.9
          }
        },
        TRUE
      ))
      check(
        label(
          paste0(
            "genuine hubs: required_by and domination recomputed from the ",
            "configurations"
          )
        ),
        okh
      )

      # --- similar features and odd ones
      if (nv >= 2) {
        f <- sample(vars, 1)
        sf <- vp_similar_features(m, f)
        jac <- vapply(
          sf$feature,
          function(g) {
            u <- sum(arcs[f, ] | arcs[g, ])
            if (u == 0) 0 else sum(arcs[f, ] & arcs[g, ]) / u
          },
          0
        )
        check(
          label(
            paste0(
              "similar features: the Jaccard index of their conflicts, the ",
              "most similar first"
            )
          ),
          all(abs(sf$similarity - jac) < 1e-12) &&
            !is.unsorted(rev(sf$similarity)) &&
            !(f %in% sf$feature)
        )
      }
      oo <- vp_odd_ones(m)
      okodd <- all(vapply(
        seq_len(nrow(oo)),
        function(i) {
          a <- oo$feature_1[i]
          b <- oo$feature_2[i]
          u <- sum(arcs[a, ] | arcs[b, ])
          ra <- setdiff(vars[imm[a, ]], b)
          rb <- setdiff(vars[imm[b, ]], a)
          u > 0 &&
            sum(arcs[a, ] & arcs[b, ]) / u >= 0.6 &&
            cls[a] != cls[b] &&
            !setequal(ra, rb)
        },
        TRUE
      ))
      check(
        label(
          paste0(
            "odd ones: alike in conflicts (Jaccard >= 0.6), different in ",
            "requirements"
          )
        ),
        okodd
      )

      # --- redundant candidates
      if (nv >= 2) {
        pairs <- unique(t(replicate(8, sample(vars, 2))))
        wr <- tibble::tibble(from = pairs[, 1], to = pairs[, 2])
        rc <- vp_redundant_candidates(m, wr)
        via_chain <- function(a, b) {
          any(vapply(
            vars,
            function(c) {
              cls[c] != cls[a] &&
                cls[c] != cls[b] &&
                strict[a, c] &&
                strict[c, b]
            },
            TRUE
          ))
        }
        okr <- all(vapply(
          seq_len(nrow(rc)),
          function(i) {
            a <- rc$from[i]
            b <- rc$to[i]
            if (cls[a] == cls[b]) {
              return(isTRUE(rc$in_graphs[i]) && !rc$redundant[i])
            }
            rc$in_graphs[i] == imm[a, b] &&
              rc$redundant[i] == (imm[a, b] && via_chain(a, b))
          },
          TRUE
        ))
        check(
          label(
            paste0(
              "redundant candidates: held = the configurations; redundant = ",
              "held and given by a chain through another class"
            )
          ),
          okr
        )
      }

      # --- groupings and feature groups
      g4 <- vp_feature_groups(m, groups = min(4, nv))
      check(
        label(
          paste0(
            "feature groups: every feature in one group, at most the number ",
            "asked, the same answer twice"
          )
        ),
        same_set(g4$feature, ft$feature) &&
          length(unique(g4$group)) <= min(4, nv) &&
          identical(g4, vp_feature_groups(m, groups = min(4, nv)))
      )
      if (nv >= 3) {
        com <- vp_communities(m)
        relab <- dplyr::mutate(com, community = 100 - community)
        check(
          label(
            paste0(
              "compare groupings: a grouping against itself or a relabelling ",
              "of it gives 1"
            )
          ),
          abs(vp_compare_groupings(com, com) - 1) < 1e-12 &&
            abs(vp_compare_groupings(com, relab) - 1) < 1e-12
        )
      }
    }

    section("coverage: power law, top movers, feature states")
    pl <- suppressWarnings(vp_power_law(models$uclibc))
    check(
      paste0(
        "power law: one row, verdict consistent with the p-value, the same ",
        "seed gives the same answer"
      ),
      nrow(pl) == 1 &&
        pl$verdict ==
          ifelse(
            pl$p_value < 0.1,
            "not a power law",
            "a power law cannot be rejected"
          ) &&
        identical(pl, suppressWarnings(vp_power_law(models$uclibc)))
    )
    check(
      "power law: warns when fewer than 50 features have a degree",
      inherits(
        tryCatch(vp_power_law(models$miband3), warning = function(w) w),
        "warning"
      )
    )
    for (p in Map(c, head(gens, -1), gens[-1])) {
      a <- models[[p[1]]]
      b <- models[[p[2]]]
      ch <- vp_changed_links(a, b, "requires")
      tm <- vp_top_movers(a, b, "requires", n = 1000)
      cnt <- table(c(ch$from, ch$to))
      check(
        paste0(
          p[1],
          " -> ",
          p[2],
          paste0(
            paste0(
              ": top movers count each feature's changed links; total = ",
              "gained + "
            ),
            "lost; largest first"
          )
        ),
        all(tm$total == as.integer(cnt[tm$feature])) &&
          all(tm$total == tm$gained + tm$lost) &&
          !is.unsorted(rev(tm$total)) &&
          nrow(tm) == length(cnt)
      )
    }
    gh <- vp_read_history(
      vapply(gens, function(g) fixtures[[g]]$prefix, ""),
      versions = gens
    ) # the generations of the band
    st <- vp_feature_states(gh)
    check(
      paste0(
        "feature states: every feature in every version, with its status or ",
        "absent"
      ),
      nrow(st) ==
        length(unique(unlist(lapply(gh$model, function(x) {
          x$features$feature
        })))) *
          nrow(gh) &&
        all(vapply(
          seq_len(nrow(gh)),
          function(k) {
            s <- st[st$version == gh$version[k], ]
            f <- gh$model[[k]]$features
            all(s$state[match(f$feature, s$feature)] == f$status) &&
              all(s$state[!s$feature %in% f$feature] == "absent")
          },
          TRUE
        ))
    )
  }
)
