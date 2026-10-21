# ==============================================================================
# Drawing the graphs, in the style of the vignettes: requirements as blue
# arrows, conflicts as dashed red lines, at-least-one lines as dotted green
# lines.
#
# vp_dot() writes the drawing in the DOT language of Graphviz, with no
# dependency. vp_plot() renders it with the R package DiagrammeR (which carries
# its own copy of Graphviz, so nothing has to be installed outside R) and, to
# save it as SVG, PDF or PNG, with DiagrammeRsvg and rsvg. Those who have
# Graphviz installed can render with it instead (engine = "graphviz").
# ==============================================================================

.vp_style <- list(
  ink = "#1F2A44",
  blue = "#0B3D91",
  red = "#B3261E",
  green = "#1B7F3B",
  pale = "#F2F5FA",
  highlight = "#FFE9B8"
)
.vp_layouts <- c("dot", "neato", "fdp", "sfdp", "circo", "twopi")

# The font of the drawings: options(variplex.font = "...") changes it.
.vp_font <- function() getOption("variplex.font", "Helvetica")

# A name between quotes, for DOT (quotes and backslashes escaped; a new line
# written \n).
.vp_dot_q <- function(s) {
  paste0(
    '"',
    gsub(
      "\n",
      "\\n",
      gsub('"', '\\\\"', gsub("\\\\", "\\\\\\\\", s)),
      fixed = TRUE
    ),
    '"'
  )
}

# The first lines of a drawing.
.vp_dot_head <- function(rankdir) {
  st <- .vp_style
  font <- .vp_font()
  c(
    "digraph strong_graphs {",
    sprintf(
      paste0(
        '  graph [fontname="%s", fontsize=10, bgcolor="transparent", ',
        'rankdir=%s, nodesep=0.2, ranksep=0.45, overlap=false, sep="+2", ',
        "splines=true];"
      ),
      font,
      rankdir
    ),
    sprintf(
      paste0(
        '  node [fontname="%s", fontsize=10, shape=box, ',
        'style="rounded,filled", fillcolor="%s", color="%s", fontcolor="%s", ',
        'height=0.3, margin="0.06,0.04"];'
      ),
      font,
      st$pale,
      st$ink,
      st$ink
    ),
    sprintf('  edge [color="%s", arrowsize=0.75];', st$ink)
  )
}

# Where a program of Graphviz is: in the folder of options(variplex.graphviz =
# ...) or of the variable GRAPHVIZ, if given; else on the PATH; else in the
# folders where the installers of Graphviz put it (Windows does not add them to
# the PATH by itself).
.vp_graphviz <- function(layout) {
  exe <- if (.Platform$OS.type == "windows") paste0(layout, ".exe") else layout
  given <- c(getOption("variplex.graphviz", ""), Sys.getenv("GRAPHVIZ", ""))
  given <- given[nzchar(given)]
  for (d in given) {
    # a folder, or the path of one of its programs
    f <- if (dir.exists(d)) file.path(d, exe) else file.path(dirname(d), exe)
    # not normalizePath(): Graphviz reads its layout from the name it is run by,
    if (file.exists(f)) return(f)
  } # and resolving a symlink (Homebrew, Debian) would change that name
  if (length(given)) {
    stop(
      "Graphviz's program ",
      exe,
      " is not in ",
      given[1],
      ": give the folder that holds dot (its bin folder)."
    )
  }
  on_path <- Sys.which(layout)
  if (nzchar(on_path)) {
    return(unname(on_path))
  }
  usual <- c(
    file.path(
      c(
        Sys.getenv("ProgramFiles"),
        Sys.getenv("ProgramFiles(x86)"),
        "C:/Program Files",
        "C:/Program Files (x86)"
      ),
      "Graphviz",
      "bin"
    ),
    file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Graphviz", "bin"),
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/opt/local/bin",
    "/usr/bin",
    "/snap/bin"
  ) # Homebrew (Apple silicon, Intel), MacPorts, Linux
  for (d in unique(usual[nzchar(usual)])) {
    f <- file.path(d, exe)
    if (file.exists(f)) return(f)
  }
  stop(
    paste0(
      "Graphviz was not found: install it (https://graphviz.org), or tell R ",
      "where it is, for example\n"
    ),
    '  options(variplex.graphviz = "C:/Program Files/Graphviz/bin")',
    call. = FALSE
  )
}

