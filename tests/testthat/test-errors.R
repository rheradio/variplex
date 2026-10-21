test_that(
  paste0(
    "Wrong input gets a clear message; unusual models do not break the ",
    "functions."
  ),
  {
    # ==========================================================================
    # Wrong input gets a clear message; unusual models do not break the
    # functions.
    # ==========================================================================
    section("errors and edge cases")
    band <- models$miband3
    check(
      "a prefix without files: the message says what a prefix is",
      fails_with(vp_read(file.path(work, "nothing")), "prefix is the path")
    )
    check(
      "a misspelt feature: the message says so",
      fails_with(vp_required_by(band, "Scren"), "not a feature of the model")
    )
    check(
      "a core feature: the message says it is not in the graphs",
      fails_with(vp_requirements(band, "Pedometer"), "is core")
    )
    check(
      "an unknown graph name is refused",
      fails_with(vp_links(band, "depends"), "should be one of")
    )
    plain <- vp_read(run_vp(
      file.path(examples, "miband3_realized.uvl"),
      file.path(work, "plain")
    ))
    plain_dir <- file.path(work, "noalo")
    dir.create(plain_dir)
    vp_generate(
      file.path(examples, "miband3_realized.uvl"),
      output_dir = plain_dir,
      read = FALSE
    )
    noalo <- vp_read(file.path(plain_dir, "miband3_realized"))
    check("without --or-graph: atleastone is NULL", is.null(noalo$atleastone))
    check(
      "without --or-graph: functions that need it say how to get it",
      fails_with(vp_opposites(noalo), "or_graph = TRUE") &&
        fails_with(vp_primitive_atleastone(noalo), "or_graph = TRUE") &&
        fails_with(vp_atleastone_of(noalo, "Screen"), "or_graph = TRUE") &&
        fails_with(vp_links(noalo, "atleastone"), "or_graph = TRUE")
    )
    check(
      paste0(
        "without --or-graph: 'neither' is NA, decision_power_off is NA, ",
        "combinations are not exact"
      ),
      is.na(vp_pair(noalo, "Screen", "BT40")$possible[4]) &&
        all(is.na(vp_feature_table(noalo)$decision_power_off)) &&
        !vp_combinations_to_cover(noalo, 2)$exact
    )
    check(
      "without --or-graph: leaving features out warns",
      inherits(
        tryCatch(
          vp_consequences(noalo, deselected = "Screen"),
          warning = function(w) w
        ),
        "warning"
      )
    )
    check(
      "t must be 1 or 2",
      fails_with(vp_combinations_to_cover(band, 3), "t must be 1 or 2")
    )
    check(
      "a sample without a column of a feature is refused",
      fails_with(vp_coverage(band, data.frame(Screen = 1)), "no column for")
    )
    smp <- as.data.frame(matrix(
      2L,
      1,
      11,
      dimnames = list(NULL, .vp_nodes(band))
    ))
    check(
      "a sample with values other than 0/1 is refused",
      fails_with(vp_coverage(band, smp), "0/1")
    )
    check(
      "too many features to count products: refused",
      fails_with(vp_count_graph_products(band, max_features = 5), "too many")
    )
    check(
      "too many features for the t = 2 bound: refused",
      fails_with(vp_min_sample_size(band, 2, max_features = 5), "Use t = 1")
    )
    check(
      "forecast needs at least 3 training versions",
      fails_with(
        vp_forecast_size(
          vp_read_history(c(
            fixtures$miband3$prefix,
            fixtures$miband4$prefix,
            fixtures$miband6$prefix
          )),
          1
        ),
        "train"
      )
    )
    bad <- file.path(work, "bad")
    dir.create(bad)
    writeLines(
      c("*Vertices 2", '1 "a"', '2 "b"', "*Arcs"),
      file.path(bad, "x__requires.net")
    )
    writeLines(
      c("*Vertices 2", '1 "b"', '2 "a"', "*Edges"),
      file.path(bad, "x__excludes.net")
    )
    file.create(file.path(bad, "x__core.txt"))
    file.create(file.path(bad, "x__dead.txt"))
    check(
      "graph files that list the features in different orders are refused",
      fails_with(
        vp_read(file.path(bad, "x")),
        "same features in the same order"
      )
    )
    writeLines("not a pajek file", file.path(bad, "y__requires.net"))
    check(
      "a file that is not Pajek is refused",
      fails_with(vp_read(file.path(bad, "y")), "not a Pajek file")
    )
    empty <- models$miband1
    fns <- list(
      vp_feature_table,
      vp_summary,
      vp_skeleton,
      vp_primitive_conflicts,
      vp_levels,
      vp_kernel,
      vp_twins,
      vp_check,
      vp_independent_parts,
      vp_cut_features,
      vp_candidate_groups,
      vp_conflict_cover,
      vp_mig,
      vp_triangles,
      vp_minimal,
      function(m) vp_expand(vp_minimal(m)),
      vp_alternative_groups,
      vp_colouring,
      vp_feature_tree
    )
    ok <- vapply(
      seq_along(fns),
      function(i) {
        tryCatch(
          {
            fns[[i]](empty)
            TRUE
          },
          error = function(e) {
            cat("      function", i, "of the list:", conditionMessage(e), "\n")
            FALSE
          }
        )
      },
      TRUE
    )
    check("a model with no feature that can vary: every function runs", all(ok))
    legacy <- model_from_links(
      c("a", "b", "c", "always"),
      requires = data.frame(
        from = c("a", "b", "c"),
        to = c("always", "always", "always")
      ),
      excludes = data.frame(from = "a", to = "b"),
      core = "always",
      name = "legacy"
    )
    check(
      paste0(
        "graphs of version 1 of Strong4VM: core features drawn as nodes are ",
        "removed"
      ),
      isTRUE(legacy$legacy) &&
        !"always" %in% .vp_nodes(legacy) &&
        nrow(legacy$requires) == 0
    )
    art <- model_from_links(
      c(
        "A",
        "k!12",
        "__VISIBILITY__A",
        "<unsupported>",
        "B_MODULE",
        "B",
        "CHOICE_3"
      ),
      requires = data.frame(from = c("A", "B_MODULE"), to = c("k!12", "B")),
      excludes = data.frame(from = "A", to = "B"),
      name = "artificial"
    )
    a1 <- vp_read(
      file.path(dirname(art$prefix), "artificial"),
      artificial = "drop"
    )
    a2 <- vp_read(
      file.path(dirname(art$prefix), "artificial"),
      artificial = "drop",
      translator = "kconfigreader"
    )
    check(
      paste0(
        "artificial = 'drop' (KMax) removes k!N, __VISIBILITY__ and ",
        "<unsupported>"
      ),
      setequal(.vp_nodes(a1), c("A", "B_MODULE", "B", "CHOICE_3"))
    )
    check(
      paste0(
        paste0(
          "translator = 'kconfigreader' also removes CHOICE_N, and X_MODULE ",
          "when "
        ),
        "X exists"
      ),
      setequal(.vp_nodes(a2), c("A", "B"))
    )
    check(
      "vp_subset keeps only the given features and refuses unknown ones",
      setequal(
        .vp_nodes(vp_subset(band, c("Screen", "BT40"))),
        c("Screen", "BT40")
      ) &&
        fails_with(vp_subset(band, c("Screen", "Nope")), "not a feature")
    )
    check(
      "vp_functions lists every function defined, and nothing else",
      setequal(
        vp_functions()$name,
        grep("^vp_", getNamespaceExports("variplex"), value = TRUE)
      ),
      setdiff(
        grep("^vp_", getNamespaceExports("variplex"), value = TRUE),
        vp_functions()$name
      )
    )

    section("empty answers keep their columns")
    one <- vp_read_history(fixtures$miband3$prefix, versions = "only")
    m3 <- models$miband3
    calls <- list(
      "can_go_together(no wish list)" = function() {
        vp_can_go_together(m3, list())
      },
      "explain_conflict(no conflict)" = function() {
        suppressMessages(vp_explain_conflict(m3, "NFC", "Screen"))
      },
      "explain_requires(no requirement)" = function() {
        suppressMessages(vp_explain_requires(m3, "NFC", "Screen"))
      },
      "tree_agreement(nothing to compare)" = function() {
        vp_tree_agreement(
          models$miband1,
          vp_read_uvl_tree(fixtures$miband1$uvl)
        )
      },
      "false_optional(none)" = function() {
        vp_false_optional(
          models$miband1,
          vp_read_uvl_tree(fixtures$miband1$uvl)
        )
      },
      "history_changes(one version)" = function() vp_history_changes(one),
      "attachment(one version)" = function() vp_attachment(one),
      "hub_stability(one version)" = function() vp_hub_stability(one),
      "disruptions(one version)" = function() vp_disruptions(one),
      "community_history(one version)" = function() vp_community_history(one),
      "edit_type(one version)" = function() vp_edit_type(one),
      "life_cycle(one version)" = function() vp_life_cycle(one),
      "flip_flops(none)" = function() vp_flip_flops(one),
      "prediction_table(one version)" = function() vp_prediction_table(one),
      "changed_links(none)" = function() vp_changed_links(m3, m3),
      "state_moves(none)" = function() vp_state_moves(m3, m3),
      "top_movers(none)" = function() vp_top_movers(m3, m3),
      "rename_candidates(none)" = function() vp_rename_candidates(m3, m3),
      "consequences(no decision)" = function() vp_consequences(m3),
      "alternative_groups(none)" = function() vp_alternative_groups(m3, 10),
      "twins(none)" = function() vp_twins(m3),
      "candidate_groups(empty model)" = function() {
        vp_candidate_groups(models$miband1)
      },
      "conflict_cover(empty model)" = function() {
        vp_conflict_cover(models$miband1)
      },
      "cut_features(empty model)" = function() vp_cut_features(models$miband1),
      "independent_parts(empty model)" = function() {
        vp_independent_parts(models$miband1)
      },
      "feature_table(empty model)" = function() {
        vp_feature_table(models$miband1)
      },
      "kernel(empty model)" = function() vp_kernel(models$miband1),
      "kernel_links(empty model)" = function() vp_kernel_links(models$miband1),
      "mig(empty model)" = function() vp_mig(models$miband1),
      "levels(empty model)" = function() vp_levels(models$miband1),
      "chains(empty model)" = function() vp_chains(models$miband1),
      "plot of an empty model" = function() {
        tibble::tibble(dot = vp_dot(models$miband1))
      },
      "largest_free_set(empty model)" = function() {
        vp_largest_free_set(models$miband1)
      },
      "longest_decision_chain(empty model)" = function() {
        vp_longest_decision_chain(models$miband1)
      },
      "feature_tree(empty model)" = function() vp_feature_tree(models$miband1),
      "uncovered(no pair)" = function() {
        vp_uncovered(models$miband1s, data.frame(HeartRateSensor = c(0, 1)))
      },
      "sample_violations(none)" = function() {
        vp_sample_violations(m3, as.data.frame(oracle$miband3$T$X * 1L))
      },
      "implied_requires(none)" = function() vp_implied_requires(models$miband2),
      "requires_from_conflicts(none)" = function() {
        vp_requires_from_conflicts(models$miband1)
      },
      "opposites(none)" = function() vp_opposites(models$miband1)
    )
    res <- vapply(
      names(calls),
      function(nm) {
        r <- tryCatch(calls[[nm]](), error = function(e) e)
        if (inherits(r, "error")) {
          paste("error:", conditionMessage(r))
        } else if (!is.data.frame(r)) {
          "not a table"
        } else if (ncol(r) == 0) {
          "no columns"
        } else {
          "ok"
        }
      },
      ""
    )
    for (nm in names(res)) {
      check(
        paste0(nm, ": a table with its columns"),
        res[[nm]] == "ok",
        res[[nm]]
      )
    }
  }
)
