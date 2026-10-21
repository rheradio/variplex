test_that(
  paste0(
    "Splitting the configuration among teams: vp_team_links, vp_teams, ",
    "vp_team_moves, vp_team_order, vp_split_after,"
  ),
  {
    # ==========================================================================
    # Splitting the configuration among teams: vp_team_links, vp_teams,
    # vp_team_moves, vp_team_order, vp_split_after, vp_splitting_decisions.
    # Interference is checked against the oracle (two features interfere when
    # not all four combinations occur); the counts and the order against brute
    # force on the links.
    # ==========================================================================
    section("teams")
    withr::local_seed(20261015)
    ukey2 <- function(a, b) paste(pmin(a, b), pmax(a, b), sep = "\t")
    all_links <- function(m) {
      dplyr::bind_rows(m$requires, m$excludes, m$atleastone)
    }
    for (n in pick(names(oracle))) {
      m <- models[[n]]
      truth_t <- oracle[[n]]$T
      vars <- oracle[[n]]$V
      if (length(vars) < 2) {
        next
      }
      label <- function(s) paste0(s, " (", n, ")")
      tm <- stats::setNames(
        sample(
          paste0("t", seq_len(sample(1:4, 1))),
          length(vars),
          replace = TRUE
        ),
        vars
      )
      teams <- tibble::tibble(feature = vars, team = unname(tm))

      # the links between teams = the pairs of features of two teams that the
      # oracle says interfere
      tl <- vp_team_links(m, teams)
      pairs <- which(upper.tri(truth_t$tt), arr.ind = TRUE)
      a <- truth_t$names[pairs[, 1]]
      b <- truth_t$names[pairs[, 2]]
      inter <- !(truth_t$tt[pairs] &
        truth_t$tf[pairs] &
        t(truth_t$tf)[pairs] &
        truth_t$ff[pairs])
      want <- ukey2(a, b)[inter & tm[a] != tm[b]]
      check(
        label(
          paste0(
            "team links: exactly the pairs of features of two teams that ",
            "interfere (oracle)"
          )
        ),
        setequal(unique(ukey2(tl$from, tl$to)), want)
      )
      check(
        label(
          "team links: the team of each end is the given one, and they differ"
        ),
        all(tl$from_team == tm[tl$from]) &&
          all(tl$to_team == tm[tl$to]) &&
          all(tl$from_team != tl$to_team)
      )

      # the summary of each team, by brute force on the links
      chg <- all_links(m)
      st <- vp_teams(m, teams)
      touched <- unique(c(a[inter & tm[a] != tm[b]], b[inter & tm[a] != tm[b]]))
      okst <- all(vapply(
        seq_len(nrow(st)),
        function(k) {
          t <- st$team[k]
          mine <- vars[tm == t]
          inside <- sum(tm[chg$from] == t & tm[chg$to] == t)
          outside <- sum(xor(tm[chg$from] == t, tm[chg$to] == t))
          linked <- length(unique(c(
            tm[chg$to][tm[chg$from] == t & tm[chg$to] != t],
            tm[chg$from][tm[chg$to] == t & tm[chg$from] != t]
          )))
          st$features[k] == length(mine) &&
            st$links_inside[k] == inside &&
            st$links_outside[k] == outside &&
            st$teams_linked[k] == linked &&
            st$free_features[k] == sum(!mine %in% touched) &&
            abs(st$free_share[k] - st$free_features[k] / st$features[k]) < 1e-12
        },
        TRUE
      ))
      check(
        label(
          paste0(
            "team summary: counts, linked teams and free features (free ",
            "checked against the oracle)"
          )
        ),
        okst &&
          setequal(st$team, unique(tm)) &&
          sum(st$links_inside) + sum(st$links_outside) / 2 == nrow(chg)
      )

      # moves: brute-force count of the links of each feature to each team
      mv <- vp_team_moves(m, teams)
      okmv <- all(vapply(
        vars,
        function(f) {
          other <- c(tm[chg$to][chg$from == f], tm[chg$from][chg$to == f])
          own <- sum(other == tm[f])
          rest <- table(other[other != tm[f]])
          best <- if (length(rest)) max(rest) else 0
          row <- mv[mv$feature == f, ]
          if (best > own) {
            nrow(row) == 1 &&
              row$links_own == own &&
              row$links_better == best &&
              row$better_team %in% names(rest)[rest == best]
          } else {
            nrow(row) == 0
          }
        },
        TRUE
      ))
      check(
        label(
          paste0(
            paste0(
              "team moves: exactly the features with more links to another ",
              "team, "
            ),
            "with the counts"
          )
        ),
        okmv
      )

      # the order, against the oracle: X waits for Y when a feature of X
      # requires one of Y
      ord <- vp_team_order(m, teams)
      ts <- sort(unique(tm))
      k <- length(ts)
      w_mat <- matrix(FALSE, k, k, dimnames = list(ts, ts))
      for (i in seq_along(vars)) {
        for (j in seq_along(vars)) {
          if (
            i != j &&
              tm[vars[i]] != tm[vars[j]] &&
              !truth_t$tf[vars[i], vars[j]]
          ) {
            w_mat[tm[vars[i]], tm[vars[j]]] <- TRUE
          }
        }
      }
      imm <- w_mat
      for (s in seq_len(k)) {
        imm <- imm | (imm %*% w_mat > 0)
      } # reachability
      block <- function(t) ts[(imm[t, ] & imm[, t]) | ts == t]
      rnd <- integer(0)
      level <- function(t) {
        if (!is.na(rnd[t])) {
          return(rnd[t])
        }
        later <- setdiff(ts[imm[t, ]], block(t))
        # nolint start: assignment_linter. A closure updates its parent.
        rnd[t] <<- if (length(later) == 0) {
          1L
        } else {
          max(vapply(later, level, 0L)) + 1L
        }
        # nolint end
        rnd[t]
      }
      rnd <- stats::setNames(rep(NA_integer_, k), ts)
      for (t in ts) {
        level(t)
      }
      agree <- function(t) {
        x <- character(0)
        for (i in vars[tm == t]) {
          for (j in vars[tm != t]) {
            if (!truth_t$tt[i, j] || !truth_t$ff[i, j]) x <- c(x, tm[j])
          }
        }
        sort(unique(x))
      }
      split_list <- function(s) {
        if (s == "") character(0) else strsplit(s, ", ", fixed = TRUE)[[1]]
      }
      okord <- all(vapply(
        seq_len(nrow(ord)),
        function(r) {
          t <- ord$team[r]
          ord$round[r] == rnd[t] &&
            setequal(
              split_list(ord$decide_together_with[r]),
              setdiff(block(t), t)
            ) &&
            setequal(
              split_list(ord$waits_for[r]),
              setdiff(ts[w_mat[t, ]], block(t))
            ) &&
            setequal(split_list(ord$must_agree_with[r]), agree(t))
        },
        TRUE
      ))
      check(
        label(
          paste0(
            "team order: rounds, blocks that decide together, waits and ",
            "agreements equal the oracle's"
          )
        ),
        okord && setequal(ord$team, ts)
      )

      # decisions taken first: what they settle is truly settled; what is left
      # splits along no link
      for (trial in 1:3) {
        d <- sample(vars, min(length(vars), sample(1:2, 1)))
        on <- d[runif(length(d)) < 0.5]
        off <- setdiff(d, on)
        if (!possible(truth_t, on, off)) {
          check(
            label("split after impossible decisions: refused"),
            fails_with(vp_split_after(m, on, off), "cannot go together")
          )
          next
        }
        sp <- vp_split_after(m, on, off)
        dec <- attr(sp, "decided")
        x_mat <- truth_t$X
        rows <- rep(TRUE, nrow(x_mat))
        for (f in on) {
          rows <- rows & x_mat[, f]
        }
        for (f in off) {
          rows <- rows & !x_mat[, f]
        }
        settled <- all(vapply(
          dec,
          function(f) length(unique(x_mat[rows, f])) == 1,
          TRUE
        ))
        cross <- chg[chg$from %in% sp$feature & chg$to %in% sp$feature, ]
        check(
          label(
            paste0(
              paste0(
                "split after decisions: settled features are fixed (oracle), ",
                "the "
              ),
              "parts share no link, nothing is lost"
            )
          ),
          settled &&
            setequal(c(dec, sp$feature), vars) &&
            !any(dec %in% sp$feature) &&
            all(
              sp$part[match(cross$from, sp$feature)] ==
                sp$part[match(cross$to, sp$feature)]
            )
        )
      }
      sd <- vp_splitting_decisions(m)
      oksd <- all(vapply(
        seq_len(min(nrow(sd), 6)),
        function(r) {
          p <- if (sd$decision[r] == "selected") {
            vp_split_after(m, selected = sd$feature[r])
          } else {
            suppressWarnings(vp_split_after(m, deselected = sd$feature[r]))
          }
          sd$decided[r] == length(attr(p, "decided")) &&
            sd$parts[r] == dplyr::n_distinct(p$part) &&
            sd$largest_part[r] == if (nrow(p)) max(p$size) else 0
        },
        TRUE
      ))
      check(
        label(
          paste0(
            "splitting decisions: two per feature, each the answer of ",
            "vp_split_after, sorted"
          )
        ),
        oksd && nrow(sd) == 2 * length(vars) && !is.unsorted(sd$largest_part)
      )

      # the minimal form: measures read the written links; the order is an
      # inference and does not change
      mm <- vp_minimal(m)
      ml <- all_links(mm)
      rep_of <- .vp_representative(m)
      # no atomic set split between teams
      whole_sets <- all(tm[names(rep_of)] == tm[rep_of])
      check(
        label(
          paste0(
            "on the minimal form: team links are the minimal links between ",
            "teams; the order is the same if no atomic set is split"
          )
        ),
        nrow(vp_team_links(mm, teams)) == sum(tm[ml$from] != tm[ml$to]) &&
          (!whole_sets || identical(vp_team_order(mm, teams), ord))
      )
    }

    band <- models$miband3
    bt <- tibble::tibble(
      feature = .vp_nodes(band),
      team = ifelse(grepl("BLE|BT", .vp_nodes(band)), "radio", "rest")
    )
    check(
      paste0(
        "teams: a named vector gives the same answer as a tibble, and another ",
        "column name works"
      ),
      identical(
        vp_teams(band, stats::setNames(bt$team, bt$feature)),
        vp_teams(band, bt)
      ) &&
        identical(
          vp_teams(band, dplyr::rename(bt, owner = team)),
          vp_teams(band, bt)
        )
    )
    check(
      paste0(
        "teams: a misspelt feature, a feature in two teams and a missing team ",
        "are refused"
      ),
      fails_with(
        vp_teams(
          band,
          dplyr::bind_rows(bt, tibble::tibble(feature = "Scren", team = "x"))
        ),
        "not a feature"
      ) &&
        fails_with(
          vp_teams(
            band,
            dplyr::bind_rows(bt, tibble::tibble(feature = "Screen", team = "x"))
          ),
          "more than one team"
        ) &&
        fails_with(
          vp_teams(
            band,
            dplyr::mutate(bt, team = ifelse(feature == "NFC", NA, team))
          ),
          "NA"
        )
    )
    w <- tryCatch(vp_teams(band, bt[-1, ]), warning = function(w) {
      conditionMessage(w)
    })
    check(
      "teams: a feature without a team warns and goes to (unassigned)",
      is.character(w) &&
        grepl("unassigned", w) &&
        "(unassigned)" %in% suppressWarnings(vp_teams(band, bt[-1, ]))$team
    )
    check(
      "teams: core features may be listed and are ignored",
      identical(
        vp_teams(
          band,
          dplyr::bind_rows(
            bt,
            tibble::tibble(feature = "Pedometer", team = "rest")
          )
        ),
        vp_teams(band, bt)
      )
    )
    check(
      paste0(
        "teams: on the minimal form, a member of an atomic set gives the team ",
        "of its node (Screen from OLED)"
      ),
      identical(
        vp_teams(vp_minimal(band), dplyr::filter(bt, feature != "Screen")),
        vp_teams(vp_minimal(band), bt)
      )
    )
    empty <- models$miband1
    check(
      paste0(
        "teams on a model with no feature that can vary: every function runs ",
        "and answers nothing"
      ),
      nrow(vp_team_links(
        empty,
        tibble::tibble(feature = character(0), team = character(0))
      )) ==
        0 &&
        nrow(vp_teams(
          empty,
          tibble::tibble(feature = character(0), team = character(0))
        )) ==
          0 &&
        nrow(vp_team_moves(
          empty,
          tibble::tibble(feature = character(0), team = character(0))
        )) ==
          0 &&
        nrow(vp_team_order(
          empty,
          tibble::tibble(feature = character(0), team = character(0))
        )) ==
          0 &&
        nrow(vp_split_after(empty)) == 0 &&
        nrow(vp_splitting_decisions(empty)) == 0
    )
  }
)
