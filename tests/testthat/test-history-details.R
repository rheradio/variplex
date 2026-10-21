test_that(
  paste0(
    paste0(
      "The details of the functions over histories that the manual explains ",
      "step "
    ),
    "by step: growth laws and their NA,"
  ),
  {
    # ==========================================================================
    # The details of the functions over histories that the manual explains step
    # by step: growth laws and their NA, vp_history_apply() and the shapes of
    # its answers, eras, disruptions, link lifetimes, the life cycle, the
    # prediction table, and the file of renames read by `strong4vm diff
    # --rename`. Histories made by hand, so the answers are known.
    # ==========================================================================
    section("evolution: details explained in the manual")

    mk <- function(name, nodes, req = NULL, exc = NULL) {
      model_from_links(
        nodes,
        if (is.null(req)) {
          data.frame(from = character(0), to = character(0))
        } else {
          req
        },
        if (is.null(exc)) {
          data.frame(from = character(0), to = character(0))
        } else {
          exc
        },
        name = name
      )
    }
    hist_of <- function(ms) {
      tibble::tibble(
        version = factor(names(ms), levels = names(ms)),
        model = unname(ms)
      )
    }

    # --- growth laws: the user's Mi Band 1 to 4; log(0) leaves versions out;
    # fewer than three points give NA
    band14 <- hist_of(models[c("miband1", "miband2", "miband3", "miband4")])
    sz <- vp_history_sizes(band14)
    gr <- vp_growth(band14)
    for (k in gr$links) {
      n_ok <- sum(sz[[k]] > 0 & sz$features > 0)
      check(
        paste0(
          "growth: ",
          k,
          paste0(
            " has a slope exactly when three or more versions have features ",
            "and links ("
          ),
          n_ok,
          ")"
        ),
        identical(is.na(gr$slope[gr$links == k]), n_ok < 3) &&
          identical(is.na(gr$r_squared[gr$links == k]), n_ok < 3)
      )
    }
    check(
      "growth: the Mi Band 1 (no features) never counts",
      sz$features[1] == 0
    )
    # an exact power law, links = 2 * features^1.5, gives slope 1.5 and
    # r_squared 1 links = n^1.5 / 2 (n = 4, 16, 36, 64 give 4, 32, 108, 256
    # links, exactly), acyclic so nothing merges
    pl <- lapply(c(4, 16, 36, 64), function(n) {
      nodes <- paste0("f", seq_len(n))
      pr <- t(utils::combn(n, 2))[seq_len(n^1.5 / 2), , drop = FALSE]
      mk(
        paste0("p", n),
        nodes,
        data.frame(from = nodes[pr[, 1]], to = nodes[pr[, 2]])
      )
    })
    names(pl) <- paste0("p", c(4, 16, 36, 64))
    gp <- vp_growth(hist_of(pl))
    check(
      paste0(
        "growth: an exact power law with exponent 1.5 gives slope 1.5 and ",
        "r_squared 1"
      ),
      abs(gp$slope[gp$links == "requires"] - 1.5) < 1e-9 &&
        gp$r_squared[gp$links == "requires"] > 1 - 1e-9,
      paste(gp$slope, gp$r_squared)
    )

    # --- vp_history_apply: the three shapes of an answer, extra arguments,
    # empty blocks, errors
    h7 <- hist_of(models[gens])
    a1 <- vp_history_apply(h7, vp_depth)
    check(
      "history_apply: a number gives one row per version and a column value",
      nrow(a1) == length(gens) &&
        identical(names(a1), c("version", "value")) &&
        identical(levels(a1$version), gens)
    )
    a2 <- vp_history_apply(h7, function(m) {
      c(depth = vp_depth(m), width = vp_width(m))
    })
    check(
      "history_apply: a named vector gives one column per name",
      identical(names(a2), c("version", "depth", "width")) &&
        all(a2$depth == a1$value)
    )
    a3 <- vp_history_apply(h7, vp_most_decisive, n = 2)
    nv <- vapply(
      models[gens],
      function(m) sum(m$features$status == "variable"),
      0
    )
    check(
      paste0(
        "history_apply: a tibble keeps its rows, arguments after f are passed ",
        "on, and an empty answer adds no row"
      ),
      all(table(factor(a3$version, levels = gens)) == pmin(2, nv)) &&
        !("miband1" %in% as.character(a3$version))
    )
    check(
      "history_apply: f given by name works",
      identical(vp_history_apply(h7, "vp_depth"), a1)
    )
    a4 <- vp_history_apply(h7, function(m) {
      if (vp_depth(m) > 2) {
        c(depth = vp_depth(m), deep = 1)
      } else {
        c(depth = vp_depth(m))
      }
    })
    check(
      "history_apply: a column missing in some versions is NA there",
      all(is.na(a4$deep[a4$depth <= 2])) && all(a4$deep[a4$depth > 2] == 1)
    )
    check(
      paste0(
        "history_apply: a list, or several numbers without names, stop and ",
        "name the version"
      ),
      fails_with(vp_history_apply(h7, function(m) list(1)), "miband1") &&
        fails_with(vp_history_apply(h7, function(m) 1:2), "miband1")
    )

    # --- eras: whole numbers 1..n, runs of consecutive versions, the obvious
    # split of two blocks
    block_a <- mk(
      "A",
      c("a", "b", "c", "d"),
      data.frame(from = c("a", "b"), to = c("b", "c"))
    )
    block_b <- mk(
      "B",
      c("a", "b", "c", "d"),
      data.frame(from = c("d", "c"), to = c("a", "a"))
    )
    h6 <- hist_of(list(
      v1 = block_a,
      v2 = block_a,
      v3 = block_a,
      v4 = block_b,
      v5 = block_b,
      v6 = block_b
    ))
    e2 <- vp_eras(h6, 2)
    check(
      "eras: two blocks of identical versions are the two eras, with spread 0",
      identical(e2$era, c(1L, 1L, 1L, 2L, 2L, 2L)) && all(e2$spread == 0)
    )
    check(
      "eras: k = 1 is one era, k = n one version per era",
      all(vp_eras(h6, 1)$era == 1) && identical(vp_eras(h6, 6)$era, 1:6)
    )
    check(
      "eras: k outside 1..n, or not whole, stops",
      fails_with(vp_eras(h6, 0), "between 1") &&
        fails_with(vp_eras(h6, 7), "between 1") &&
        fails_with(vp_eras(h6, 1.5), "whole number")
    )
    e3 <- vp_eras(h7, 3)
    check(
      "eras: always runs of consecutive versions, numbered in time order",
      all(diff(e3$era) %in% c(0, 1)) && e3$era[1] == 1 && max(e3$era) == 3
    )
    vd <- vp_version_distance(h6)
    check(
      paste0(
        paste0(
          "version distance: one row per pair, the older first, 0 inside a ",
          "block "
        ),
        "and 1 across"
      ),
      nrow(vd) == 15 &&
        all(as.integer(vd$from) < as.integer(vd$to)) &&
        all(
          vd$distance[
            (vd$from %in% c("v1", "v2", "v3")) ==
              (vd$to %in% c("v1", "v2", "v3"))
          ] ==
            0
        ) &&
        all(
          vd$distance[
            (vd$from %in% c("v1", "v2", "v3")) !=
              (vd$to %in% c("v1", "v2", "v3"))
          ] ==
            1
        )
    )

    # --- disruptions: per graph, robust score, one-sided, nothing flagged when
    # every step is alike
    calm <- lapply(1:8, function(i) block_a)
    names(calm) <- paste0("c", 1:8)
    dc <- vp_disruptions(hist_of(calm))
    check(
      "disruptions: a history where nothing changes flags nothing (score 0)",
      all(dc$score == 0) && !any(dc$disruption)
    )
    # small changes at every step and one big step: only the big one is flagged
    # a chain f1 -> ... -> f21 with one or two extra links that come and go
    # (small, uneven changes), and one version whose links are all different
    fn <- paste0("f", 1:21)
    chain <- data.frame(from = fn[-21], to = fn[-1])
    small <- lapply(1:12, function(i) {
      mk(
        paste0("s", i),
        fn,
        rbind(
          chain,
          if (i %% 2) data.frame(from = "f1", to = "f3"),
          if (i %% 3 == 0) data.frame(from = "f1", to = "f4"),
          if (i %% 4 == 0) data.frame(from = "f2", to = "f5")
        )
      )
    })
    small[[7]] <- mk(
      "s7",
      fn,
      data.frame(from = fn[c(1, 3, 5)], to = fn[c(21, 20, 19)])
    )
    names(small) <- paste0("s", 1:12)
    ds <- vp_disruptions(hist_of(small))
    dr <- ds[ds$graph == "requires", ]
    check(
      paste0(
        "disruptions: the steps into and out of the odd version are the only ",
        "ones flagged"
      ),
      identical(which(dr$disruption), c(6L, 7L)),
      paste(round(dr$score, 2), collapse = " ")
    )
    x <- 1 - dr$jaccard
    s <- if (mad(x) > 0) mad(x) else sd(x)
    check(
      paste0(
        "disruptions: score = (change - median) / MAD (or the standard ",
        "deviation when the MAD is 0)"
      ),
      all(abs(dr$score - (x - median(x)) / s) < 1e-12)
    )
    check(
      "disruptions: a step that changed less than usual is never flagged",
      !any(dr$disruption[x <= median(x)])
    )

    # --- link lifetime: born between old features, followed at each age,
    # present at that version only
    chg <- function(...) {
      p <- c(...)
      data.frame(from = p[c(TRUE, FALSE)], to = p[c(FALSE, TRUE)])
    }
    nodes <- c("a", "b", "c", "n")
    lt_h <- hist_of(list(
      t1 = mk("t1", c("a", "b", "c"), chg("a", "b")),
      # born: b->c (old ends); n->a has a new end, left out
      t2 = mk("t2", nodes, chg("a", "b", "b", "c", "n", "a")),
      t3 = mk("t3", nodes, chg("a", "b", "n", "a")), # b->c gone
      t4 = mk("t4", nodes, chg("a", "b", "b", "c", "n", "a"))
    )) # b->c back (and born again)
    lt <- vp_link_lifetime(lt_h, "requires", horizon = 3)
    check(
      paste0(
        "link lifetime: followed shrinks with the age; a link that comes back ",
        "counts as present at that version"
      ),
      identical(lt$followed, c(1, 1, 0)) &&
        identical(lt$still_present, c(0, 1, 0)) &&
        is.na(lt$share[3])
    )

    # --- life cycle: shares per state add up to 1; absent -> absent is left out
    lc <- vp_life_cycle(h7)
    check(
      paste0(
        "life cycle: shares of each state add up to 1, and no absent -> ",
        "absent row"
      ),
      all(abs(tapply(lc$share, lc$before, sum) - 1) < 1e-12) &&
        !any(lc$before == "absent" & lc$after == "absent")
    )
    fs <- vp_feature_states(h7)
    check(
      "feature states: one row per feature and version",
      nrow(fs) == length(unique(fs$feature)) * length(gens)
    )

    # --- prediction table: one row per variable feature and version except the
    # last; outcomes read later
    pt <- vp_prediction_table(lt_h, horizon = 2)
    check(
      "prediction table: no row for the last version",
      !("t4" %in% as.character(pt$version))
    )
    check(
      paste0(
        paste0(
          "prediction table: age counts from the first version where the ",
          "feature "
        ),
        "can vary"
      ),
      pt$age[pt$version == "t3" & pt$feature == "n"] == 1 &&
        pt$age[pt$version == "t3" & pt$feature == "a"] == 2
    )
    check(
      "prediction table: gone_later is NA when t + horizon is past the end",
      all(is.na(pt$gone_later[pt$version == "t3"])) &&
        !any(is.na(pt$gone_later[pt$version %in% c("t1", "t2")]))
    )
    gone <- hist_of(list(
      u1 = mk("u1", c("a", "b")),
      u2 = mk("u2", c("a")),
      u3 = mk("u3", c("a", "b"))
    ))
    pg <- vp_prediction_table(gone, horizon = 2)
    check(
      paste0(
        paste0(
          "prediction table: gone_next sees a feature leave; gone_later at t ",
          "+ 2 "
        ),
        "sees it back"
      ),
      pg$gone_next[pg$version == "u1" & pg$feature == "b"] &&
        !pg$gone_later[pg$version == "u1" & pg$feature == "b"]
    )
    check(
      "auc: a perfect ranking is 1, the reverse 0, ties count one half",
      vp_auc(c(1, 2, 3, 4), c(FALSE, FALSE, TRUE, TRUE)) == 1 &&
        vp_auc(c(4, 3, 2, 1), c(FALSE, FALSE, TRUE, TRUE)) == 0 &&
        vp_auc(c(1, 1), c(FALSE, TRUE)) == 0.5
    )

    # --- renames: the file is read by strong4vm diff --rename, names with
    # spaces included
    uvl <- function(path, names) {
      writeLines(
        c(
          "features",
          "\tRoot {abstract}",
          "\t\toptional",
          paste0("\t\t\t\"", names, "\""),
          "constraints",
          sprintf("\t\"%s\" => \"%s\"", names[3], names[1]),
          sprintf("\t\"%s\" => !\"%s\"", names[3], names[2])
        ),
        path
      )
    }
    rdir <- file.path(work, "renames")
    dir.create(rdir, showWarnings = FALSE)
    uvl(file.path(rdir, "before.uvl"), c("Alpha", "Beta", "Old feature"))
    uvl(file.path(rdir, "after.uvl"), c("Alpha", "Beta", "New feature"))
    pb <- tryCatch(
      run_vp(file.path(rdir, "before.uvl"), rdir),
      error = function(e) NULL
    )
    pa <- tryCatch(
      run_vp(file.path(rdir, "after.uvl"), rdir),
      error = function(e) NULL
    )
    if (is.null(pb) || is.null(pa)) {
      skip_note(
        "renames: the file works with strong4vm diff --rename",
        "Strong4VM did not accept the quoted names"
      )
    } else {
      rfile <- file.path(rdir, "renames.txt")
      rc <- vp_rename_candidates(vp_read(pb), vp_read(pa), file = rfile)
      check(
        paste0(
          "renames: the renamed feature with a space is the candidate, and is ",
          "written"
        ),
        nrow(rc) == 1 &&
          rc$old == "Old feature" &&
          rc$new == "New feature" &&
          rc$similarity == 1 &&
          identical(
            grep("^#", readLines(rfile), invert = TRUE, value = TRUE),
            "Old feature\tNew feature"
          )
      )
      if (nzchar(program)) {
        # strong4vm diff --rename: only when VARIPLEX_STRONG4VM gives the
        # program
        out_d <- file.path(rdir, "diff")
        st <- system2(
          program,
          c("diff", pb, pa, "-o", out_d, "--rename", rfile),
          stdout = TRUE,
          stderr = TRUE
        )
        check(
          paste0(
            "renames: strong4vm diff --rename reads the file and keeps the ",
            "feature"
          ),
          is.null(attr(st, "status")) &&
            any(grepl("3 kept, 0 added, 0 removed", st)),
          paste(st, collapse = " | ")
        )
        vp_rename_candidates(
          vp_read(pb),
          vp_read(pa),
          file = rfile,
          name_threshold = 0.95
        )
        check(
          paste0(
            "renames: a pair below name_threshold is not written, and diff ",
            "still reads the file"
          ),
          length(grep("^#", readLines(rfile), invert = TRUE)) == 0 &&
            is.null(attr(
              system2(
                program,
                c("diff", pb, pa, "-o", out_d, "--rename", rfile),
                stdout = TRUE,
                stderr = TRUE
              ),
              "status"
            ))
        )
      }
    }
  }
)
