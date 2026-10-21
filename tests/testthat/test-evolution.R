test_that(
  paste0(
    "Following a model through time: against `strong4vm diff`, and on ",
    "histories made by hand whose answers are known."
  ),
  {
    # ==========================================================================
    # Following a model through time: against `strong4vm diff`, and on histories
    # made by hand whose answers are known.
    # ==========================================================================
    section("evolution: vp_compare against strong4vm diff")
    pairs <- c(
      Map(c, head(gens, -1), gens[-1]),
      list(c("miband3_planned", "miband3")),
      list(c("miband3", "battery"))
    )
    # against the command line of Strong4VM: only when VARIPLEX_STRONG4VM gives
    # the program
    if (nzchar(program)) {
      for (p in pairs) {
        old <- fixtures[[p[1]]]$prefix
        new <- fixtures[[p[2]]]$prefix
        out <- file.path(work, "diff", paste0(p[1], "_", p[2]))
        dir.create(out, recursive = TRUE, showWarnings = FALSE)
        st <- system2(
          program,
          c("diff", old, new, "-o", out),
          stdout = FALSE,
          stderr = FALSE
        )
        js <- list.files(out, "diff_summary.json$", full.names = TRUE)
        if (st != 0 || !length(js)) {
          check(paste(p, collapse = " -> "), FALSE, "strong4vm diff failed")
          next
        }
        d <- jsonlite::fromJSON(js)
        r <- vp_compare(models[[p[1]]], models[[p[2]]])
        label <- function(what) paste0(p[1], " -> ", p[2], ": ", what)
        check(
          label("kept, added, removed"),
          all(
            r$kept == d$options$kept &
              r$added == d$options$added &
              r$removed == d$options$removed
          )
        )
        okg <- all(vapply(
          seq_len(nrow(r)),
          function(k) {
            g <- d$graphs[[r$graph[k]]]
            r$old_links[k] == g$old_links &&
              r$new_links[k] == g$new_links &&
              r$gained[k] == g$gained &&
              r$lost[k] == g$lost &&
              abs(r$jaccard[k] - g$jaccard) < 1e-5
          },
          TRUE
        ))
        check(
          label(
            paste0(
              "links old, new, gained, lost and Jaccard of every graph = ",
              "strong4vm diff"
            )
          ),
          okg
        )
        sp <- d$in_degree_spearman
        check(
          label("Spearman of the in-degrees = strong4vm diff"),
          (is.null(sp) && is.na(r$spearman[1])) ||
            (!is.null(sp) &&
              !is.na(r$spearman[1]) &&
              abs(r$spearman[1] - sp) < 1e-5)
        )
        for (g in r$graph) {
          ch <- vp_changed_links(models[[p[1]]], models[[p[2]]], g)
          csv <- list.files(out, paste0("diff_", g, ".csv$"), full.names = TRUE)
          if (length(csv)) {
            x <- utils::read.csv(csv, stringsAsFactors = FALSE)
            check(
              label(paste(
                "changed links of",
                g,
                "= the file of strong4vm diff"
              )),
              nrow(ch) == nrow(x) &&
                sum(ch$change == "gained") == r$gained[r$graph == g] &&
                sum(ch$change == "lost") == r$lost[r$graph == g]
            )
          }
        }
        sm <- vp_state_moves(models[[p[1]]], models[[p[2]]])
        states <- utils::read.csv(
          list.files(out, "diff_states.csv$", full.names = TRUE),
          stringsAsFactors = FALSE,
          na.strings = ""
        )
        check(
          label("state moves = the moves of diff_states.csv (absent = empty)"),
          nrow(sm) == nrow(states)
        )
      }
    }

    section("evolution: histories made by hand")
    mk <- function(
      name,
      nodes,
      req = NULL,
      exc = NULL,
      core = character(0),
      dead = character(0)
    ) {
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
        core = core,
        dead = dead,
        name = name
      )
    }
    v1 <- mk("v1", c("a", "b", "c"), data.frame(from = "a", to = "b"))
    v2 <- mk(
      "v2",
      c("a", "b", "c"),
      data.frame(from = c("a", "c"), to = c("b", "b"))
    ) # only gains
    # only a loss
    v3 <- mk("v3", c("a", "b", "c"), data.frame(from = "c", to = "b"))
    v4 <- mk("v4", c("a", "b", "c"), data.frame(from = "c", to = "a")) # both
    v5 <- mk("v5", c("a", "b", "c"), data.frame(from = "c", to = "a")) # nothing
    h <- tibble::tibble(
      version = factor(paste0("v", 1:5), levels = paste0("v", 1:5)),
      model = list(v1, v2, v3, v4, v5)
    )
    et <- vp_edit_type(h)
    check(
      "edit type: only gains, only losses, both, nothing",
      identical(
        et$type,
        c(
          "specialisation?",
          "generalisation?",
          "arbitrary edit",
          "refactoring?"
        )
      )
    )
    hc <- vp_history_changes(h)
    check(
      "history changes: one row per step and graph",
      nrow(hc) == 4 * 2 &&
        all(hc$jaccard[hc$graph == "requires"] == c(1 / 2, 1 / 2, 0, 1))
    )
    sizes <- vp_history_sizes(h)
    check(
      "history sizes: one row per version, the counts of each",
      nrow(sizes) == 5 && all(sizes$requires == c(1, 2, 1, 1, 1))
    )

    # states and flips: f is variable, then core, then variable again; g
    # disappears and comes back; r is renamed to s
    w1 <- mk(
      "w1",
      c("f", "g", "r", "k"),
      data.frame(from = c("r", "k"), to = c("k", "g"))
    )
    w2 <- mk("w2", c("k", "s"), data.frame(from = "s", to = "k"), core = "f")
    w3 <- mk(
      "w3",
      c("f", "g", "k", "s"),
      data.frame(from = c("s", "k"), to = c("k", "g"))
    )
    hw <- tibble::tibble(
      version = factor(c("w1", "w2", "w3"), levels = c("w1", "w2", "w3")),
      model = list(w1, w2, w3)
    )
    ff <- vp_flip_flops(hw)
    check(
      paste0(
        paste0(
          "flip-flops: f (variable > core > variable) and g (variable > ",
          "absent > "
        ),
        "variable)"
      ),
      setequal(ff$feature, c("f", "g")) &&
        ff$path[ff$feature == "f"] == "variable > core > variable"
    )
    st <- vp_feature_states(hw)
    check(
      "feature states: one row per feature and version",
      nrow(st) == 5 * 3 &&
        st$state[st$version == "w2" & st$feature == "r"] == "absent"
    )
    lc <- vp_life_cycle(hw)
    check(
      "life cycle: the shares of each state add up to 1",
      all(abs(tapply(lc$share, lc$before, sum) - 1) < 1e-12)
    )
    rn <- vp_rename_candidates(
      w1,
      mk(
        "w1b",
        c("f", "g", "s", "k"),
        data.frame(from = c("s", "k"), to = c("k", "g"))
      )
    )
    check(
      "rename candidates: r renamed to s, found by its links (similarity 1)",
      nrow(rn) == 1 && rn$old == "r" && rn$new == "s" && rn$similarity == 1
    )
    check(
      "rename candidates: none when nothing was removed",
      nrow(vp_rename_candidates(w1, w1)) == 0
    )
    w1b <- mk(
      "w1b",
      c("f", "g", "s", "k"),
      data.frame(from = c("s", "k"), to = c("k", "g"))
    )
    rf <- tempfile(fileext = ".txt")
    rn0 <- vp_rename_candidates(w1, w1b, file = rf, name_threshold = 0)
    check(
      paste0(
        paste0(
          "rename candidates: the file has a comment and r<tab>s when names ",
          "need "
        ),
        "not be alike"
      ),
      identical(rn0, rn) &&
        identical(
          grep("^#", readLines(rf), invert = TRUE, value = TRUE),
          "r\ts"
        ) &&
        startsWith(readLines(rf)[1], "# ")
    )
    vp_rename_candidates(w1, w1b, file = rf)
    check(
      paste0(
        "rename candidates: names r and s (name similarity 0) stay out of the ",
        "file by default"
      ),
      length(grep("^#", readLines(rf), invert = TRUE)) == 0
    )
    check(
      paste0(
        paste0(
          "rename candidates: a name threshold outside [0, 1] or a bad file ",
          "name "
        ),
        "stops"
      ),
      inherits(
        tryCatch(
          vp_rename_candidates(w1, w1b, name_threshold = 2),
          error = function(e) e
        ),
        "error"
      ) &&
        inherits(
          tryCatch(
            vp_rename_candidates(w1, w1b, file = ""),
            error = function(e) {
              e
            }
          ),
          "error"
        )
    )
    unlink(rf)

    # attachment, hubs, lifetime, disruptions
    x1 <- mk(
      "x1",
      c("hub", "p", "q"),
      data.frame(from = c("p", "q"), to = c("hub", "hub"))
    )
    x2 <- mk(
      "x2",
      c("hub", "p", "q", "n1", "n2"),
      data.frame(
        from = c("p", "q", "n1", "n2"),
        to = c("hub", "hub", "hub", "p")
      )
    )
    hx <- tibble::tibble(
      version = factor(c("x1", "x2"), levels = c("x1", "x2")),
      model = list(x1, x2)
    )
    at <- vp_attachment(hx)
    check(
      paste0(
        paste0(
          "attachment: the hub had 2 direct dependants and got 1 newcomer; p ",
          "had "
        ),
        "0 and got 1"
      ),
      at$direct_dependants[at$feature == "hub"] == 2 &&
        at$new_dependants[at$feature == "hub"] == 1 &&
        at$new_dependants[at$feature == "p"] == 1
    )
    hs <- vp_hub_stability(hx, top = 1)
    check("hub stability: the hub stays the top hub", hs$top_kept == 1)
    y <- lapply(1:6, function(k) {
      mk(
        paste0("y", k),
        c("a", "b", "c"),
        exc = if (k %in% 2:3) {
          data.frame(from = c("a", "a"), to = c("b", "c"))
        } else {
          data.frame(from = "a", to = "b")
        }
      )
    })
    hy <- tibble::tibble(
      version = factor(paste0("y", 1:6), levels = paste0("y", 1:6)),
      model = y
    )
    lt <- vp_link_lifetime(hy, "excludes", horizon = 2)
    check(
      paste0(
        "link lifetime: a conflict born in y2 lasts one more version, then ",
        "is gone"
      ),
      lt$followed[1] == 1 &&
        lt$still_present[1] == 1 &&
        lt$still_present[2] == 0
    )
    z <- lapply(1:30, function(k) {
      mk(
        paste0("z", k),
        letters[1:6],
        req = if (k == 15) {
          data.frame(from = c("a", "b", "c", "d"), to = c("e", "e", "f", "f"))
        } else {
          data.frame(from = "a", to = "b")
        }
      )
    })
    hz <- tibble::tibble(
      version = factor(paste0("z", 1:30), levels = paste0("z", 1:30)),
      model = z
    )
    dz <- vp_disruptions(hz)
    check(
      paste0(
        "disruptions: the two steps around the odd version are flagged, the ",
        "others not"
      ),
      setequal(dz$step[dz$disruption & dz$graph == "requires"], c(14, 15)) &&
        !any(dz$disruption[dz$graph == "excludes"])
    )
    check(
      "growth: the slope of the fit is that of lm on the sizes",
      local({
        s <- vp_history_sizes(
          busy <- vp_read_history(c(
            fixtures$miband3$prefix,
            fixtures$miband4$prefix,
            fixtures$miband6$prefix,
            fixtures$miband8$prefix
          ))
        )
        g <- vp_growth(busy)
        abs(g$slope[1] - coef(lm(log(s$requires) ~ log(s$features)))[2]) < 1e-12
      })
    )
    check(
      paste0(
        "AUC: 1 for a perfect ranking, 0 for the reverse, 0.5 for ties, NA ",
        "without both outcomes"
      ),
      vp_auc(1:4, c(FALSE, FALSE, TRUE, TRUE)) == 1 &&
        vp_auc(4:1, c(FALSE, FALSE, TRUE, TRUE)) == 0 &&
        vp_auc(rep(1, 4), c(FALSE, TRUE, FALSE, TRUE)) == 0.5 &&
        is.na(vp_auc(1:3, c(TRUE, TRUE, TRUE)))
    )
    gh <- vp_read_history(
      vapply(gens, function(g) fixtures[[g]]$prefix, ""),
      versions = gens
    )
    pt <- vp_prediction_table(gh, horizon = 2)
    check(
      "prediction table: one row per feature of every version but the last",
      nrow(pt) ==
        sum(vapply(gh$model[-nrow(gh)], function(m) length(.vp_nodes(m)), 0))
    )
    check(
      paste0(
        "prediction table: gone_next is TRUE exactly for features absent from ",
        "the next version"
      ),
      all(vapply(
        seq_len(nrow(pt)),
        function(k) {
          v <- match(as.character(pt$version[k]), gens)
          pt$gone_next[k] ==
            !(pt$feature[k] %in% gh$model[[v + 1]]$features$feature)
        },
        TRUE
      ))
    )
    fc <- vp_forecast_size(gh, train = 4)
    check(
      "forecast: errors are |forecast - observed| / observed",
      all(
        abs(
          fc$error_same_ratio - abs(fc$same_ratio - fc$observed) / fc$observed
        ) <
          1e-12,
        na.rm = TRUE
      )
    )
    ch <- vp_community_history(gh[4:7, ])
    check(
      "community history: agreements between 0 and 1",
      all(ch$between_versions >= 0 & ch$between_versions <= 1 + 1e-9)
    )
  }
)
