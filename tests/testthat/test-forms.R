test_that(
  paste0(
    "The two forms of a model (complete and minimal), expansion, and parts of ",
    "a model."
  ),
  {
    # ==========================================================================
    # The two forms of a model (complete and minimal), expansion, and parts of a
    # model.
    # ==========================================================================
    section(
      "forms: minimal form, expansion, and the same answers in every form"
    )
    withr::local_seed(7)
    same_links <- function(a, b) {
      setequal(keys(a$requires), keys(b$requires)) &&
        setequal(keys(a$excludes, TRUE), keys(b$excludes, TRUE)) &&
        setequal(keys(a$atleastone, TRUE), keys(b$atleastone, TRUE)) &&
        setequal(a$features$feature, b$features$feature)
    }
    norm <- function(x) {
      x <- as.data.frame(x)
      if (nrow(x)) {
        x <- x[do.call(order, unname(as.list(x))), , drop = FALSE]
      }
      rownames(x) <- NULL
      x
    }

    for (n in pick(names(models))) {
      m <- models[[n]]
      label <- function(what) paste0(n, ": ", what)
      mn <- vp_minimal(m)
      mr <- vp_read(fixtures[[n]]$prefix, form = "minimal")
      check(
        label("vp_minimal() = the minimal form that Strong4VM wrote"),
        setequal(keys(mn$requires), keys(mr$requires)) &&
          setequal(keys(mn$excludes, TRUE), keys(mr$excludes, TRUE)) &&
          setequal(keys(mn$atleastone, TRUE), keys(mr$atleastone, TRUE))
      )
      check(
        label("expanding the minimal form gives the complete graphs back"),
        same_links(vp_expand(mn), m)
      )
      check(
        label("expanding the minimal files gives the complete graphs back"),
        same_links(vp_expand(mr), m)
      )
      check(
        label(
          "expanding twice changes nothing; a complete model is not expanded"
        ),
        identical(vp_expand(m), m) && same_links(vp_expand(vp_expand(mn)), m)
      )
      vars <- .vp_nodes(m)
      if (length(vars) < 2) {
        next
      }
      f1 <- vars[1]
      f2 <- vars[length(vars)]
      inferences <- list(
        skeleton = function(x) vp_skeleton(x),
        primitive = function(x) vp_primitive_conflicts(x),
        levels = function(x) vp_levels(x),
        width = function(x) data.frame(w = vp_width(x)),
        chains = function(x) vp_chains(x),
        pair = function(x) vp_pair(x, f1, f2),
        upset = function(x) vp_upset(x, f1),
        wish = function(x) {
          vp_can_go_together(
            x,
            list(c(f1, f2), vars[seq_len(min(3, length(vars)))])
          )
        },
        partial = function(x) {
          data.frame(possible = vp_partial_configuration(x, f1, f2)$possible)
        },
        partial_explanation = function(x) {
          vp_partial_configuration(x, f1, f2)$explanation
        },
        team_order = function(x) {
          vp_team_order(
            x,
            tibble::tibble(
              feature = vars,
              team = rep(c("a", "b"), length.out = length(vars))
            )
          )
        },
        split_after = function(x) vp_split_after(x, selected = f1),
        consequences = function(x) vp_consequences(x, f1, f2),
        kernel = function(x) vp_kernel(x),
        kernel_links = function(x) vp_kernel_links(x),
        count = function(x) vp_count_graph_products(x),
        cover = function(x) vp_combinations_to_cover(x, 2),
        bound = function(x) vp_min_sample_size(x, 1),
        twins = function(x) vp_twins(x),
        opposites = function(x) vp_opposites(x),
        groups = function(x) vp_alternative_groups(x, 2),
        check = function(x) vp_check(x),
        communities = function(x) vp_communities(x),
        cuts = function(x) vp_cut_features(x),
        candidates = function(x) vp_candidate_groups(x),
        cover_groups = function(x) vp_conflict_cover(x),
        power = function(x) {
          t <- vp_feature_table(x)[, c(
            "feature",
            "decision_power",
            "decision_power_off",
            "level",
            "betweenness"
          )]
          t[t$feature %in% .vp_nodes(mn), ]
        }
      ) # the minimal form has one row per atomic set: compare those features
      if (length(vars) > 20) {
        inferences$count <- NULL
      } # vp_count_graph_products refuses more than 20 features
      diff <- names(inferences)[
        !vapply(
          inferences,
          function(f) {
            identical(norm(f(m)), norm(f(mn))) &&
              identical(norm(f(m)), norm(f(mr)))
          },
          TRUE
        )
      ]
      check(
        label(paste(
          "inferences give the same answer in the three forms",
          if (length(diff)) {
            paste0("(differ: ", paste(diff, collapse = ", "), ")")
          } else {
            ""
          }
        )),
        length(diff) == 0
      )
      # the MIG reads the graphs given: the compact MIG of the minimal form
      # reaches exactly the implications of the complete one
      lit <- function(f, v) paste0(ifelse(v, "", "not "), f)
      rp <- .vp_representative(m)
      full <- suppressWarnings(vp_mig(m))
      cm <- suppressWarnings(vp_mig(mn))
      want <- unique(paste(
        lit(rp[full$from], full$from_selected),
        lit(rp[full$to], full$to_selected),
        sep = "\t"
      ))
      want <- want[sub("\t.*", "", want) != sub(".*\t", "", want)]
      got <- character(0)
      if (nrow(cm) > 0) {
        g <- igraph::graph_from_data_frame(data.frame(
          from = lit(cm$from, cm$from_selected),
          to = lit(cm$to, cm$to_selected)
        ))
        reach <- igraph::ego(
          g,
          order = igraph::vcount(g),
          mode = "out",
          mindist = 1
        )
        nm <- igraph::V(g)$name
        got <- unlist(lapply(seq_along(nm), function(i) {
          t <- setdiff(nm[as.integer(reach[[i]])], nm[i])
          if (length(t)) paste(nm[i], t, sep = "\t")
        }))
      }
      check(
        label(
          paste0(
            "the compact MIG (minimal form) has fewer arrows and reaches ",
            "exactly the implications of the complete MIG"
          )
        ),
        setequal(got, want) && nrow(cm) <= nrow(full)
      )
      ftm <- vp_feature_table(mn)
      check(
        label("measures on the minimal form count its own links"),
        all(
          ftm$requires ==
            vapply(ftm$feature, function(f) sum(mn$requires$from == f), 0)
        ) &&
          all(
            ftm$excludes ==
              vapply(
                ftm$feature,
                function(f) sum(mn$excludes$from == f | mn$excludes$to == f),
                0
              )
          )
      )
      sm <- vp_summary(mn)
      sc <- vp_summary(m)
      check(
        label(
          paste0(
            "summary of the minimal form: its counts, the inferences of the ",
            "complete graphs"
          )
        ),
        sm$requires == nrow(mn$requires) &&
          sm$form == "minimal" &&
          all(
            unlist(sm[c(
              "depth",
              "width",
              "implicit_requires",
              "implicit_excludes",
              "mean_decision_power",
              "largest_alternative_group"
            )]) ==
              unlist(sc[c(
                "depth",
                "width",
                "implicit_requires",
                "implicit_excludes",
                "mean_decision_power",
                "largest_alternative_group"
              )])
          )
      )
    }

    section("forms: a part of a model is exact (property P3)")
    for (n in pick(names(oracle))) {
      m <- models[[n]]
      vars <- oracle[[n]]$V
      x_mat <- oracle[[n]]$T$X
      if (length(vars) < 4) {
        next
      }
      ok <- TRUE
      for (r in 1:5) {
        keep <- sample(vars, sample(2:(length(vars) - 1), 1))
        part <- vp_subset(m, keep)
        t2 <- truth(x_mat[, keep, drop = FALSE])
        if (
          !(setequal(keys(part$requires), t2$requires) &&
            setequal(keys(part$excludes, TRUE), t2$excludes) &&
            setequal(keys(part$atleastone, TRUE), t2$atleastone))
        ) {
          ok <- FALSE
        }
        if (
          !identical(
            norm(vp_subset(vp_minimal(m), keep)$requires),
            norm(part$requires)
          )
        ) {
          ok <- FALSE
        }
      }
      check(
        paste0(
          n,
          paste0(
            ": the graphs of a random part = the relationships of its ",
            "configurations; same from the minimal form"
          )
        ),
        ok
      )
    }
  }
)