# Renders a DOT text. engine "diagrammer": with file = NULL, an htmlwidget
# (shown in the viewer, or in a document made with R Markdown); with a file, the
# drawing saved as SVG, PDF or PNG. engine "graphviz": the programs of Graphviz
# write the file.
.vp_render <- function(dot, file, layout, engine, width = NULL, height = NULL) {
  if (!is.null(file)) {
    format <- tolower(tools::file_ext(file))
    if (!format %in% c("pdf", "svg", "png")) {
      stop("The file must end in .pdf, .svg or .png: ", file, call. = FALSE)
    }
    dir.create(dirname(file), showWarnings = FALSE, recursive = TRUE)
  }
  if (engine == "graphviz") {
    if (is.null(file)) {
      file <- tempfile("vp_plot", fileext = ".pdf")
      format <- "pdf"
    }
    program <- .vp_graphviz(layout)
    src <- tempfile("vp_plot", fileext = ".dot")
    on.exit(unlink(src))
    writeLines(dot, src, useBytes = TRUE)
    err <- suppressWarnings(system2(
      program,
      c(paste0("-T", format), shQuote(src), "-o", shQuote(file)),
      stdout = TRUE,
      stderr = TRUE
    ))
    status <- attr(err, "status")
    if (!is.null(status) && status != 0 || !file.exists(file)) {
      stop("Graphviz failed: ", paste(err, collapse = "\n"), call. = FALSE)
    }
    return(invisible(file))
  }
  .vp_need(
    "DiagrammeR",
    paste0(
      "to draw the graphs (or use engine = \"graphviz\", or write the source ",
      "with vp_dot())"
    )
  )
  if (layout == "sfdp") {
    layout <- "fdp"
  } # the Graphviz of DiagrammeR has no sfdp
  # the layout also as an attribute of the graph: the export to SVG does not
  # pass the engine on
  dot <- sub(
    "\n",
    sprintf("\n  graph [layout=%s];\n", layout),
    dot,
    fixed = TRUE
  )
  widget <- DiagrammeR::grViz(
    dot,
    engine = layout,
    width = width,
    height = height
  )
  if (is.null(file)) {
    return(widget)
  }
  .vp_need("DiagrammeRsvg", "to save a drawing to a file")
  svg <- DiagrammeRsvg::export_svg(widget)
  if (format == "svg") {
    writeLines(svg, file, useBytes = TRUE)
  } else {
    .vp_need("rsvg", "to save a drawing as PDF or PNG")
    if (format == "pdf") {
      rsvg::rsvg_pdf(charToRaw(svg), file)
    } else {
      rsvg::rsvg_png(charToRaw(svg), file)
    }
  }
  invisible(file)
}

# Stops with a clear message when a suggested package is not installed.
.vp_need <- function(pkg, why) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      "The package ",
      pkg,
      " is needed ",
      why,
      ": install.packages(\"",
      pkg,
      "\")",
      call. = FALSE
    )
  }
}

