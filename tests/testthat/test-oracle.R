test_that(
  paste0(
    "The R functions against the oracle: the valid configurations of each ",
    "formula, enumerated in plain R."
  ),
  {
    # ==========================================================================
    # The R functions against the oracle: the valid configurations of each
    # formula, enumerated in plain R.
    # ==========================================================================
    section("oracle: what the files say, and what every inference answers")
    withr::local_seed(20261014)

    for (n in pick(names(oracle))) {
      m <- models[[n]]
      o <- oracle[[n]]
      truth_t <- o$T
      x_mat <- truth_t$X
      vars <- o$V
      nv <- length(vars)
      all <- o$all
      label <- function(what) paste0(n, ": ", what)

      # --- the files themselves (Strong4VM) against the oracle: the ground the
      # other checks stand on
      fs <- vp_features(m)
      core_truth <- colnames(all)[colSums(all) == nrow(all)]
      dead_truth <- colnames(all)[colSums(all) == 0]
      check(
        label("core features are in every configuration"),
        all(fs$feature[fs$status == "core"] %in% core_truth)
      )
      check(
        label("dead features are in no configuration"),
        all(fs$feature[fs$status == "dead"] %in% dead_truth)
      )
      check(
        label("variable features vary"),
        all(colSums(x_mat) > 0 & colSums(x_mat) < nrow(x_mat))
      )
      check(
        label("requires graph = every 'a requires b' of the configurations"),
        setequal(keys(m$requires), truth_t$requires)
      )
      check(
        label("excludes graph = every 'never both'"),
        setequal(keys(m$excludes, TRUE), truth_t$excludes)
      )
      check(
        label("at-least-one graph = every 'never neither'"),
        setequal(keys(m$atleastone, TRUE), truth_t$atleastone)
      )
      if (nv == 0) {
        skip_note(label("inferences"), "no feature can vary")
        next
      }

      # --- atomic sets and opposites
      groups <- split(
        vars,
        apply(x_mat, 2, function(x) paste(as.integer(x), collapse = ""))
      )
      groups <- unname(groups[lengths(groups) > 1])
      a <- vp_atomic_sets(m)
      got <- if (nrow(a)) unname(split(a$feature, a$set)) else list()
      check(
        label("atomic sets = features with identical columns"),
        setequal(
          vapply(got, function(g) paste(sort(g), collapse = ","), ""),
          vapply(groups, function(g) paste(sort(g), collapse = ","), "")
        )
      )
      opp_truth <- character(0)
      for (i in seq_len(nv - 1)) {
        for (j in (i + 1):nv) {
          if (all(x_mat[, i] != x_mat[, j])) {
            opp_truth <- c(
              opp_truth,
              paste(sort(vars[c(i, j)]), collapse = "\t")
            )
          }
        }
      }
      op <- vp_opposites(m)
      check(
        label("opposites = features always different"),
        setequal(
          paste(
            pmin(op$feature_1, op$feature_2),
            pmax(op$feature_1, op$feature_2),
            sep = "\t"
          ),
          opp_truth
        )
      )

      # --- pairs: exact
      ok <- TRUE
      for (i in seq_len(nv)) {
        for (j in seq_len(nv)) {
          if (i < j) {
            p <- vp_pair(m, vars[i], vars[j])
            want <- c(
              truth_t$tt[i, j],
              truth_t$tf[i, j],
              truth_t$tf[j, i],
              truth_t$ff[i, j]
            )
            if (!identical(unname(p$possible), unname(want))) {
              ok <- FALSE
              break
            }
          }
        }
      }
      check(label("vp_pair is exact for every pair of features"), ok)

      # --- wish lists: a FALSE is always right; a possible list always gets
      # TRUE; pairs are exact
      pairs <- if (nv > 1) asplit(t(utils::combn(vars, 2)), 1) else list()
      triples <- if (nv > 2) asplit(t(utils::combn(vars, 3)), 1) else list()
      if (length(triples) > 600) {
        triples <- triples[sample(length(triples), 600)]
      }
      wl <- c(
        lapply(pairs, unname),
        lapply(triples, unname),
        lapply(1:200, function(k) sample(vars, min(nv, sample(2:6, 1))))
      )
      wl <- wl[lengths(wl) > 0]
      ans <- vp_can_go_together(m, wl)
      truthw <- vapply(wl, function(w) possible(truth_t, on = w), TRUE)
      check(
        label("wish lists: every FALSE is right"),
        all(truthw[!ans$possible] == FALSE)
      )
      check(
        label("wish lists: every possible list gets TRUE"),
        all(ans$possible[truthw])
      )
      check(
        label("wish lists of two features: exact"),
        all(ans$possible[lengths(wl) == 2] == truthw[lengths(wl) == 2])
      )
      check(
        label("wish lists: a FALSE always comes with a reason"),
        all(nzchar(ans$reasons[!ans$possible]))
      )

      # --- the kernel answers wish lists as vp_can_go_together does (the recipe
      # of the user manual)
      k <- vp_kernel(m)
      kl <- vp_kernel_links(m)
      cls <- setNames(k$label, k$feature)
      kernel_yes <- function(w) {
        boxes <- unique(cls[w])
        boxes <- boxes[!boxes %in% k$label[k$trouble_free]]
        boxes <- unique(c(
          boxes,
          kl$to[kl$link == "requires" & kl$from %in% boxes]
        ))
        !any(kl$link == "excludes" & kl$from %in% boxes & kl$to %in% boxes)
      }
      check(
        label("kernel recipe = vp_can_go_together on every wish list"),
        all(vapply(wl, kernel_yes, TRUE) == ans$possible)
      )
      check(
        label("kernel classes partition the variable features"),
        setequal(k$feature, vars) && !anyDuplicated(k$feature)
      )
      tf <- k$feature[k$trouble_free]
      if (length(tf)) {
        yes <- wl[ans$possible]
        with_tf <- unlist(
          lapply(yes, function(w) lapply(tf, function(f) unique(c(w, f)))),
          recursive = FALSE
        )
        check(
          label(
            paste0(
              paste0(
                "adding a trouble-free feature never turns a 'yes' of the ",
                "graphs "
              ),
              "into a 'no'"
            )
          ),
          all(vp_can_go_together(m, with_tf)$possible)
        )
        # the graphs answer every wish list of this model right
        exact <- all(ans$possible == truthw)
        if (exact) {
          check(
            label("and, since the graphs are exact here, it is truly possible"),
            all(vapply(with_tf, function(w) possible(truth_t, on = w), TRUE))
          )
        }
      }

      # --- partial configurations (with left-out features): pairs of decisions
      # exact, a FALSE always right
      dec <- c(paste0("+", vars), paste0("-", vars))
      sel <- function(d) {
        list(
          on = sub("^\\+", "", d[startsWith(d, "+")]),
          off = sub("^-", "", d[startsWith(d, "-")])
        )
      }
      okpair <- TRUE
      oksound <- TRUE
      okcomplete <- TRUE
      dp <- utils::combn(dec, 2)
      if (ncol(dp) > 800) {
        dp <- dp[, sample(ncol(dp), 800)]
      }
      for (c in seq_len(ncol(dp))) {
        s <- sel(dp[, c])
        if (length(intersect(s$on, s$off))) {
          next
        }
        got <- vp_partial_configuration(m, s$on, s$off)$possible
        if (got != possible(truth_t, s$on, s$off)) {
          okpair <- FALSE
          break
        }
      }
      for (r in 1:150) {
        d <- sample(dec, min(length(dec), sample(3:5, 1)))
        s <- sel(d)
        if (length(intersect(s$on, s$off))) {
          next
        }
        got <- vp_partial_configuration(m, s$on, s$off)$possible
        want <- possible(truth_t, s$on, s$off)
        if (!got && want) {
          oksound <- FALSE
        }
        if (want && !got) okcomplete <- FALSE
      }
      okexpl <- TRUE
      for (r in 1:40) {
        d <- sample(dec, min(length(dec), sample(1:4, 1)))
        s <- sel(d)
        if (length(intersect(s$on, s$off))) {
          next
        }
        pc <- vp_partial_configuration(m, s$on, s$off)
        cq <- vp_consequences(m, s$on, s$off)
        both <- intersect(
          cq$feature[cq$value == "selected"],
          cq$feature[cq$value == "left out"]
        )
        tie <- function(f, v) {
          by <- cq$forced_by[cq$feature == f & cq$value == v][1]
          if (by %in% c(f, paste("not", f))) "your choice" else by
        }
        okexpl <- okexpl &&
          is.list(pc) &&
          identical(names(pc), c("possible", "explanation")) &&
          isTRUE(pc$possible == (length(both) == 0)) &&
          setequal(pc$explanation$feature, both) &&
          nrow(pc$explanation) == length(both) &&
          all(vapply(
            seq_len(nrow(pc$explanation)),
            function(k) {
              f <- pc$explanation$feature[k]
              pc$explanation$in_because[k] == tie(f, "selected") &&
                pc$explanation$out_because[k] == tie(f, "left out") &&
                startsWith(
                  pc$explanation$reason[k],
                  paste(f, "would be both in")
                )
            },
            TRUE
          ))
      }
      check(
        label(
          paste0(
            paste0(
              "partial configurations: one row of explanation per feature ",
              "forced "
            ),
            "both ways, with the decisions that force it"
          )
        ),
        okexpl
      )
      check(label("partial configurations of two decisions: exact"), okpair)
      check(label("partial configurations: every FALSE is right"), oksound)
      check(
        label("partial configurations: every possible mix gets TRUE"),
        okcomplete
      )

      # --- consequences: every forced decision holds in every configuration
      # that respects the decisions
      okc <- TRUE
      for (r in 1:60) {
        s <- sel(sample(dec, min(length(dec), sample(1:3, 1))))
        if (length(intersect(s$on, s$off)) || !possible(truth_t, s$on, s$off)) {
          next
        }
        cq <- vp_consequences(m, s$on, s$off)
        rows <- rep(TRUE, nrow(x_mat))
        for (f in s$on) {
          rows <- rows & x_mat[, f]
        }
        for (f in s$off) {
          rows <- rows & !x_mat[, f]
        }
        for (q in seq_len(nrow(cq))) {
          v <- x_mat[rows, cq$feature[q]]
          if (!all(v == (cq$value[q] == "selected"))) {
            okc <- FALSE
            break
          }
        }
      }
      check(
        label(
          paste0(
            "consequences: every forced decision holds in every matching ",
            "configuration"
          )
        ),
        okc
      )

      # --- the decision graph: every implication holds in every configuration
      dg <- vp_mig(m)
      check(
        label("decision graph: every implication holds"),
        all(vapply(
          seq_len(nrow(dg)),
          function(q) {
            all(
              x_mat[x_mat[, dg$from[q]] == dg$from_selected[q], dg$to[q]] ==
                dg$to_selected[q]
            )
          },
          TRUE
        ))
      )

      # --- counting products
      if (nv > 20) {
        skip_note(
          label("counting products"),
          paste0(
            "more than 20 features: vp_count_graph_products refuses, as ",
            "documented"
          )
        )
      } else {
        cg <- vp_count_graph_products(m)
        products_respect <- all(apply(x_mat, 1, function(r) {
          on <- vars[r]
          !any(m$requires$from %in% on & !(m$requires$to %in% on)) &&
            !any(m$excludes$from %in% on & m$excludes$to %in% on) &&
            (is.null(m$atleastone) ||
              !any(!(m$atleastone$from %in% on) & !(m$atleastone$to %in% on)))
        }))
        check(
          label("every valid configuration respects every link"),
          products_respect
        )
        check(
          label(
            paste0(
              "count of products the graphs allow: monotone, and at least the ",
              "valid ones"
            )
          ),
          cg$selections >= cg$respect_requires &&
            cg$respect_requires >= cg$and_excludes &&
            cg$and_excludes >= cg$and_atleastone &&
            cg$and_atleastone >= nrow(unique(x_mat))
        )
        ce <- vp_count_graph_products(m, products = nrow(unique(x_mat)))
        check(
          label("explained share is between 0 and 1"),
          ce$explained >= 0 &&
            ce$explained <= 1 + 1e-9 ||
            nrow(unique(x_mat)) == 2^nv
        )
      }

      # --- testing: combinations to cover = the combinations that occur; full
      # coverage by all configurations
      occur2 <- 0
      for (i in seq_len(nv - 1)) {
        for (j in (i + 1):nv) {
          occur2 <- occur2 +
            truth_t$tt[i, j] +
            truth_t$tf[i, j] +
            truth_t$tf[j, i] +
            truth_t$ff[i, j]
        }
      }
      check(
        label("combinations to cover (t = 2) = combinations that occur"),
        vp_combinations_to_cover(m, 2)$combinations == occur2
      )
      check(
        label("combinations to cover (t = 1) = 2n"),
        vp_combinations_to_cover(m, 1)$combinations == 2 * nv
      )
      sample_all <- as.data.frame(x_mat * 1L)
      cv <- vp_coverage(m, sample_all)
      check(
        label("all valid configurations cover 100 % for t = 1 and t = 2"),
        all(abs(cv$coverage - 1) < 1e-12)
      )
      check(
        label("all valid configurations leave nothing uncovered"),
        nrow(vp_uncovered(m, sample_all)) == 0
      )
      one <- sample_all[1, , drop = FALSE]
      cv1 <- vp_coverage(m, one)
      check(
        label("uncovered pairs = to cover - covered"),
        nrow(vp_uncovered(m, one)) == cv1$to_cover[2] - cv1$covered[2]
      )
      check(
        label("valid configurations break no link"),
        nrow(vp_sample_violations(m, sample_all)) == 0
      )
      if (nrow(m$requires)) {
        bad <- one
        bad[[m$requires$from[1]]] <- 1L
        bad[[m$requires$to[1]]] <- 0L
        v <- vp_sample_violations(m, bad)
        check(
          label("a configuration that breaks a requirement is reported"),
          any(v$rule == "requires")
        )
      }
      b1 <- vp_min_sample_size(m, 1)
      items <- b1$item
      in_x <- function(it) {
        f <- sub("^not ", "", it)
        if (startsWith(it, "not ")) !x_mat[, f] else x_mat[, f]
      }
      pairwise_incompatible <- function(items) {
        if (length(items) < 2) {
          return(TRUE)
        }
        cm <- utils::combn(length(items), 2)
        all(apply(cm, 2, function(p) !any(in_x(items[p[1]]) & in_x(items[p[2]]))))
      }
      check(
        label("lower bound t = 1: its items never share a configuration"),
        pairwise_incompatible(items)
      )
      pk1 <- vp_pick_sample(m, sample_all, 1)
      pk2 <- vp_pick_sample(m, sample_all, 2)
      check(
        label("lower bound t = 1 <= size of a covering sample"),
        b1$bound[1] <= nrow(pk1)
      )
      check(
        label("picked samples cover everything"),
        all(abs(vp_coverage(m, pk2)$coverage - 1) < 1e-12) &&
          abs(vp_coverage(m, pk1)$coverage[1] - 1) < 1e-12
      )
      if (nv <= 25) {
        b2 <- vp_min_sample_size(m, 2)
        pairs2 <- if (b2$bound[1] == 0) list() else strsplit(b2$item, " and ")
        in_x2 <- function(p) in_x(p[1]) & in_x(p[2])
        ok2 <- length(pairs2) < 2 ||
          all(apply(utils::combn(length(pairs2), 2), 2, function(q) {
            !any(in_x2(pairs2[[q[1]]]) & in_x2(pairs2[[q[2]]]))
          }))
        check(
          label(
            paste0(
              "lower bound t = 2: its pairs never share a configuration, and ",
              "each pair occurs"
            )
          ),
          ok2 && all(vapply(pairs2, function(p) any(in_x2(p)), TRUE))
        )
        check(
          label("lower bound t = 2 <= size of a covering sample"),
          b2$bound[1] <= nrow(pk2)
        )
      }

      # --- conflicts: groups, colouring, compatible sets, twins, explanations
      ag <- vp_alternative_groups(m, 2)
      check(
        label(
          "alternative groups: no configuration has two features of a group"
        ),
        all(vapply(
          split(ag$feature, ag$group),
          function(g) all(rowSums(x_mat[, g, drop = FALSE]) <= 1),
          TRUE
        ))
      )
      col <- vp_colouring(m)
      no_conflict_inside <- function(g) {
        length(g) < 2 ||
          !any(
            apply(utils::combn(g, 2), 2, function(p) {
              paste(sort(p), collapse = "\t")
            }) %in%
              truth_t$excludes
          )
      }
      check(
        label("colouring: no conflict inside a colour"),
        all(vapply(split(col$feature, col$colour), no_conflict_inside, TRUE))
      )
      lc <- vp_largest_compatible_set(m)$feature
      check(
        label(
          paste0(
            "largest compatible set has no conflict inside, and is at least ",
            "the largest product"
          )
        ),
        no_conflict_inside(lc) && length(lc) >= max(rowSums(x_mat))
      )
      tw <- vp_twins(m)
      if (nrow(tw)) {
        rel <- function(f) {
          i <- match(f, vars)
          c(
            truth_t$tt[i, -i],
            truth_t$tf[i, -i],
            truth_t$tf[-i, i],
            truth_t$ff[i, -i]
          )
        }
        check(
          label("twins have the same relationships with every other feature"),
          all(vapply(
            split(tw$feature, tw$group),
            function(g) {
              others <- setdiff(vars, g)
              sig <- function(f) {
                i <- match(f, vars)
                j <- match(others, vars)
                paste(
                  c(
                    truth_t$tt[i, j],
                    truth_t$tf[i, j],
                    truth_t$tf[j, i],
                    truth_t$ff[i, j]
                  ),
                  collapse = ""
                )
              }
              length(unique(vapply(g, sig, ""))) == 1
            },
            TRUE
          ))
        )
      }
      okx <- TRUE
      for (q in head(seq_len(nrow(m$excludes)), 25)) {
        a1 <- m$excludes$from[q]
        b1x <- m$excludes$to[q]
        ex <- vp_explain_conflict(m, a1, b1x)
        if (nrow(ex) == 0) {
          okx <- FALSE
          break
        }
        for (oi in unique(ex$origin)) {
          r <- ex[ex$origin == oi, ]
          steps_true <- all(ifelse(
            r$link == "requires",
            paste(r$from, r$to, sep = "\t") %in% truth_t$requires,
            paste(pmin(r$from, r$to), pmax(r$from, r$to), sep = "\t") %in%
              truth_t$excludes
          ))
          one_conflict <- sum(r$link == "excludes") == 1
          if (
            !steps_true ||
              !one_conflict ||
              !(a1 %in% r$from || a1 %in% r$to) ||
              !(b1x %in% r$from || b1x %in% r$to)
          ) {
            okx <- FALSE
          }
        }
      }
      check(
        label(
          paste0(
            "explanations of conflicts: every step is true, one conflict per ",
            "origin, both ends present"
          )
        ),
        okx
      )
      okr <- TRUE
      for (q in head(seq_len(nrow(m$requires)), 25)) {
        ex <- vp_explain_requires(m, m$requires$from[q], m$requires$to[q])
        for (ri in unique(ex$route)) {
          r <- ex[ex$route == ri, ]
          ok_step <- ifelse(
            r$link == "requires",
            paste(r$from, r$to, sep = "\t") %in% truth_t$requires,
            ifelse(
              r$link == "excludes",
              paste(pmin(r$from, r$to), pmax(r$from, r$to), sep = "\t") %in%
                truth_t$excludes,
              paste(pmin(r$from, r$to), pmax(r$from, r$to), sep = "\t") %in%
                truth_t$atleastone
            )
          )
          if (
            !all(ok_step) ||
              r$from[1] != m$requires$from[q] ||
              r$to[nrow(r)] != m$requires$to[q]
          ) {
            okr <- FALSE
          }
        }
      }
      check(
        label(
          paste0(
            "explanations of requirements: every step is true, and the route ",
            "goes from a to b"
          )
        ),
        okr
      )
      nonc <- if (nv < 2) {
        character(0)
      } else {
        setdiff(
          apply(utils::combn(vars, 2), 2, function(p) {
            paste(sort(p), collapse = "\t")
          }),
          truth_t$excludes
        )
      }
      if (length(nonc)) {
        p <- strsplit(nonc[1], "\t")[[1]]
        check(
          label("explaining a conflict that does not hold gives no rows"),
          suppressMessages(nrow(vp_explain_conflict(m, p[1], p[2]))) == 0
        )
      }

      # --- more inferences from the third graph
      rc <- vp_requires_from_conflicts(m)
      check(
        label("requirements from conflicts are true requirements"),
        all(
          paste(rc$from, rc$to, sep = "\t") %in%
            c(truth_t$requires, paste(vars, vars, sep = "\t")) |
            .vp_representative(m)[rc$from] == .vp_representative(m)[rc$to]
        )
      )
      check(
        label("primitive at-least-one lines are at-least-one lines"),
        all(
          keys(vp_primitive_atleastone(m), TRUE) %in%
            c(truth_t$atleastone, keys(.vp_merged(m)$atleastone, TRUE))
        )
      )

      # --- hierarchy: up-sets and down-sets
      okup <- all(vapply(
        vars,
        function(f) {
          want <- c(f, vars[paste(f, vars, sep = "\t") %in% truth_t$requires])
          setequal(vp_upset(m, f)$feature, want)
        },
        TRUE
      ))
      okdown <- all(vapply(
        vars,
        function(f) {
          want <- c(f, vars[paste(vars, f, sep = "\t") %in% truth_t$requires])
          setequal(vp_downset(m, f)$feature, want)
        },
        TRUE
      ))
      check(
        label("up-set of every feature = itself and what it requires"),
        okup
      )
      check(
        label("down-set of every feature = itself and what requires it"),
        okdown
      )
      if (nv >= 2) {
        a2 <- vars[1]
        b2 <- vars[2]
        check(
          label("common requirements and dependants"),
          setequal(
            vp_common_requirements(m, a2, b2)$feature,
            vars[
              paste(a2, vars, sep = "\t") %in%
                truth_t$requires &
                paste(b2, vars, sep = "\t") %in% truth_t$requires
            ]
          ) &&
            setequal(
              vp_common_dependants(m, a2, b2)$feature,
              vars[
                paste(vars, a2, sep = "\t") %in%
                  truth_t$requires &
                  paste(vars, b2, sep = "\t") %in% truth_t$requires
              ]
            )
        )
      }

      # --- groups by meaning
      cgp <- vp_candidate_groups(m)
      check(
        label("candidate groups: members exclude one another"),
        all(vapply(
          split(cgp$feature, cgp$group),
          function(g) all(rowSums(x_mat[, g, drop = FALSE]) <= 1),
          TRUE
        ))
      )
      cc <- vp_conflict_cover(m)
      covered <- unlist(lapply(split(cc$feature, cc$group), function(g) {
        if (length(g) > 1) {
          apply(utils::combn(g, 2), 2, function(p) {
            paste(sort(p), collapse = "\t")
          })
        }
      }))
      pc <- vp_primitive_conflicts(m)
      check(
        label(
          paste0(
            paste0(
              "conflict cover: groups are groups of alternatives, and they ",
              "state "
            ),
            "every primitive conflict"
          )
        ),
        all(vapply(
          split(cc$feature, cc$group),
          function(g) all(rowSums(x_mat[, g, drop = FALSE]) <= 1),
          TRUE
        )) &&
          all(
            paste(pmin(pc$from, pc$to), pmax(pc$from, pc$to), sep = "\t") %in%
              covered
          )
      )
      ip <- vp_independent_parts(m)
      part <- setNames(ip$part, ip$feature)
      lk <- strsplit(
        c(truth_t$requires, truth_t$excludes, truth_t$atleastone),
        "\t"
      )
      check(
        label("independent parts: no relationship joins two parts"),
        all(vapply(lk, function(p) part[[p[1]]] == part[[p[2]]], TRUE))
      )

      # --- the feature table: counts and decision power from the oracle
      ft <- vp_feature_table(m)
      rq <- do.call(rbind, strsplit(truth_t$requires, "\t"))
      if (is.null(rq)) {
        rq <- matrix(character(0), 0, 2)
      }
      cnt <- function(x) as.integer(table(factor(x, levels = vars))[ft$feature])
      ex2 <- do.call(rbind, strsplit(truth_t$excludes, "\t"))
      if (is.null(ex2)) {
        ex2 <- matrix(character(0), 0, 2)
      }
      al2 <- do.call(rbind, strsplit(truth_t$atleastone, "\t"))
      if (is.null(al2)) {
        al2 <- matrix(character(0), 0, 2)
      }
      check(
        label("feature table: required_by, requires, excludes, atleastone"),
        identical(ft$required_by, cnt(rq[, 2])) &&
          identical(ft$requires, cnt(rq[, 1])) &&
          identical(ft$excludes, cnt(c(ex2[, 1], ex2[, 2]))) &&
          identical(ft$atleastone, cnt(c(al2[, 1], al2[, 2])))
      )
      if (nv > 1) {
        dp_truth <- vapply(
          ft$feature,
          function(f) {
            i <- match(f, vars)
            sum(!truth_t$tf[i, -i]) + sum(!truth_t$tt[i, -i])
          },
          0
        ) /
          (nv - 1)
        check(
          label(
            paste0(
              "decision power = share of the other features that selecting it ",
              "decides (oracle)"
            )
          ),
          isTRUE(all.equal(unname(ft$decision_power), unname(dp_truth)))
        )
        dpo_truth <- vapply(
          ft$feature,
          function(f) {
            i <- match(f, vars)
            sum(!truth_t$tf[-i, i]) + sum(!truth_t$ff[i, -i])
          },
          0
        ) /
          (nv - 1)
        check(
          label(
            "decision power off = share that leaving it out decides (oracle)"
          ),
          isTRUE(all.equal(unname(ft$decision_power_off), unname(dpo_truth)))
        )
      }
      check(
        label("isolated features have no relationship at all"),
        all(vapply(
          ft$feature[ft$isolated],
          function(f) {
            i <- match(f, vars)
            all(
              truth_t$tt[i, -i] &
                truth_t$tf[i, -i] &
                truth_t$tf[-i, i] &
                truth_t$ff[i, -i]
            )
          },
          TRUE
        ))
      )

      # --- whole model
      s <- vp_summary(m)
      check(
        label("summary: counts and densities"),
        s$features == nv &&
          s$requires == length(truth_t$requires) &&
          s$excludes == length(truth_t$excludes) &&
          (nv < 2 ||
            abs(
              s$density_requires - length(truth_t$requires) / (nv * (nv - 1))
            ) <
              1e-12)
      )
      check(label("consistency checks hold"), all(vp_check(m)$holds))
    }

    # ---------------------------------------------------------- the known limit
    section("oracle: the limit of pairs (a rule over three features)")
    for (n in intersect(c("battery", "tiny"), names(oracle))) {
      m <- models[[n]]
      truth_t <- oracle[[n]]$T
      vars <- oracle[[n]]$V
      wl <- if (length(vars) > 2) {
        lapply(asplit(t(utils::combn(vars, 3)), 1), unname)
      } else {
        list()
      }
      wrong <- sum(
        vp_can_go_together(m, wl)$possible &
          !vapply(wl, function(w) possible(truth_t, on = w), TRUE)
      )
      check(
        paste0(
          n,
          paste0(
            ": the graphs say yes to some wish list of three that no product ",
            "has (the documented limit)"
          )
        ),
        wrong > 0
      )
    }
    if (!is.null(oracle$battery) && !is.null(oracle$miband3)) {
      check(
        "battery rule: no relationship between two features changes",
        all(vp_compare(models$miband3, models$battery)$jaccard == 1)
      )
      check(
        "battery rule: the model lost products",
        nrow(oracle$battery$all) < nrow(oracle$miband3$all)
      )
      w <- c("TouchScreen", "HeartRateSensor", "NFC")
      check(
        paste0(
          paste0(
            "battery rule: the graphs say yes to a wish list that no product ",
            "has "
          ),
          "(the documented limit)"
        ),
        vp_can_go_together(models$battery, w)$possible &&
          !possible(oracle$battery$T, on = w)
      )
    }
    if (!is.null(oracle$tiny)) {
      check(
        "tiny band: no relationship, so every feature is isolated",
        nrow(models$tiny$requires) + nrow(models$tiny$excludes) == 0 &&
          all(vp_feature_table(models$tiny)$isolated)
      )
      check(
        "tiny band: the kernel answers yes to the impossible list",
        vp_can_go_together(
          models$tiny,
          c("GPS", "NFC", "AlwaysOnDisplay")
        )$possible &&
          !possible(oracle$tiny$T, on = c("GPS", "NFC", "AlwaysOnDisplay"))
      )
    }

    # -------------------------------------------------- the tree of a UVL model
    section("the feature tree of the UVL models")
    for (n in pick(names(fixtures))) {
      if (is.null(fixtures[[n]]$uvl)) {
        next
      }
      m <- models[[n]]
      vars <- .vp_nodes(m)
      tree <- vp_read_uvl_tree(fixtures[[n]]$uvl)
      check(
        paste0(n, ": every feature of the graphs is in the tree"),
        all(vars %in% tree$feature)
      )
      fo <- vp_false_optional(m, tree)
      optional <- tree[!is.na(tree$relation) & tree$relation == "optional", ]
      st <- setNames(vp_features(m)$status, vp_features(m)$feature)
      if (!is.null(oracle[[n]])) {
        # by the configurations
        x_mat <- oracle[[n]]$T$X
        always <- function(c, p) all(x_mat[x_mat[, p], c])
        how <- "the configurations"
      } else {
        # by the definitions on the graphs
        always <- function(c, p) paste(p, c, sep = "\t") %in% keys(m$requires)
        how <- "the graphs"
      }
      is_fo <- vapply(
        seq_len(nrow(optional)),
        function(k) {
          c <- optional$feature[k]
          p <- optional$parent[k]
          if (c %in% names(st) && st[[c]] == "core") {
            return(TRUE)
          }
          c %in% vars && p %in% vars && always(c, p)
        },
        TRUE
      )
      want <- optional$feature[is_fo]
      check(
        paste0(n, ": false-optional features (by ", how, ")"),
        setequal(fo$feature, want)
      )
      ta <- vp_tree_agreement(m, tree)
      skel <- vp_skeleton(m)
      rep <- .vp_representative(m)
      check(
        paste0(
          n,
          paste0(
            paste0(
              ": tree agreement: 'direct' iff the parent is a direct ",
              "requirement "
            ),
            "in the skeleton"
          )
        ),
        all(
          ta$direct ==
            (paste(rep[ta$feature], rep[ta$parent]) %in%
              paste(skel$from, skel$to))
        )
      )
      check(
        paste0(
          n,
          paste0(
            paste0(
              ": tree agreement: the features in between are on a chain from ",
              "the "
            ),
            "feature to its parent"
          )
        ),
        all(vapply(
          seq_len(nrow(ta)),
          function(k) {
            if (ta$direct[k]) {
              return(TRUE)
            }
            mid <- strsplit(ta$in_between[k], ", ")[[1]]
            dep_m <- .vp_merged(m)$D
            all(
              dep_m[rep[[ta$feature[k]]], mid] > 0 &
                dep_m[mid, rep[[ta$parent[k]]]] > 0
            )
          },
          TRUE
        ))
      )
    }
  }
)
