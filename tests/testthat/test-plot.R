test_that(
  paste0(
    "Drawing: the Graphviz source of vp_dot() (every link once, in the style ",
    "of its graph, atomic sets merged) and the"
  ),
  {
    # ==========================================================================
    # Drawing: the Graphviz source of vp_dot() (every link once, in the style of
    # its graph, atomic sets merged) and the files of vp_plot() (every layout,
    # every format), on every fixture and on cases made by hand.
    # ==========================================================================
    section("drawing: the Graphviz source")

    for (n in pick(names(models))) {
      m <- models[[n]]
      label <- function(what) paste0(n, ": ", what)
      vars <- .vp_nodes(m)
      rep <- .vp_representative(m)
      to_rep <- function(v) unname(rep[v])
      expect <- function(l, directed) {
        # the links with atomic sets merged, by vp_atomic_sets' representative
        if (is.null(l) || nrow(l) == 0) {
          return(character(0))
        }
        f <- to_rep(l$from)
        t <- to_rep(l$to)
        keep <- f != t
        unique(
          if (directed) {
            paste(f[keep], t[keep], sep = "\t")
          } else {
            ukeys(f[keep], t[keep])
          }
        )
      }
      if (length(vars) > 400) {
        next
      }
      d <- parse_dot(vp_dot(m))
      check(
        label("one node per feature, atomic sets merged"),
        setequal(d$nodes, unique(to_rep(vars))) && !anyDuplicated(d$nodes)
      )
      chg <- d$links
      check(
        label("requires: every link once, merged by atomic sets"),
        setequal(
          paste(chg$from, chg$to, sep = "\t")[chg$kind == "requires"],
          expect(m$requires, TRUE)
        ) &&
          !anyDuplicated(chg[chg$kind == "requires", ])
      )
      check(
        label("excludes: every conflict once, as a red line"),
        setequal(
          ukeys(chg$from, chg$to)[chg$kind == "excludes"],
          expect(m$excludes, FALSE)
        ) &&
          sum(chg$kind == "excludes") == length(expect(m$excludes, FALSE))
      )
      check(
        label("at-least-one: every line once, as a green line"),
        setequal(
          ukeys(chg$from, chg$to)[chg$kind == "atleastone"],
          expect(m$atleastone, FALSE)
        )
      )
      a <- vp_atomic_sets(m)
      if (nrow(a)) {
        lab <- grep("label=", d$lines, value = TRUE)
        check(
          label("each atomic set: one box whose label names all its features"),
          length(lab) == length(unique(a$set)) &&
            all(vapply(
              split(a$feature, a$set),
              function(fs) {
                any(vapply(
                  lab,
                  function(x) all(vapply(fs, grepl, TRUE, x = x, fixed = TRUE)),
                  TRUE
                ))
              },
              TRUE
            ))
        )
        dn <- parse_dot(vp_dot(m, merge_atomic = FALSE))
        check(
          label("merge_atomic = FALSE: every feature its own box"),
          setequal(dn$nodes, vars)
        )
      }
      mn <- vp_minimal(m)
      dm <- parse_dot(vp_dot(mn))
      lm <- dm$links
      check(
        label(
          "minimal form: its links, and the same boxes as the complete form"
        ),
        sum(lm$kind == "requires") == nrow(mn$requires) &&
          sum(lm$kind == "excludes") == nrow(mn$excludes) &&
          setequal(dm$nodes, d$nodes) &&
          length(grep("label=", dm$lines)) == length(grep("label=", d$lines))
      )
      only <- parse_dot(vp_dot(m, graphs = "excludes"))$links
      check(
        label("graphs = \"excludes\": conflicts only"),
        all(only$kind == "excludes") &&
          nrow(only) == sum(chg$kind == "excludes")
      )
      t <- vp_feature_tree(m)
      dt <- parse_dot(vp_dot(t))
      check(
        label(
          paste0(
            "feature tree: one edge per feature with a parent, one dashed ",
            "arrow per cross-tree requirement"
          )
        ),
        sum(dt$links$kind == "tree") == sum(!is.na(t$parent)) &&
          sum(dt$links$kind == "cross_tree") ==
            sum(vapply(
              strsplit(t$cross_tree, ",", fixed = TRUE),
              function(x) sum(nzchar(trimws(x))),
              0L
            )) &&
          all(
            paste(dt$links$from, dt$links$to)[dt$links$kind == "tree"] %in%
              paste(t$parent, t$feature)
          )
      )
    }

    m3 <- models$miband3
    up <- vp_upset(m3, "MovementFilter")
    d <- parse_dot(vp_dot(
      m3,
      features = up$feature,
      highlight = "MovementFilter",
      highlight_links = tibble::tibble(from = "MovementFilter", to = "BLEv40")
    ))
    check(
      "features = : only those features, and only the links among them",
      setequal(d$nodes, unique(.vp_representative(m3)[up$feature])) &&
        all(d$links$from %in% d$nodes & d$links$to %in% d$nodes)
    )
    check(
      paste0(
        paste0(
          "highlight: the feature is filled in yellow; highlight_links: the ",
          "link "
        ),
        "is thick, and only it"
      ),
      any(grepl('^  "MovementFilter" \\[fillcolor="#FFE9B8"', d$lines)) &&
        identical(
          d$links$thick,
          d$links$from == "MovementFilter" &
            d$links$to == "BLEv40" &
            d$links$kind == "requires"
        )
    )
    check(
      "highlight of a member of an atomic set: its box is highlighted",
      any(grepl(
        '^  "Screen" \\[label=.*fillcolor="#FFE9B8"',
        parse_dot(vp_dot(m3, highlight = "OLED"))$lines
      ))
    )
    fl <- parse_dot(vp_dot(
      m3,
      fill = c(NFC = "#AAAAAA", BT40 = "#BBBBBB")
    ))$lines
    check(
      "fill: one colour per feature",
      any(grepl('"NFC" \\[fillcolor="#AAAAAA"\\]', fl)) &&
        any(grepl('"BT40" \\[fillcolor="#BBBBBB"\\]', fl))
    )
    sk <- vp_skeleton(m3)
    ds <- parse_dot(vp_dot(sk))
    check(
      "a tibble of links without graph: all requirements",
      all(ds$links$kind == "requires") &&
        nrow(ds$links) == nrow(unique(sk[c("from", "to")]))
    )
    mix <- dplyr::bind_rows(
      dplyr::mutate(sk, graph = "requires"),
      dplyr::mutate(vp_primitive_conflicts(m3), graph = "excludes")
    )
    dx <- parse_dot(vp_dot(mix))
    check(
      "a tibble of links with graph: each link in the style of its graph",
      sum(dx$links$kind == "requires") == nrow(sk) &&
        sum(dx$links$kind == "excludes") == nrow(vp_primitive_conflicts(m3))
    )
    kl <- vp_kernel_links(m3)
    dk <- parse_dot(vp_dot(kl))
    check(
      "kernel links (column link): each in the style of its graph",
      sum(dk$links$kind == "requires") == sum(kl$link == "requires") &&
        sum(dk$links$kind == "excludes") ==
          length(unique(ukeys(kl$from, kl$to)[kl$link == "excludes"]))
    )
    ut <- vp_read_uvl_tree(fixtures$miband3$uvl)
    du <- parse_dot(vp_dot(ut))
    check(
      paste0(
        "the declared UVL tree: every feature, one edge per child, abstract ",
        "features dashed"
      ),
      setequal(du$nodes, ut$feature) &&
        sum(du$links$kind == "tree") == sum(!is.na(ut$parent)) &&
        all(vapply(
          ut$feature[ut$abstract],
          function(f) any(grepl(paste0('^  "', f, '" \\[.*dashed'), du$lines)),
          TRUE
        ))
    )
    dg <- vp_mig(m3) |>
      dplyr::mutate(
        from = paste0(ifelse(from_selected, "", "not "), from),
        to = paste0(ifelse(to_selected, "", "not "), to)
      )
    dm <- parse_dot(vp_dot(vp_mig(m3)))
    check(
      paste0(
        "a MIG is drawn directly: nodes 'A' and 'not A', one arrow per ",
        "implication, every arrow directed"
      ),
      setequal(dm$nodes, unique(c(dg$from, dg$to))) &&
        nrow(dm$links) == nrow(unique(dg[c("from", "to")])) &&
        !any(grepl("dir=none", grep(" -> ", dm$lines, value = TRUE)))
    )
    check(
      paste0(
        "a MIG: 'not A' nodes white; graphs = selects the implications by ",
        "their link"
      ),
      all(grepl(
        'fillcolor="white"',
        grep('^  "not [^"]*" \\[', dm$lines, value = TRUE)
      )) &&
        nrow(parse_dot(vp_dot(vp_mig(m3), graphs = "excludes"))$links) ==
          sum(dg$because == "excludes")
    )
    check(
      paste0(
        "the MIG with its nodes named by hand (only from and to): drawn as ",
        "requirements"
      ),
      nrow(parse_dot(vp_dot(dplyr::select(dg, from, to)))$links) ==
        nrow(unique(dg[c("from", "to")]))
    )
    check(
      paste0(
        "conflicts do not move the layers when there are requirements ",
        "(constraint=false), and do when alone"
      ),
      all(grepl("constraint=false", grep("#B3261E", dx$lines, value = TRUE))) &&
        all(grepl(
          "constraint=true",
          grep(
            "#B3261E",
            vp_dot(m3, graphs = "excludes") |> strsplit("\n") |> unlist(),
            value = TRUE
          )
        ))
    )
    check(
      "rankdir: BT for graphs, TB for trees, or as given",
      grepl("rankdir=BT", vp_dot(m3)) &&
        grepl("rankdir=TB", vp_dot(vp_feature_tree(m3))) &&
        grepl("rankdir=LR", vp_dot(m3, rankdir = "LR"))
    )
    odd <- model_from_links(
      c('say "hi"', "back\\slash", "plain"),
      data.frame(
        from = c('say "hi"', "plain"),
        to = c("back\\slash", 'say "hi"')
      ),
      name = "odd"
    )
    dq <- parse_dot(vp_dot(odd))
    check(
      "names with quotes and backslashes are escaped",
      length(dq$nodes) == 3 && nrow(dq$links) == 2
    )
    check(
      "a model without links: its features, no links",
      nrow(
        parse_dot(vp_dot(model_from_links(c("a", "b"), name = "nolinks")))$links
      ) ==
        0
    )
    check(
      "an empty model: a drawing with nothing in it",
      length(parse_dot(vp_dot(models$miband1))$nodes) == 0
    )
    check(
      "a tibble of links with no row: an empty drawing",
      length(parse_dot(vp_dot(sk[0, ]))$nodes) == 0
    )

    section("drawing: errors")
    check(
      "unknown feature in features =",
      fails_with(vp_dot(m3, features = "Nope"), "Not in what is drawn: Nope")
    )
    check(
      "unknown feature in highlight",
      fails_with(vp_dot(m3, highlight = "Nope"), "Not in what is drawn")
    )
    check(
      "unknown feature in fill",
      fails_with(vp_dot(m3, fill = c(Nope = "red")), "Not in what is drawn")
    )
    check(
      "unknown layout",
      fails_with(vp_dot(m3, layout = "nope"), "should be one of")
    )
    check(
      "unknown rankdir",
      fails_with(vp_dot(m3, rankdir = "UP"), "rankdir must be")
    )
    check(
      "unknown graph",
      fails_with(vp_dot(m3, graphs = "nope"), "should be one of")
    )
    check(
      "a tibble without from and to",
      fails_with(vp_dot(tibble::tibble(a = 1)), "from and to")
    )
    check(
      "a tibble with an unknown graph",
      fails_with(
        vp_dot(tibble::tibble(from = "a", to = "b", graph = "x")),
        "requires, excludes or atleastone"
      )
    )
    check(
      "something that cannot be drawn",
      fails_with(vp_dot(42), "draws a model")
    )
    check(
      "too many nodes",
      fails_with(vp_dot(m3, max_nodes = 3), "too many to draw")
    )
    check(
      "a file that is not .pdf, .svg or .png",
      fails_with(vp_plot(m3, file.path(work, "x.jpg")), "must end in")
    )

    section("drawing: the files")
    vp_plot_gv <- function(...) vp_plot(..., engine = "graphviz")
    if (!nzchar(Sys.which("dot"))) {
      skip_note("drawing files", "Graphviz is not installed")
    } else {
      out <- file.path(work, "plots")
      magic <- function(f, n) readBin(f, "raw", n)
      for (l in c("dot", "neato", "fdp", "sfdp", "circo", "twopi")) {
        f <- vp_plot_gv(
          vp_minimal(m3),
          file.path(out, paste0("band_", l, ".pdf")),
          layout = l,
          highlight = "BLEv40"
        )
        check(
          paste("layout", l, ": a PDF file"),
          file.exists(f) &&
            identical(rawToChar(magic(f, 5)), "%PDF-") &&
            file.size(f) > 1000
        )
      }
      f <- vp_plot_gv(m3, file.path(out, "band.svg"))
      check(
        "format SVG",
        grepl("<svg", paste(readLines(f, warn = FALSE), collapse = ""))
      )
      f <- vp_plot_gv(m3, file.path(out, "band.png"))
      check("format PNG", identical(magic(f, 4)[2:4], charToRaw("PNG")))
      f <- vp_plot_gv(vp_feature_tree(m3), file.path(out, "deeper", "tree.pdf"))
      check("a tree, into a folder that did not exist", file.exists(f))
      f <- vp_plot_gv(m3)
      check(
        "no file given: a temporary PDF",
        file.exists(f) && grepl("\\.pdf$", f)
      )
      check(
        "the returned path is invisible",
        !withVisible(vp_plot_gv(m3, file.path(out, "v.pdf")))$visible
      )
      for (n in pick(names(models))) {
        if (length(.vp_nodes(models[[n]])) > 400) {
          next
        }
        ok <- tryCatch(
          {
            vp_plot_gv(
              vp_minimal(models[[n]]),
              file.path(out, paste0(n, ".pdf"))
            )
            TRUE
          },
          error = function(e) conditionMessage(e)
        )
        check(
          paste0(n, ": its minimal form is drawn"),
          isTRUE(ok),
          if (!isTRUE(ok)) ok
        )
      }
      check(
        "an odd name is drawn",
        file.exists(vp_plot_gv(odd, file.path(out, "odd.pdf")))
      )
      # Graphviz off the PATH, in a folder with spaces in its name (as
      # C:/Program Files (x86)/Graphviz/bin on Windows)
      gv <- file.path(work, "Program Files (x86)", "Graphviz", "bin")
      dir.create(gv, recursive = TRUE)
      for (p in c("dot", "neato")) {
        file.symlink(Sys.which(p), file.path(gv, p))
      }
      op <- Sys.getenv("PATH")
      Sys.setenv(PATH = "")
      options(variplex.graphviz = gv)
      ok_option <- tryCatch(
        file.exists(vp_plot_gv(
          m3,
          file.path(out, "spaces.pdf"),
          layout = "neato"
        )),
        error = function(e) conditionMessage(e)
      )
      # the path of the program itself also works
      options(variplex.graphviz = file.path(gv, "dot"))
      ok_program <- tryCatch(
        file.exists(vp_plot_gv(m3, file.path(out, "spaces2.pdf"))),
        error = function(e) conditionMessage(e)
      )
      options(variplex.graphviz = NULL)
      Sys.setenv(GRAPHVIZ = gv)
      ok_env <- tryCatch(
        file.exists(vp_plot_gv(m3, file.path(out, "spaces3.pdf"))),
        error = function(e) conditionMessage(e)
      )
      Sys.setenv(GRAPHVIZ = file.path(work, "nowhere"))
      wrong <- fails_with(
        vp_plot_gv(m3, file.path(out, "none.pdf")),
        "is not in"
      )
      Sys.unsetenv("GRAPHVIZ")
      Sys.setenv(PATH = op)
      check(
        paste0(
          "Graphviz off the PATH, in a folder with spaces, given by ",
          "options(variplex.graphviz = folder)"
        ),
        isTRUE(ok_option),
        ok_option
      )
      check(
        "... or by the path of the program itself",
        isTRUE(ok_program),
        ok_program
      )
      check("... or by the variable GRAPHVIZ", isTRUE(ok_env), ok_env)
      check("a folder given that has no Graphviz: a clear error", wrong)
      check(
        "Graphviz off the PATH but in a usual folder (here /usr/bin): found",
        local({
          Sys.setenv(PATH = "")
          on.exit(Sys.setenv(PATH = op))
          nzchar(.vp_graphviz("dot"))
        })
      )
    }
  }
)