#' The Graphviz (DOT) source of a drawing
#'
#' The source of a drawing in the DOT language of Graphviz. [vp_plot()] renders
#' it; use it directly to edit the source by hand, or to render it with any
#' Graphviz tool. It needs no other package.
#'
#' @param x What to draw: a model (from vp_read(), complete or minimal: the
#'   drawing shows the links it has, so a minimal form, vp_minimal(model), is
#'   much easier to read); or a tibble of links with `from` and `to` (the answer
#'   of vp_skeleton(), vp_primitive_conflicts(), vp_kernel_links(),
#'   vp_changed_links()...), with an optional column `graph` ("requires",
#'   "excludes" or "atleastone", or a column `link` as in vp_kernel_links();
#'   without either, every link is a requirement); or a feature tree, from
#'   vp_feature_tree() or vp_read_uvl_tree() (whose abstract features get a
#'   dashed border); or a modal implication graph, from vp_mig(): its nodes are
#'   decisions, "A" and "not A" (white), and every arrow is an implication, in
#'   the colour and line of the link it comes from (`graphs` selects which;
#'   `features` and `highlight` take decisions).
#' @param graphs Which graphs of a model to draw.
#' @param features Draw only these features and the links among them (NULL:
#'   all).
#' @param highlight Features to fill in yellow.
#' @param highlight_links A tibble with `from` and `to`: links to draw thick.
#' @param fill A named vector: feature -> fill colour (for example, one colour
#'   per community).
#' @param merge_atomic Draw each atomic set of a model as one box, with the
#'   names of its features one under the other.
#' @param rankdir For the layout dot: "BT" puts the features that are required
#'   at the top, "TB" at the bottom, "LR" and "RL" left to right and right to
#'   left. NULL: "BT" for graphs, "TB" for a tree (parents at the top).
#' @param layout The Graphviz program that places the nodes: "dot" (layers: best
#'   for requirements), "neato" and "fdp" (springs: best for conflicts), "sfdp"
#'   (springs, for large graphs), "circo" (a circle), "twopi" (rings around a
#'   centre).
#' @param max_nodes Refuse to draw more nodes than this (the layout gets slow,
#'   and the drawing unreadable): draw a part instead.
#' @return A character string: the DOT source.
#' @family drawing
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' cat(vp_dot(vp_minimal(band)))
#' cat(vp_dot(vp_skeleton(band), highlight = "Screen"))
vp_dot <- function(
  x,
  graphs = c("requires", "excludes", "atleastone"),
  features = NULL,
  highlight = character(0),
  highlight_links = NULL,
  fill = NULL,
  merge_atomic = TRUE,
  rankdir = NULL,
  layout = "dot",
  max_nodes = 400
) {
  layout <- match.arg(layout, .vp_layouts)
  is_tree <- is.data.frame(x) && all(c("feature", "parent") %in% names(x))
  if (is.null(rankdir)) {
    rankdir <- if (is_tree) "TB" else "BT"
  }
  if (!rankdir %in% c("BT", "TB", "LR", "RL")) {
    stop("rankdir must be BT, TB, LR or RL.")
  }
  graphs <- match.arg(
    graphs,
    c("requires", "excludes", "atleastone"),
    several.ok = TRUE
  )
  st <- .vp_style
  q <- .vp_dot_q
  empty <- tibble::tibble(
    from = character(0),
    to = character(0),
    graph = character(0)
  )
  tree_edges <- empty
  label <- NULL
  abstract <- character(0)
  is_mig <- FALSE

  # --- what to draw: nodes, links (from, to, graph), labels
  if (is_tree) {
    # a feature tree
    nodes <- unique(c(x$feature, stats::na.omit(x$parent)))
    tree_edges <- tibble::tibble(
      from = x$feature,
      to = x$parent,
      graph = "tree"
    )[!is.na(x$parent), ]
    ct <- if ("cross_tree" %in% names(x)) x$cross_tree else rep("", nrow(x))
    cross <- lapply(seq_len(nrow(x)), function(k) {
      t <- trimws(strsplit(ct[k], ",", fixed = TRUE)[[1]])
      t <- t[nzchar(t)]
      if (length(t)) {
        tibble::tibble(from = x$feature[k], to = t, graph = "requires")
      } else {
        NULL
      }
    })
    links <- dplyr::bind_rows(empty, cross)
    nodes <- unique(c(nodes, links$to))
    abstract <- if ("abstract" %in% names(x)) {
      x$feature[x$abstract %in% TRUE]
    } else {
      character(0)
    } # a tree read by vp_read_uvl_tree()
  } else if (
    is.data.frame(x) &&
      all(c("from", "from_selected", "to", "to_selected") %in% names(x))
  ) {
    # a MIG, from vp_mig()
    is_mig <- TRUE
    lit <- function(f, v) paste0(ifelse(v, "", "not "), f)
    why <- if ("because" %in% names(x)) {
      as.character(x$because)
    } else {
      rep("requires", nrow(x))
    }
    links <- tibble::tibble(
      from = lit(x$from, x$from_selected),
      to = lit(x$to, x$to_selected),
      graph = why
    )
    links <- links[links$graph %in% graphs, ]
    nodes <- unique(c(links$from, links$to))
  } else if (is.data.frame(x)) {
    # a tibble of links
    if (!all(c("from", "to") %in% names(x))) {
      stop(
        paste0(
          "A tibble to draw needs the columns from and to (or feature and ",
          "parent, for a tree)."
        )
      )
    }
    g <- if ("graph" %in% names(x)) {
      as.character(x$graph)
    } else if ("link" %in% names(x)) {
      # a link column, as in the answer of vp_kernel_links()
      as.character(x$link)
    } else {
      rep("requires", nrow(x))
    }
    if (!all(g %in% c("requires", "excludes", "atleastone"))) {
      stop("The column graph can only be requires, excludes or atleastone.")
    }
    links <- tibble::tibble(
      from = as.character(x$from),
      to = as.character(x$to),
      graph = g
    )
    links <- links[links$graph %in% graphs, ]
    nodes <- unique(c(links$from, links$to))
  } else if (is.list(x) && !is.null(x$requires)) {
    # a model
    nodes <- .vp_nodes(x)
    pick <- function(g) {
      if (g %in% graphs && !is.null(x[[g]]) && nrow(x[[g]]) > 0) {
        tibble::tibble(from = x[[g]]$from, to = x[[g]]$to, graph = g)
      } else {
        NULL
      }
    }
    links <- dplyr::bind_rows(
      empty,
      pick("requires"),
      pick("excludes"),
      pick("atleastone")
    )
    if (merge_atomic) {
      rep <- .vp_representative(x)
      if (!is.null(x$sets) && nrow(x$sets) > 0) {
        # a minimal form keeps one feature per atomic set; the sets say the rest
        rep <- c(
          rep[!names(rep) %in% x$sets$feature],
          stats::setNames(x$sets$representative, x$sets$feature)
        )
      }
      if (length(rep) && any(rep != names(rep))) {
        members <- split(names(rep), unname(rep))
        members <- members[lengths(members) > 1]
        label <- vapply(
          members,
          function(m) {
            paste(
              c(m[m %in% names(members)], .vp_sort(setdiff(m, names(members)))),
              collapse = "\n"
            )
          },
          ""
        )
        to_rep <- function(v) ifelse(v %in% names(rep), unname(rep[v]), v)
        if (length(highlight)) {
          highlight <- unique(to_rep(highlight))
        }
        if (!is.null(fill)) {
          names(fill) <- to_rep(names(fill))
        }
        if (!is.null(highlight_links)) {
          highlight_links <- tibble::tibble(
            from = to_rep(highlight_links$from),
            to = to_rep(highlight_links$to)
          )
        }
        if (!is.null(features)) {
          features <- unique(to_rep(features))
        }
        links$from <- to_rep(links$from)
        links$to <- to_rep(links$to)
        links <- links[links$from != links$to, ]
        nodes <- unique(to_rep(nodes))
      }
    }
  } else {
    stop(
      paste0(
        "vp_dot() draws a model, a tibble of links (from, to) or a feature ",
        "tree (feature, parent)."
      )
    )
  }

  if (!is.null(features)) {
    unknown <- setdiff(features, nodes)
    if (length(unknown)) {
      stop("Not in what is drawn: ", paste(unknown, collapse = ", "))
    }
    nodes <- nodes[nodes %in% features]
    links <- links[links$from %in% features & links$to %in% features, ]
    tree_edges <- tree_edges[
      tree_edges$from %in% features & tree_edges$to %in% features,
    ]
  }
  unknown <- setdiff(c(highlight, names(fill)), nodes)
  if (length(unknown)) {
    stop("Not in what is drawn: ", paste(unknown, collapse = ", "))
  }
  if (length(nodes) > max_nodes) {
    stop(
      length(nodes),
      " nodes are too many to draw (max_nodes = ",
      max_nodes,
      "): draw a part, with features = or vp_subset(), ",
      "or raise max_nodes (and use layout = \"sfdp\")."
    )
  }
  # an undirected link once
  # in a MIG every link is an implication, with a direction
  und <- links$graph != "requires" & !is_mig
  a <- pmin(links$from, links$to)
  b <- pmax(links$from, links$to)
  links$from[und] <- a[und]
  links$to[und] <- b[und]
  links <- unique(links)
  hl <- if (is.null(highlight_links) || nrow(highlight_links) == 0) {
    character(0)
  } else {
    paste(highlight_links$from, highlight_links$to, sep = "\t")
  }

  # --- the DOT text
  has_req <- any(links$graph %in% c("requires")) || nrow(tree_edges) > 0
  out <- .vp_dot_head(rankdir)
  for (v in nodes) {
    attrs <- character(0)
    if (!is.null(label) && v %in% names(label)) {
      attrs <- c(attrs, paste0("label=", q(label[[v]])))
    }
    if (!is.null(fill) && v %in% names(fill)) {
      attrs <- c(attrs, sprintf('fillcolor="%s"', fill[[v]]))
    }
    if (v %in% highlight) {
      attrs <- c(attrs, sprintf('fillcolor="%s", penwidth=1.8', st$highlight))
    }
    if (v %in% abstract) {
      attrs <- c(attrs, 'style="rounded,filled,dashed"')
    }
    if (
      is_mig &&
        startsWith(v, "not ") &&
        !(v %in% highlight) &&
        !(v %in% names(fill))
    ) {
      attrs <- c(attrs, 'fillcolor="white"')
    }
    out <- c(
      out,
      paste0(
        "  ",
        q(v),
        if (length(attrs)) paste0(" [", paste(attrs, collapse = ", "), "]"),
        ";"
      )
    )
  }
  for (k in seq_len(nrow(tree_edges))) {
    # a child below its parent: the edge runs from the parent
    out <- c(
      out,
      sprintf(
        '  %s -> %s [arrowhead=none, color="%s", penwidth=1.4];',
        q(tree_edges$to[k]),
        q(tree_edges$from[k]),
        st$ink
      )
    )
  }
  for (k in seq_len(nrow(links))) {
    f <- q(links$from[k])
    t <- q(links$to[k])
    thick <- paste(links$from[k], links$to[k], sep = "\t") %in%
      hl ||
      (links$graph[k] != "requires" &&
        paste(links$to[k], links$from[k], sep = "\t") %in% hl)
    w <- if (thick) ", penwidth=2.6" else ""
    if (is_mig) {
      # an implication: an arrow in the colour of its link
      out <- c(
        out,
        sprintf(
          '  %s -> %s [color="%s", style=%s%s];',
          f,
          t,
          c(
            requires = st$blue,
            excludes = st$red,
            atleastone = st$green
          )[[links$graph[k]]],
          c(
            requires = "solid",
            excludes = "dashed",
            atleastone = "dotted"
          )[[links$graph[k]]],
          w
        )
      )
      next
    }
    out <- c(
      out,
      switch(
        links$graph[k],
        requires = if (nrow(tree_edges) > 0) {
          sprintf(
            '  %s -> %s [color="%s", style=dashed, constraint=false%s];',
            f,
            t,
            st$blue,
            w
          )
        } else {
          sprintf('  %s -> %s [color="%s"%s];', f, t, st$blue, w)
        },
        excludes = sprintf(
          '  %s -> %s [dir=none, style=dashed, color="%s", constraint=%s%s];',
          f,
          t,
          st$red,
          tolower(!has_req),
          w
        ),
        atleastone = sprintf(
          paste0(
            '  %s -> %s [dir=none, style=dotted, penwidth=%s, color="%s", ',
            "constraint=%s];"
          ),
          f,
          t,
          if (thick) "2.6" else "1.8",
          st$green,
          tolower(!has_req && !any(links$graph == "excludes"))
        )
      )
    )
  }
  paste(c(out, "}"), collapse = "\n")
}

