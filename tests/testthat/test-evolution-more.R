test_that(
  paste0(
    "The deeper operations on histories: apply, ripple, interaction changes ",
    "(against the oracle), churn, co-change,"
  ),
  {
    # ==========================================================================
    # The deeper operations on histories: apply, ripple, interaction changes
    # (against the oracle), churn, co-change, distances between versions, eras
    # (against brute force) and the drawing of changes.
    # ==========================================================================
    section("evolution, deeper: against the oracle and brute force")
    gh <- vp_read_history(
      vapply(gens, function(g) fixtures[[g]]$prefix, ""),
      versions = gens
    )

    # --- vp_history_apply
    a1 <- vp_history_apply(gh, vp_depth)
    check(
      "apply: a number per version -> a column value",
      identical(names(a1), c("version", "value")) &&
        all(a1$value == vapply(gh$model, vp_depth, 0L)) &&
        identical(a1$version, gh$version)
    )
    a2 <- vp_history_apply(gh, function(m) {
      c(depth = vp_depth(m), width = vp_width(m))
    })
    check(
      "apply: a named vector -> one column per name",
      identical(names(a2), c("version", "depth", "width")) &&
        all(a2$width == vapply(gh$model, vp_width, 0L))
    )
    a3 <- vp_history_apply(gh, function(m) {
      vp_feature_table(m)[, c("feature", "required_by")]
    })
    check(
      "apply: a tibble -> its rows, with the version in front",
      nrow(a3) ==
        sum(vapply(gh$model, function(m) nrow(vp_feature_table(m)), 0L)) &&
        names(a3)[1] == "version"
    )
    check(
      "apply: extra arguments reach the function",
      all(vp_history_apply(gh, function(m, k) k, k = 7)$value == 7)
    )
    check(
      "apply: an answer that is not a number, a vector or a tibble is an error",
      fails_with(vp_history_apply(gh, function(m) list(1)), "must return")
    )

    # --- vp_ripple
    rp <- vp_ripple(gh)
    rg <- vp_ripple(gh, by_graph = TRUE)
    full <- vp_history_changes(gh)
    mini <- vp_history_changes(dplyr::mutate(
      gh,
      model = lapply(model, vp_minimal)
    ))
    check(
      paste0(
        "ripple by graph: written = the changes of the minimal forms, ",
        "gained/lost = those of the complete graphs"
      ),
      all(
        rg$gained == full$gained &
          rg$lost == full$lost &
          rg$written_gained == mini$gained &
          rg$written_lost == mini$lost
      )
    )
    check(
      "ripple: one row per step, the graphs added up",
      nrow(rp) == nrow(gh) - 1 &&
        all(rp$gained == tapply(full$gained, full$step, sum)) &&
        all(rp$written_lost == tapply(mini$lost, mini$step, sum))
    )
    check(
      paste0(
        "ripple: complete changes over written changes; NA when nothing ",
        "written changed"
      ),
      all(is.na(rp$ripple) == (rp$written_gained + rp$written_lost == 0)) &&
        all(
          abs(
            rp$ripple -
              (rp$gained + rp$lost) / (rp$written_gained + rp$written_lost)
          ) <
            1e-12,
          na.rm = TRUE
        )
    )
    r1 <- model_from_links(
      c("a", "b", "c"),
      data.frame(from = "a", to = "b"),
      name = "r1"
    )
    r2 <- model_from_links(
      c("a", "b", "c"),
      data.frame(from = c("a", "b", "a"), to = c("b", "c", "c")),
      name = "r2"
    )
    hr <- tibble::tibble(
      version = factor(c("r1", "r2"), levels = c("r1", "r2")),
      model = list(r1, r2)
    )
    check(
      paste0(
        paste0(
          "ripple by hand: writing b -> c also makes a -> c: one written ",
          "change, "
        ),
        "two consequences"
      ),
      local({
        x <- vp_ripple(hr)
        x$written_gained == 1 && x$gained == 2 && x$ripple == 2
      })
    )

    # --- vp_interaction_changes, against the oracle (exact as far as pairs:
    # property P3)
    combo <- function(truth_t, a, va, b, vb) {
      possible(truth_t, on = c(a, b)[c(va, vb)], off = c(a, b)[!c(va, vb)])
    }
    for (p in Map(c, head(gens, -1), gens[-1])) {
      if (is.null(oracle[[p[1]]]) || is.null(oracle[[p[2]]])) {
        next
      }
      to_m <- oracle[[p[1]]]$T
      tn <- oracle[[p[2]]]$T
      kept <- intersect(oracle[[p[1]]]$V, oracle[[p[2]]]$V)
      truth_rows <- character(0)
      if (length(kept) >= 2) {
        for (i in 1:(length(kept) - 1)) {
          for (j in (i + 1):length(kept)) {
            for (va in c(TRUE, FALSE)) {
              for (vb in c(TRUE, FALSE)) {
                o <- combo(to_m, kept[i], va, kept[j], vb)
                n <- combo(tn, kept[i], va, kept[j], vb)
                if (o != n) {
                  truth_rows <- c(
                    truth_rows,
                    paste(
                      pmin(kept[i], kept[j]),
                      pmax(kept[i], kept[j]),
                      if (kept[i] < kept[j]) va else vb,
                      if (kept[i] < kept[j]) vb else va,
                      if (n) "now possible" else "now impossible"
                    )
                  )
                }
              }
            }
          }
        }
      }
      ic <- vp_interaction_changes(models[[p[1]]], models[[p[2]]])
      got <- paste(
        pmin(ic$feature_1, ic$feature_2),
        pmax(ic$feature_1, ic$feature_2),
        ifelse(ic$feature_1 < ic$feature_2, ic$value_1, ic$value_2),
        ifelse(ic$feature_1 < ic$feature_2, ic$value_2, ic$value_1),
        ic$change
      )
      check(
        paste0(
          p[1],
          " -> ",
          p[2],
          paste0(
            ": interaction changes = the combinations whose possibility ",
            "changed (oracle)"
          )
        ),
        setequal(got, truth_rows) && !anyDuplicated(got)
      )
      # the sample: the valid configurations of the old version
      x_mat <- oracle[[p[1]]]$all
      smp <- as.data.frame(x_mat * 1L)
      if (nrow(ic)) {
        ics <- vp_interaction_changes(
          models[[p[1]]],
          models[[p[2]]],
          sample = smp
        )
        cnt <- vapply(
          seq_len(nrow(ics)),
          function(k) {
            sum(
              x_mat[, ics$feature_1[k]] == ics$value_1[k] &
                x_mat[, ics$feature_2[k]] == ics$value_2[k]
            )
          },
          0L
        )
        check(
          paste0(
            p[1],
            " -> ",
            p[2],
            paste0(
              ": in_sample counts the configurations with the combination; ",
              "none for a combination that was impossible"
            )
          ),
          all(ics$in_sample == cnt) &&
            all(ics$in_sample[ics$change == "now possible"] == 0) &&
            all(ics$in_sample[ics$change == "now impossible"] > 0)
        )
      }
    }
    check(
      "interaction changes: a sample without a needed column is an error",
      fails_with(
        vp_interaction_changes(
          models$miband3,
          models$miband4,
          sample = data.frame(x = 1)
        ),
        "no column for"
      )
    )
    check(
      "interaction changes: nothing changed, nothing listed (with its columns)",
      local({
        x <- vp_interaction_changes(models$miband3, models$miband3)
        nrow(x) == 0 && ncol(x) == 6
      })
    )

    # --- churn and co-change, by hand: s1 -> s2 gains a->b and c->d; s2 -> s3
    # loses a->b and gains a->c
    s1 <- model_from_links(
      c("a", "b", "c", "d", "e"),
      data.frame(from = "e", to = "d"),
      name = "s1"
    )
    s2 <- model_from_links(
      c("a", "b", "c", "d", "e"),
      data.frame(from = c("e", "a", "c"), to = c("d", "b", "d")),
      name = "s2"
    )
    s3 <- model_from_links(
      c("a", "b", "c", "d"),
      data.frame(from = c("c", "a", "a"), to = c("d", "c", "d")),
      name = "s3"
    )
    hs <- tibble::tibble(
      version = factor(c("s1", "s2", "s3"), levels = c("s1", "s2", "s3")),
      model = list(s1, s2, s3)
    )
    ch <- vp_feature_churn(hs, "requires")
    g <- function(f, col) ch[[col]][ch$feature == f]
    check(
      paste0(
        "churn by hand: a gained 1 and lost 1, then gained 2 (a->c, a->d ",
        "through c), in 2 steps"
      ),
      g("a", "gained") == 3 &&
        g("a", "lost") == 1 &&
        g("a", "steps_changed") == 2 &&
        g("a", "churn") == 4
    )
    check(
      paste0(
        paste0(
          "churn by hand: e is in 2 versions and never changed; required_by ",
          "from "
        ),
        "the last version with the feature"
      ),
      g("e", "versions") == 2 &&
        g("e", "churn") == 0 &&
        g("d", "required_by") == 2 &&
        g("b", "required_by") == 0
    )
    check(
      "churn: the churns add up to twice the changed links",
      local({
        x <- vp_feature_churn(gh)
        sum(x$churn) == 2 * sum(full$gained + full$lost)
      })
    )
    cc <- vp_co_change(hs, "requires", min_together = 1)
    row <- function(a, b) cc[cc$feature_1 == a & cc$feature_2 == b, ]
    check(
      paste0(
        paste0(
          "co-change by hand: a and c changed together in both steps, a and ",
          "b in "
        ),
        "two (through their own link once... and its loss)"
      ),
      row("a", "c")$together == 2 &&
        row("a", "b")$together == 2 &&
        row("a", "b")$through_their_link == 2 &&
        row("a", "c")$through_their_link == 1
    )
    check(
      paste0(
        "co-change by hand: linked in the last version that has both (a, b: ",
        "no; a, c: yes)"
      ),
      identical(row("a", "b")$linked, FALSE) &&
        identical(row("a", "c")$linked, TRUE)
    )
    check(
      paste0(
        "co-change: pairs once, sorted, at least min_together, jaccard = ",
        "together / either"
      ),
      all(cc$feature_1 < cc$feature_2) &&
        !anyDuplicated(cc[c("feature_1", "feature_2")]) &&
        all(
          abs(
            cc$jaccard - cc$together / (cc$steps_1 + cc$steps_2 - cc$together)
          ) <
            1e-12
        ) &&
        all(vp_co_change(hs, "requires", min_together = 2)$together >= 2)
    )
    check(
      paste0(
        "co-change: one version, or no change, is an empty table with its ",
        "columns"
      ),
      ncol(vp_co_change(hs[1, ])) == 8 &&
        nrow(vp_co_change(tibble::tibble(
          version = factor(c("x", "y")),
          model = list(s1, s1)
        ))) ==
          0
    )

    # --- distances and eras
    vd <- vp_version_distance(gh)
    check(
      paste0(
        paste0(
          "version distance: every pair once; consecutive pairs = the ",
          "Jaccard of "
        ),
        "vp_compare"
      ),
      nrow(vd) == choose(nrow(gh), 2) &&
        all(abs(vd$distance - (1 - vd$jaccard)) < 1e-12) &&
        all(vapply(
          seq_len(nrow(gh) - 1),
          function(k) {
            abs(
              vd$jaccard[
                vd$from == gh$version[k] & vd$to == gh$version[k + 1]
              ] -
                full$jaccard[full$step == k & full$graph == "requires"]
            ) <
              1e-12
          },
          TRUE
        ))
    )
    dep_m <- matrix(0, nrow(gh), nrow(gh))
    ix <- t(combn(nrow(gh), 2))
    dep_m[ix] <- vd$distance
    dep_m[ix[, 2:1]] <- vd$distance
    crit <- function(era) {
      sum(vapply(
        unique(era),
        function(e) {
          w <- which(era == e)
          sum(dep_m[w, w]) / 2 / length(w)
        },
        0
      ))
    }
    splits <- function(n, k) {
      if (k == 1) {
        list(rep(1L, n))
      } else {
        unlist(
          lapply(1:(n - k + 1), function(f) {
            lapply(splits(n - f, k - 1), function(r) c(rep(1L, f), r + 1L))
          }),
          recursive = FALSE
        )
      }
    }
    for (k in seq_len(nrow(gh))) {
      e <- vp_eras(gh, k)
      best <- min(vapply(splits(nrow(gh), k), crit, 0))
      check(
        paste(
          "eras, k =",
          k,
          paste0(
            ": consecutive, numbered 1..k, and the best split found by trying ",
            "them all"
          )
        ),
        identical(sort(unique(e$era)), seq_len(k)) &&
          all(diff(e$era) %in% c(0, 1)) &&
          abs(crit(e$era) - best) < 1e-12
      )
    }
    check(
      "eras: spread = the mean distance between two versions of the era",
      local({
        e <- vp_eras(gh, 2)
        all(vapply(
          1:2,
          function(x) {
            w <- which(e$era == x)
            s <- if (length(w) < 2) {
              0
            } else {
              sum(dep_m[w, w]) / (length(w) * (length(w) - 1))
            }
            abs(e$spread[w[1]] - s) < 1e-12
          },
          TRUE
        ))
      })
    )
    check(
      "eras: k out of range is an error",
      fails_with(vp_eras(gh, 0), "whole number") &&
        fails_with(vp_eras(gh, 99), "whole number") &&
        fails_with(vp_eras(gh, 1.5), "whole number")
    )

    section("evolution, deeper: drawing the changes")
    dc <- function(...) parse_dot(vp_dot_compare(...))
    for (p in Map(c, head(gens, -1), gens[-1])) {
      a <- models[[p[1]]]
      b <- models[[p[2]]]
      label <- function(w) paste0(p[1], " -> ", p[2], ": ", w)
      if (length(union(.vp_nodes(a), .vp_nodes(b))) == 0) {
        next
      }
      d <- dc(a, b, minimal = FALSE, context = FALSE)
      chg <- d$links
      k <- paste(chg$from, chg$to, sep = "\t")
      thick <- grepl("penwidth=2.6", grep(" -> ", d$lines, value = TRUE))
      lost <- grepl("#C25E00", grep(" -> ", d$lines, value = TRUE))
      check(
        label(
          paste0(
            paste0(
              "complete graphs: kept + gained = the new links, kept + lost = ",
              "the "
            ),
            "old ones"
          )
        ),
        setequal(k[!lost], keys(b$requires)) &&
          setequal(k[!thick], keys(a$requires))
      )
      added <- setdiff(.vp_nodes(b), .vp_nodes(a))
      removed <- setdiff(.vp_nodes(a), .vp_nodes(b))
      check(
        label("added features in yellow, removed ones dashed"),
        all(vapply(
          added,
          function(f) {
            any(grepl(paste0('^  "', f, '" \\[fillcolor="#FFE9B8"'), d$lines))
          },
          TRUE
        )) &&
          all(vapply(
            removed,
            function(f) {
              any(grepl(
                paste0(
                  '^  "',
                  f,
                  '" \\[fillcolor="white", style="rounded,filled,dashed"'
                ),
                d$lines
              ))
            },
            TRUE
          ))
      )
      dctx <- dc(a, b, minimal = FALSE)
      check(
        label("context: only the features touched by a change"),
        setequal(
          dctx$nodes,
          unique(c(
            chg$from[thick | lost],
            chg$to[thick | lost],
            added,
            removed
          ))
        )
      )
      dm <- dc(a, b)
      km <- paste(dm$links$from, dm$links$to, sep = "\t")
      check(
        label(
          paste0(
            "minimal forms: a feature that only changed its atomic set is not ",
            "drawn as new"
          )
        ),
        !any(vapply(
          intersect(.vp_nodes(a), .vp_nodes(b)),
          function(f) {
            any(grepl(paste0('^  "', f, '" \\[fillcolor="#FFE9B8"'), dm$lines))
          },
          TRUE
        ))
      )
    }
    check(
      "drawing changes: an unknown graph, or a version without it, is an error",
      fails_with(
        vp_dot_compare(models$miband3, models$miband4, graph = "nope"),
        "should be one of"
      ) &&
        fails_with(
          vp_dot_compare(
            model_from_links(c("a"), name = "noalo"),
            models$miband4,
            graph = "atleastone"
          ),
          "has no atleastone graph"
        )
    )
    check(
      "drawing changes: excludes and at-least-one lines have no arrow head",
      all(grepl(
        "dir=none",
        grep(
          " -> ",
          vp_dot_compare(models$miband3, models$miband4, graph = "excludes") |>
            strsplit("\n") |>
            unlist(),
          value = TRUE
        )
      ))
    )
    if (nzchar(Sys.which("dot"))) {
      f <- vp_plot_compare(
        models$miband3,
        models$miband4,
        file.path(work, "plots", "cmp.pdf"),
        engine = "graphviz"
      )
      check(
        "drawing changes: a PDF file",
        identical(rawToChar(readBin(f, "raw", 5)), "%PDF-")
      )
      check(
        "drawing changes: a file that is not .pdf, .svg or .png is an error",
        fails_with(
          vp_plot_compare(models$miband3, models$miband4, "x.gif"),
          "must end in"
        )
      )
    }
  }
)