#' Draw a model, some links or a feature tree
#'
#' Draws what [vp_dot()] describes: requirements as blue arrows (from the
#' feature that requires to the one required), conflicts as dashed red lines and
#' at-least-one lines as dotted green lines. A minimal form ([vp_minimal()]) is
#' much easier to read than the complete graphs, which have an arrow for every
#' consequence.
#'
#' By default the drawing is made by the package DiagrammeR, which includes its
#' own copy of Graphviz: nothing needs to be installed outside R. Without `file`
#' the result is an htmlwidget, which RStudio shows in its viewer and R Markdown
#' puts in the document. With `file` the drawing is saved; SVG needs the package
#' DiagrammeRsvg, and PDF or PNG also need rsvg. With `engine = "graphviz"` the
#' drawing is made by the programs of Graphviz, if it is installed (they are
#' looked for in `getOption("variplex.graphviz")`, the variable `GRAPHVIZ`, the
#' `PATH` and the usual folders), and always saved to a file.
#'
#' @param x What to draw; see [vp_dot()].
#' @param file Where to save the drawing: a file ending in `.svg`, `.pdf` or
#'   `.png`. `NULL`: no file (with `engine = "graphviz"`, a temporary PDF file).
#' @param layout How the nodes are placed: `"dot"` (layers: best for
#'   requirements), `"neato"` and `"fdp"` (springs: best for conflicts),
#'   `"sfdp"` (springs, for large graphs; drawn as `"fdp"` by DiagrammeR),
#'   `"circo"` (a circle) or `"twopi"` (rings around a centre).
#' @param engine `"diagrammer"` (the R packages DiagrammeR, DiagrammeRsvg and
#'   rsvg) or `"graphviz"` (the programs of Graphviz).
#' @param width,height The size of the htmlwidget (any CSS size, or a number of
#'   pixels); `NULL` lets it fill the space.
#' @param ... More arguments of [vp_dot()], such as `graphs`, `features`,
#'   `highlight`, `fill` or `rankdir`.
#' @return Without `file` and with DiagrammeR, an htmlwidget. With `file`, the
#'   path of the file, invisibly.
#' @seealso [vp_dot()] for the source of the drawing and the meaning of its
#'   arguments.
#' @family drawing
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' if (requireNamespace("DiagrammeR", quietly = TRUE)) {
#'   vp_plot(vp_minimal(band))
#'   vp_plot(vp_minimal(band), graphs = "excludes", layout = "neato")
#'   vp_plot(vp_feature_tree(band))
#' }
#' \donttest{
#' if (requireNamespace("DiagrammeRsvg", quietly = TRUE)) {
#'   file <- vp_plot(vp_minimal(band), file = tempfile(fileext = ".svg"))
#'   file.exists(file)
#' }
#' }
vp_plot <- function(
  x,
  file = NULL,
  layout = c("dot", "neato", "fdp", "sfdp", "circo", "twopi"),
  engine = c("diagrammer", "graphviz"),
  width = NULL,
  height = NULL,
  ...
) {
  layout <- match.arg(layout)
  engine <- match.arg(engine)
  .vp_render(
    vp_dot(x, layout = layout, ...),
    file,
    layout,
    engine,
    width,
    height
  )
}

#' Draw what changed between two versions
#'
#' Draws what changed between two versions in one graph: links kept (grey),
#' gained (thick, in the colour of their graph) and lost (dashed orange);
#' features added (yellow) and removed (white, dashed border). By default only
#' the features touched by a change are drawn, and the minimal forms are
#' compared, so that the drawing shows what was written (an atomic set is drawn
#' as requirements both ways between its features, so that a feature joining or
#' leaving a set shows). The drawing is made as in [vp_plot()].
#'
#' @inheritParams vp_plot
#' @inheritParams vp_dot_compare
#' @return Without `file` and with DiagrammeR, an htmlwidget. With `file`, the
#'   path of the file, invisibly.
#' @family drawing
#' @export
#' @examples
#' old <- vp_generate(vp_example("miband3_planned.uvl"))
#' new <- vp_generate(vp_example("miband3_realized.uvl"))
#' if (requireNamespace("DiagrammeR", quietly = TRUE)) {
#'   vp_plot_compare(old, new)
#' }
vp_plot_compare <- function(
  old,
  new,
  file = NULL,
  graph = c("requires", "excludes", "atleastone"),
  minimal = TRUE,
  context = TRUE,
  layout = c("dot", "neato", "fdp", "sfdp", "circo", "twopi"),
  engine = c("diagrammer", "graphviz"),
  rankdir = "BT",
  max_nodes = 400,
  width = NULL,
  height = NULL
) {
  layout <- match.arg(layout)
  engine <- match.arg(engine)
  .vp_render(
    vp_dot_compare(
      old,
      new,
      graph = graph,
      minimal = minimal,
      context = context,
      rankdir = rankdir,
      max_nodes = max_nodes
    ),
    file,
    layout,
    engine,
    width,
    height
  )
}

#' The Graphviz (DOT) source of a drawing of what changed
#'
#' The source, in the DOT language of Graphviz, of the drawing of
#' [vp_plot_compare()].
#'
#' @param old The older version of a model (from [vp_generate()] or
#'   [vp_read()]).
#' @param new The newer version of the same model.
#' @param graph The graph to compare: `"requires"`, `"excludes"` or
#'   `"atleastone"`.
#' @param minimal Compare the minimal forms (`TRUE`) or the complete graphs
#'   (`FALSE`: every consequence, often a tangle).
#' @param context `TRUE`: only the features with a gained or lost link, and
#'   those added or removed; `FALSE`: all.
#' @param rankdir The direction of the layers: `"BT"` puts the features that are
#'   required at the top, `"TB"` at the bottom, `"LR"` and `"RL"` left to right
#'   and right to left.
#' @param max_nodes Refuse to draw more nodes than this: compare a part instead,
#'   with [vp_subset()] on both versions.
#' @return A character string: the DOT source.
#' @family drawing
#' @export
#' @examples
#' old <- vp_generate(vp_example("miband3_planned.uvl"))
#' new <- vp_generate(vp_example("miband3_realized.uvl"))
#' cat(vp_dot_compare(old, new))
vp_dot_compare <- function(
  old,
  new,
  graph = c("requires", "excludes", "atleastone"),
  minimal = TRUE,
  context = TRUE,
  rankdir = "BT",
  max_nodes = 400
) {
  graph <- match.arg(graph)
  if (!rankdir %in% c("BT", "TB", "LR", "RL")) {
    stop("rankdir must be BT, TB, LR or RL.")
  }
  if (is.null(old[[graph]]) || is.null(new[[graph]])) {
    stop("One of the versions has no ", graph, " graph.")
  }
  # every feature that can vary is a box, in both forms: a minimal form keeps
  # one feature per atomic set, so its sets are spelled out as requirements both
  # ways (a feature leaving a set then shows as lost arrows, not as a new
  # feature)
  links_of <- function(m) {
    l <- if (minimal) vp_minimal(m)[[graph]] else .vp_complete(m)[[graph]]
    l <- tibble::tibble(from = l$from, to = l$to)
    if (minimal && graph == "requires") {
      sets <- vp_minimal(m)$sets
      if (!is.null(sets) && nrow(sets) > 0) {
        o <- sets[sets$feature != sets$representative, ]
        l <- dplyr::bind_rows(
          l,
          tibble::tibble(from = o$feature, to = o$representative),
          tibble::tibble(from = o$representative, to = o$feature)
        )
      }
    }
    l
  }
  va <- .vp_nodes(.vp_complete(old))
  vb <- .vp_nodes(.vp_complete(new))
  added <- setdiff(vb, va)
  removed <- setdiff(va, vb)
  key <- function(l) {
    if (graph == "requires") {
      paste(l$from, l$to, sep = "\t")
    } else {
      paste(pmin(l$from, l$to), pmax(l$from, l$to), sep = "\t")
    }
  }
  ka <- unique(key(links_of(old)))
  kb <- unique(key(links_of(new)))
  links <- c(intersect(ka, kb), setdiff(kb, ka), setdiff(ka, kb))
  change <- rep(
    c("kept", "gained", "lost"),
    c(
      length(intersect(ka, kb)),
      length(setdiff(kb, ka)),
      length(setdiff(ka, kb))
    )
  )
  p <- strsplit(links, "\t", fixed = TRUE)
  chg <- tibble::tibble(
    from = vapply(p, `[`, "", 1),
    to = vapply(p, `[`, "", 2),
    change = change
  )
  nodes <- union(va, vb)
  if (context) {
    hot <- unique(c(
      chg$from[chg$change != "kept"],
      chg$to[chg$change != "kept"],
      added,
      removed
    ))
    nodes <- nodes[nodes %in% hot]
    chg <- chg[chg$from %in% nodes & chg$to %in% nodes, ]
  }
  if (length(nodes) > max_nodes) {
    stop(
      length(nodes),
      " nodes are too many to draw (max_nodes = ",
      max_nodes,
      "): compare a part, with vp_subset() on both versions."
    )
  }
  st <- .vp_style
  q <- .vp_dot_q
  orange <- "#C25E00"
  grey <- "#8A93A6"
  colour <- c(requires = st$blue, excludes = st$red, atleastone = st$green)[[
    graph
  ]]
  directed <- graph == "requires"
  out <- .vp_dot_head(rankdir)
  for (v in nodes) {
    attrs <- if (v %in% added) {
      sprintf('fillcolor="%s", penwidth=1.8', st$highlight)
    } else if (v %in% removed) {
      sprintf(
        paste0(
          'fillcolor="white", style="rounded,filled,dashed", fontcolor="%s", ',
          'color="%s"'
        ),
        grey,
        grey
      )
    } else {
      character(0)
    }
    out <- c(
      out,
      paste0("  ", q(v), if (length(attrs)) paste0(" [", attrs, "]"), ";")
    )
  }
  base <- if (directed) "" else "dir=none, "
  style <- if (graph == "atleastone") {
    "dotted"
  } else if (directed) {
    "solid"
  } else {
    "dashed"
  }
  for (k in seq_len(nrow(chg))) {
    a1 <- switch(
      chg$change[k],
      kept = sprintf('%scolor="%s", style=%s', base, grey, style),
      gained = sprintf(
        '%scolor="%s", style=%s, penwidth=2.6',
        base,
        colour,
        style
      ),
      lost = sprintf(
        '%scolor="%s", style=dashed, penwidth=1.6%s',
        base,
        orange,
        if (directed) "" else ", constraint=false"
      )
    )
    if (!directed && chg$change[k] != "lost") {
      a1 <- paste0(a1, ", constraint=false")
    }
    out <- c(out, sprintf("  %s -> %s [%s];", q(chg$from[k]), q(chg$to[k]), a1))
  }
  legend <- sprintf(
    paste0(
      "%s: thick = gained, dashed orange = lost, grey = kept\nyellow = new ",
      "feature, dashed box = removed feature"
    ),
    if (minimal) paste(graph, "(minimal forms)") else graph
  )
  out <- c(
    out,
    sprintf(
      '  label=%s; labelloc=b; fontsize=9; fontcolor="%s";',
      q(legend),
      grey
    ),
    "}"
  )
  paste(out, collapse = "\n")
}
