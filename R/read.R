# ==============================================================================
# Topic 1. Reading the results of Strong4VM
#
# A run of Strong4VM writes its results in files that share a prefix, such as
# out/miband3_realized:
#   __requires.net     the requires graph ("if I take A, I also get B")
#   __excludes.net     the excludes graph ("A and B never go together")
#   __atleastone.net   the at-least-one graph ("every product has A or B";
#                      only with or_graph = TRUE)
#   __core.txt         features in every product
#   __dead.txt         features in no product
#   __atomic.txt       features that are always selected together
#   __variables.csv    what was decided about each variable of the formula
#   __summary.json     how the run was made
#
# vp_read() reads them all into one object, a "model", which is a list of
# tibbles. Every other function of this folder takes such a model. The graphs of
# version 1 of Strong4VM, such as those of the published Zenodo dataset, are
# read too.
# ==============================================================================

#' Read the files of one run of Strong4VM
#'
#' Read the results of one run of Strong4VM.
#'
#' @param prefix The path of the files without their ending, e.g.
#'   "out/miband3_realized" (the part before "__").
#' @param name A short name for the model, used in tables; by default the last
#'   part of the prefix.
#' @param artificial What to do with nodes whose names look like helper
#'   variables of a translation ("k!12", "__VISIBILITY__X", "<unsupported>"):
#'   "keep" (default) or "drop". Strong4VM 2.0 already drops them; "drop" is for
#'   the graphs of version 1, such as those of the Zenodo dataset.
#' @param translator With artificial = "drop": "kmax" (default) or
#'   "kconfigreader", whose formulas have two more kinds of helper variable:
#'   CHOICE_n (one per choice group) and X_MODULE ("X is built as a module",
#'   dropped only when X exists).
#' @param form "complete" (default) reads the complete graphs; "minimal" reads
#'   the minimal form that Strong4VM writes beside them
#'   (__requires_skeleton.net, __excludes_primitive.net,
#'   __atleastone_primitive.net): see vp_minimal().
#' @return A model: a list with the tibbles `features`, `requires`, `excludes`,
#'   `atleastone` (NULL when the run had no or_graph = TRUE) and `atomic`, plus
#'   `variables` and `summary` when the run wrote them.
#' @family reading
#' @export
#' @examples
#' prefix <- vp_generate(vp_example("miband3.uvl"), read = FALSE)
#' band <- vp_read(prefix)
#' band
#' vp_read(prefix, form = "minimal")
vp_read <- function(
  prefix,
  name = NULL,
  artificial = c("keep", "drop"),
  translator = c("kmax", "kconfigreader"),
  form = c("complete", "minimal")
) {
  artificial <- match.arg(artificial)
  translator <- match.arg(translator)
  form <- match.arg(form)
  if (form == "minimal") {
    return(.vp_read_minimal(prefix, name))
  }
  file <- function(ending) paste0(prefix, "__", ending)
  if (!file.exists(file("requires.net"))) {
    stop(
      "There is no file ",
      file("requires.net"),
      ".\n  The prefix is the path of the files without \"__requires.net\", ",
      "for example \"out/miband3_realized\".",
      call. = FALSE
    )
  }
  if (is.null(name)) {
    name <- basename(prefix)
  }

  req <- .vp_read_pajek(file("requires.net"))
  exc <- .vp_read_pajek(file("excludes.net"))
  alo <- if (file.exists(file("atleastone.net"))) {
    .vp_read_pajek(file("atleastone.net"))
  } else {
    NULL
  }
  core <- .vp_read_list(file("core.txt"))
  dead <- .vp_read_list(file("dead.txt"))

  nodes <- req$names
  if (
    !identical(exc$names, nodes) ||
      (!is.null(alo) && !identical(alo$names, nodes))
  ) {
    stop(
      "The graph files of ",
      prefix,
      " do not list the same features in the same order.",
      call. = FALSE
    )
  }

  # Version 1 of Strong4VM (and --fixed-nodes keep) also drew the core and dead
  # features as nodes. They are in every product, or in none, so their links say
  # nothing about choices: they are left out, as Strong4VM 2.0 does.
  drop <- nodes %in% c(core, dead)
  legacy <- any(drop)
  if (artificial == "drop") {
    everything <- c(nodes, core, dead)
    drop <- drop | !.vp_is_real_name(nodes, translator, everything)
    core <- core[.vp_is_real_name(core, translator, everything)]
    dead <- dead[.vp_is_real_name(dead, translator, everything)]
  }
  keep_links <- function(g) {
    if (is.null(g)) {
      return(NULL)
    }
    ok <- !drop[g$from] & !drop[g$to]
    tibble::tibble(from = nodes[g$from[ok]], to = nodes[g$to[ok]])
  }
  variable <- nodes[!drop]

  atomic_file <- file("atomic.txt")
  model <- list(
    name = name,
    prefix = prefix,
    features = tibble::tibble(
      feature = c(variable, core, dead),
      status = rep(
        c("variable", "core", "dead"),
        c(length(variable), length(core), length(dead))
      )
    ),
    requires = keep_links(req),
    excludes = .vp_sort_pairs(keep_links(exc), variable),
    atleastone = .vp_sort_pairs(keep_links(alo), variable),
    atomic = NULL,
    variables = if (file.exists(file("variables.csv"))) {
      tibble::as_tibble(utils::read.csv(
        file("variables.csv"),
        stringsAsFactors = FALSE,
        na.strings = ""
      ))
    } else {
      NULL
    },
    summary = if (
      file.exists(file("summary.json")) &&
        requireNamespace("jsonlite", quietly = TRUE)
    ) {
      jsonlite::fromJSON(file("summary.json"), simplifyVector = FALSE)
    } else {
      NULL
    },
    legacy = legacy,
    form = "complete"
  )
  class(model) <- "vp_model"

  # Atomic sets: from the file when there is one (its first name is the
  # representative), else from the graph.
  if (file.exists(atomic_file) && !legacy && artificial == "keep") {
    lines <- readLines(atomic_file, warn = FALSE, encoding = "UTF-8")
    sets <- strsplit(lines[nzchar(lines)], "\t", fixed = TRUE)
    model$atomic <- tibble::tibble(
      set = rep(seq_along(sets), lengths(sets)),
      feature = as.character(unlist(sets))
    )
  } else {
    model$atomic <- .vp_atomic_from_graph(model)
  }
  model
}

#' Read several runs: the versions of a model
#'
#' Read a whole history: one run of Strong4VM per version of a model.
#'
#' @param prefixes The prefixes of the runs, oldest first.
#' @param versions Names for the versions (by default, the names of the runs).
#'   Keep them in order: the functions of evolution.R compare each version with
#'   the one before it.
#' @param ... Passed to vp_read(), e.g. artificial = "drop".
#' @return A tibble with one row per version: `version` (a factor that keeps the
#'   order) and `model` (a list column).
#' @family reading
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3")
#' prefixes <- vapply(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   vp_generate,
#'   "",
#'   read = FALSE
#' )
#' vp_read_history(prefixes, versions = gens)
vp_read_history <- function(prefixes, versions = NULL, ...) {
  models <- lapply(prefixes, vp_read, ...)
  if (is.null(versions)) {
    versions <- vapply(models, `[[`, "", "name")
  }
  for (i in seq_along(models)) {
    models[[i]]$name <- versions[i]
  }
  tibble::tibble(
    version = factor(versions, levels = unique(versions)),
    model = models
  )
}

#' The features and their status (variable, core, dead)
#'
#' The features of a model and their status: "variable" (a real choice), "core"
#' (in every product) or "dead" (in none). Only the variable features are nodes
#' of the graphs.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A tibble with the columns `feature` and `status`.
#' @family reading
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_features(band)
vp_features <- function(model) model$features

#' The links of one graph, as a tibble
#'
#' The links of one graph as a tibble with the columns `from` and `to`.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param graph "requires" (from needs to), "excludes" (from and to never go
#'   together) or "atleastone" (every product has from or to). For the last two
#'   the order of the columns means nothing.
#' @return A tibble with the columns `from` and `to`.
#' @family reading
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_links(band, "requires")
#' vp_links(band, "excludes")
vp_links <- function(model, graph = c("requires", "excludes", "atleastone")) {
  graph <- match.arg(graph)
  links <- model[[graph]]
  if (is.null(links)) {
    stop(.vp_no_alo(model), call. = FALSE)
  }
  links
}

#' The igraph object of one graph
#'
#' The igraph object of one graph, for those who want to use igraph directly.
#' The vertices are the variable features, in the same order in the three
#' graphs, and each has the attribute `name`.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param graph Which graph: `"requires"`, `"excludes"` or `"atleastone"` (the
#'   last one needs `or_graph = TRUE` in [vp_generate()]).
#' @return An igraph object: directed for requires, undirected for the other
#'   graphs.
#' @family reading
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' g <- vp_igraph(band, "excludes")
#' igraph::degree(g)
vp_igraph <- function(model, graph = c("requires", "excludes", "atleastone")) {
  graph <- match.arg(graph)
  links <- vp_links(model, graph)
  igraph::graph_from_data_frame(
    links,
    directed = graph == "requires",
    vertices = .vp_nodes(model)
  )
}

#' Focus on part of a model (exact: no solver needed)
#'
#' Focus on part of a model: keep only some features, with the links among them.
#' Whether two features are related does not depend on the other features, so
#' the result is exactly the graphs of the model restricted to that part
#' (property P3 of the future-work report): no solver has to run again.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @param features The variable features to keep (for example those of one
#'   subsystem, chosen by name with grepl()).
#' @param name A name for the part.
#' @return A model, like that of vp_read(), with only those features (core and
#'   dead features are kept in its list).
#' @family reading
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' part <- vp_subset(band, c("Screen", "TouchScreen", "BT40", "BLEv40"))
#' vp_links(part, "excludes")
vp_subset <- function(model, features, name = paste0(model$name, " (part)")) {
  # P3 holds for the complete graphs, not for the minimal form
  model <- .vp_complete(model)
  features <- .vp_check_features(model, features)
  keep <- function(l) {
    if (is.null(l)) NULL else l[l$from %in% features & l$to %in% features, ]
  }
  out <- model
  out$name <- name
  out$prefix <- paste0(
    model$prefix,
    "#part:",
    paste(.vp_sort(features), collapse = ",")
  )
  out$features <- model$features[
    model$features$status != "variable" | model$features$feature %in% features,
  ]
  out$requires <- keep(model$requires)
  out$excludes <- keep(model$excludes)
  out$atleastone <- keep(model$atleastone)
  a <- model$atomic[model$atomic$feature %in% features, ]
  a <- a[a$set %in% a$set[duplicated(a$set)], ] # a set needs two members left
  a$set <- as.integer(factor(a$set, levels = unique(a$set)))
  out$atomic <- a
  if (!is.null(out$summary$representativeness)) {
    out$summary$representativeness <- list(part = TRUE)
  } # measured on the whole model
  out
}

#' The feature tree of a UVL model
#'
#' The feature tree of a UVL model: each feature with its parent, how it hangs
#' from it, and whether it is abstract. Strong4VM's graphs have no tree; the
#' tree is needed to compare them with the model (vp_false_optional(),
#' vp_tree_agreement()). Reads the "features" section of the file (indentation
#' by tabs or by four spaces).
#'
#' @param path The path of a `.uvl` file.
#' @return A tibble with `feature`, `parent` (NA for the root), `relation`
#'   ("mandatory", "optional", "alternative", "or", or a cardinality such as
#'   "\[1..2\]") and `abstract`.
#' @family reading
#' @export
#' @examples
#' vp_read_uvl_tree(vp_example("miband3.uvl"))
vp_read_uvl_tree <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- gsub("    ", "\t", lines, fixed = TRUE)
  section <- ""
  stack <- list() # each entry: its indent, kind and value
  rows <- list()
  for (raw in lines) {
    if (!nzchar(trimws(raw))) {
      next
    }
    indent <- nchar(raw) - nchar(sub("^\t+", "", raw))
    text <- trimws(raw)
    if (indent == 0) {
      section <- strsplit(text, "[[:space:]]")[[1]][1]
      next
    }
    if (section != "features") {
      next
    }
    while (length(stack) > 0 && stack[[length(stack)]]$indent >= indent) {
      stack[[length(stack)]] <- NULL
    }
    if (
      text %in%
        c("mandatory", "optional", "alternative", "or") ||
        startsWith(text, "[")
    ) {
      stack[[length(stack) + 1]] <- list(
        indent = indent,
        kind = "group",
        value = text
      )
      next
    }
    m <- regmatches(
      text,
      regexec(
        paste0(
          "^(?:(?:Integer|String|Real|Boolean)[[:space:]]+)?",
          '("[^"]+"|[^[:space:]{]+)',
          "[[:space:]]*(\\{.*\\})?"
        ),
        text,
        perl = TRUE
      )
    )[[1]]
    name <- gsub('"', "", m[2], fixed = TRUE)
    abstract <- nzchar(m[3]) &&
      grepl("abstract([[:space:]]+true)?[[:space:]]*[,}]", m[3])
    group <- if (length(stack) && stack[[length(stack)]]$kind == "group") {
      stack[[length(stack)]]$value
    } else {
      NA_character_
    }
    parents <- Filter(function(e) e$kind == "feature", stack)
    parent <- if (length(parents)) {
      parents[[length(parents)]]$value
    } else {
      NA_character_
    }
    rows[[length(rows) + 1]] <- tibble::tibble(
      feature = name,
      parent = parent,
      relation = group,
      abstract = abstract
    )
    stack[[length(stack) + 1]] <- list(
      indent = indent,
      kind = "feature",
      value = name
    )
  }
  dplyr::bind_rows(rows)
}

#' The minimal form: what was written, roughly
#'
#' The minimal form of a model: the skeleton (arrows that do not follow from
#' others), the primitive conflicts and, with or_graph = TRUE, the primitive
#' at-least-one lines, with each atomic set as one node. It holds the same
#' information as the complete graphs (vp_expand() gives them back), with far
#' fewer links: close to what was written, while the complete graphs hold
#' everything that follows.
#'
#' Measures (counts, degrees, densities, centralities, similarity, communities,
#' comparisons between versions) read the graphs they are given, so on the
#' minimal form they measure the written structure:
#' vp_feature_table(vp_minimal(m)) counts direct requirements, and vp_compare()
#' of two minimal forms compares what was written. Inferences (can these go
#' together, coverage, explanations, the kernel...) always need the complete
#' graphs: given a minimal form, they expand it first, so their answers do not
#' change.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A model with `form` "minimal"; its atomic sets are in `sets` (the
#'   members of each node).
#' @family reading
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' mini <- vp_minimal(band)
#' mini
#' vp_links(mini, "requires")
vp_minimal <- function(model) {
  if (identical(model$form, "minimal")) {
    return(model)
  }
  m <- .vp_merged(model)
  out <- model
  out$form <- "minimal"
  out$prefix <- paste0(model$prefix, "#minimal")
  fixed <- model$features[model$features$status != "variable", ]
  out$features <- dplyr::bind_rows(
    tibble::tibble(feature = m$nodes, status = "variable"),
    fixed
  )
  out$requires <- vp_skeleton(model)
  out$excludes <- vp_primitive_conflicts(model)[, c("from", "to")]
  out$atleastone <- if (is.null(model$atleastone)) {
    NULL
  } else {
    vp_primitive_atleastone(model)
  }
  out$sets <- vp_atomic_sets(model)
  out$atomic <- tibble::tibble(set = integer(0), feature = character(0))
  # so that vp_expand() lists the features as the run did
  out$node_order <- .vp_nodes(model)
  out
}

#' The complete graphs rebuilt from the minimal form
#'
#' The complete graphs rebuilt from a minimal form (as the command `strong4vm
#' expand` does): every arrow that follows from a chain, every conflict
#' inherited downwards, every at-least-one line inherited upwards, and the
#' atomic sets unfolded. A complete model is returned as it is.
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return A model in its complete form.
#' @family reading
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' mini <- vp_minimal(band)
#' identical(vp_expand(mini)$requires$from, band$requires$from)
vp_expand <- function(model) {
  if (!identical(model$form, "minimal")) {
    return(model)
  }
  key <- paste("expand", .vp_key(model), sep = "|")
  if (!is.null(.vp_cache[[key]])) {
    return(.vp_cache[[key]])
  }
  reps <- .vp_nodes(model)
  sets <- model$sets
  members <- lapply(reps, function(r) {
    c(r, sets$feature[sets$representative == r & sets$feature != r])
  })
  names(members) <- reps
  g <- igraph::graph_from_data_frame(
    model$requires,
    directed = TRUE,
    vertices = reps
  )
  n <- length(reps)
  reach <- function(mode) {
    if (n == 0) {
      list()
    } else {
      lapply(igraph::ego(g, order = n, mode = mode, mindist = 1), function(v) {
        igraph::V(g)$name[as.integer(v)]
      })
    }
  }
  up <- reach("out")
  down <- reach("in")
  names(up) <- names(down) <- reps
  cross <- function(a, b) {
    # every member of the nodes a against every member of the nodes b
    x <- unlist(members[a], use.names = FALSE)
    y <- unlist(members[b], use.names = FALSE)
    if (length(x) == 0 || length(y) == 0) {
      return(NULL)
    }
    data.frame(
      from = rep(x, each = length(y)),
      to = rep(y, times = length(x)),
      stringsAsFactors = FALSE
    )
  }
  nodes <- as.character(unlist(members, use.names = FALSE))
  if (!is.null(model$node_order) && setequal(model$node_order, nodes)) {
    nodes <- model$node_order
  }
  within <- lapply(members[lengths(members) > 1], function(x) {
    p <- expand.grid(from = x, to = x, stringsAsFactors = FALSE)
    p[p$from != p$to, ]
  })
  req <- do.call(
    rbind,
    c(lapply(reps, function(r) cross(r, up[[r]])), unname(within))
  )
  if (is.null(req)) {
    req <- data.frame(from = character(0), to = character(0))
  }
  spread <- function(links, dir) {
    if (is.null(links) || nrow(links) == 0) {
      return(links)
    }
    l <- do.call(
      rbind,
      lapply(seq_len(nrow(links)), function(k) {
        cross(
          c(links$from[k], dir[[links$from[k]]]),
          c(links$to[k], dir[[links$to[k]]])
        )
      })
    )
    dplyr::distinct(.vp_sort_pairs(tibble::as_tibble(l), nodes))
  }
  out <- model
  out$form <- "complete"
  out$prefix <- sub("#minimal$", "", model$prefix)
  fixed <- model$features[model$features$status != "variable", ]
  out$features <- dplyr::bind_rows(
    tibble::tibble(feature = nodes, status = "variable"),
    fixed
  )
  req <- dplyr::distinct(tibble::tibble(
    from = as.character(req$from),
    to = as.character(req$to)
  )) # no attribute of expand.grid
  out$requires <- req[
    order(match(req$from, nodes), match(req$to, nodes), method = "radix"),
  ]
  out$excludes <- spread(model$excludes, down)
  out$atleastone <- if (is.null(model$atleastone)) {
    NULL
  } else {
    spread(model$atleastone, up)
  }
  big <- members[lengths(members) > 1]
  out$atomic <- tibble::tibble(
    set = rep(seq_along(big), lengths(big)),
    feature = as.character(unlist(big, use.names = FALSE))
  )
  out$sets <- NULL
  out$node_order <- NULL
  .vp_cache[[key]] <- out
  out
}

#' The share of the configurations the graphs allow that are valid (GANAK)
#'
#' How much of the model the graphs leave out, as Strong4VM measured it with the
#' model counter GANAK (run with vp_generate(representativeness = TRUE)). The
#' graphs allow some configurations of the features that are not valid, because
#' they hold no rule over three or more features: `vm_configurations` is the
#' number of valid configurations of the variability model,
#' `graph_configurations` the number of configurations of the same features that
#' break no link of the graphs, and `share` = vm_configurations /
#' graph_configurations (1: the graphs say everything that the model says about
#' its features).
#'
#' @param model A model, from [vp_generate()] or [vp_read()], in its complete or
#'   its minimal form.
#' @return One row: `vm_configurations`, `graph_configurations` (numbers; very
#'   large ones are approximate, since R keeps about 15 digits; the exact values
#'   are in __summary.json), `share`, `left_out` (1 - share) and `note` (empty,
#'   or why the values are NA).
#' @family reading
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' vp_representativeness(band) # NA: the run did not count with GANAK
#' \donttest{
#' if (nzchar(Sys.which("ganak"))) {
#'   counted <- vp_generate(
#'     vp_example("miband3.uvl"),
#'     representativeness = TRUE
#'   )
#'   vp_representativeness(counted)
#' }
#' }
vp_representativeness <- function(model) {
  r <- model$summary$representativeness
  na <- function(note) {
    tibble::tibble(
      vm_configurations = NA_real_,
      graph_configurations = NA_real_,
      share = NA_real_,
      left_out = NA_real_,
      note = note
    )
  }
  if (is.null(model$summary)) {
    return(na("no __summary.json was read (it needs the R package jsonlite)"))
  }
  if (is.null(r)) {
    return(na("not measured: run vp_generate() with representativeness = TRUE"))
  }
  if (isTRUE(r$part)) {
    return(na("measured on the whole model, not on this part"))
  }
  if (!is.null(r$error)) {
    return(na(paste("GANAK could not count:", r$error)))
  }
  tibble::tibble(
    vm_configurations = as.numeric(r$configurations),
    graph_configurations = as.numeric(r$graph_choices),
    share = as.numeric(r$share),
    left_out = as.numeric(r$left_out),
    note = ""
  )
}

#' Print a model
#'
#' A short description of a model: its features, links and atomic sets.
#'
#' @param x A model.
#' @param ... Not used.
#' @return `x`, invisibly.
#' @export
#' @examples
#' vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
print.vp_model <- function(x, ...) {
  n <- table(factor(x$features$status, levels = c("variable", "core", "dead")))
  cat("variplex model \"", x$name, "\"\n", sep = "")
  cat(
    "  features: ",
    n[["variable"]],
    " variable (the nodes of the graphs), ",
    n[["core"]],
    " core, ",
    n[["dead"]],
    " dead\n",
    sep = ""
  )
  cat(
    "  requires: ",
    nrow(x$requires),
    " arrows   excludes: ",
    nrow(x$excludes),
    " lines\n",
    sep = ""
  )
  cat(
    "  at least one: ",
    if (is.null(x$atleastone)) {
      "not computed (use vp_generate(or_graph = TRUE))"
    } else {
      paste(nrow(x$atleastone), "lines")
    },
    "\n",
    sep = ""
  )
  if (!identical(x$form, "minimal")) {
    cat(
      "  atomic sets: ",
      length(unique(x$atomic$set)),
      " (of two or more features)\n",
      sep = ""
    )
  }
  rp <- x$summary$representativeness
  if (!is.null(rp$share)) {
    cat(
      "  representativeness: ",
      rp$configurations,
      " valid configurations among the ",
      rp$graph_choices,
      " the graphs allow (",
      formatC(100 * as.numeric(rp$share), format = "f", digits = 1),
      " %)\n",
      sep = ""
    )
  }
  if (isTRUE(x$legacy)) {
    cat(
      paste0(
        "  (made by version 1 of Strong4VM: core and dead features were ",
        "removed from the graphs)\n"
      )
    )
  }
  if (identical(x$form, "minimal")) {
    cat(
      "  minimal form: skeleton, primitive conflicts",
      if (!is.null(x$atleastone)) " and primitive at-least-one lines",
      ";\n",
      "  each atomic set is one node (",
      length(unique(x$sets$set)),
      " sets)\n",
      sep = ""
    )
  }
  invisible(x)
}

# ------------------------------------------------------------- internal helpers
# Everything below is used by the other files; a user never needs to call it.

# A Pajek file as written by Strong4VM: "*Vertices n", then `id "name"`, then
# "*Arcs" or "*Edges" and pairs of ids. A double quote inside a name is written
# \" ; this reader understands it (igraph's own reader does not).
.vp_read_pajek <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  head <- grep("^\\*", lines)
  if (
    length(head) == 0 ||
      !grepl("^\\*vertices", lines[head[1]], ignore.case = TRUE)
  ) {
    stop(path, " is not a Pajek file.", call. = FALSE)
  }
  n <- as.integer(strsplit(lines[head[1]], "[[:space:]]+")[[1]][2])
  vline <- lines[head[1] + seq_len(n)]
  names <- sub(
    '^[[:space:]]*[0-9]+[[:space:]]+"(.*)"[[:space:]]*$',
    "\\1",
    vline
  )
  names <- gsub('\\"', '"', names, fixed = TRUE)
  links <- if (length(head) > 1) {
    lines[seq.int(head[2] + 1, length.out = length(lines) - head[2])]
  } else {
    character(0)
  }
  links <- links[nzchar(trimws(links)) & !startsWith(links, "*")]
  pairs <- strsplit(trimws(links), "[[:space:]]+")
  list(
    names = names,
    from = as.integer(vapply(pairs, `[`, "", 1)),
    to = as.integer(vapply(pairs, `[`, "", 2))
  )
}

# core.txt and dead.txt: one feature per line, `number "name"`.
.vp_read_list <- function(path) {
  if (!file.exists(path)) {
    return(character(0))
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- lines[nzchar(trimws(lines))]
  gsub(
    '\\"',
    '"',
    sub('^[[:space:]]*-?[0-9]+[[:space:]]+"(.*)"[[:space:]]*$', "\\1", lines),
    fixed = TRUE
  )
}

# Names of real options in the graphs of version 1 (the rules of the future-work
# report, Section 1.3): letters, digits and underscores, and not a visibility
# variable of KMax. This drops k!12, <unsupported> and __VISIBILITY__X. For
# KConfigReader also CHOICE_n, and X_MODULE when X is a name too (a real option
# may end in _MODULE).
.vp_is_real_name <- function(x, translator = "kmax", everything = x) {
  ok <- grepl("^[A-Za-z0-9_]+$", x) & !startsWith(x, "__VISIBILITY__")
  if (translator == "kconfigreader") {
    ok <- ok &
      !grepl("^CHOICE_[0-9]+$", x) &
      !(grepl("_MODULE$", x) & sub("_MODULE$", "", x) %in% everything)
  }
  ok
}

# Undirected links: the smaller node first, the rows sorted, so that two
# versions can be compared line by line.
.vp_sort_pairs <- function(links, nodes) {
  if (is.null(links)) {
    return(NULL)
  }
  i <- match(links$from, nodes)
  j <- match(links$to, nodes)
  swap <- i > j
  out <- tibble::tibble(
    from = as.character(ifelse(swap, links$to, links$from)),
    to = as.character(ifelse(swap, links$from, links$to))
  )
  out[order(pmin(i, j), pmax(i, j), method = "radix"), ]
}

.vp_nodes <- function(model) {
  model$features$feature[model$features$status == "variable"]
}

.vp_no_alo <- function(model) {
  paste0(
    "The model \"",
    model$name,
    paste0(
      "\" has no at-least-one graph.\n  Run vp_generate() again with ",
      "or_graph = TRUE."
    )
  )
}

# Sparse adjacency matrix of a graph, rows and columns named after the features.
# Undirected graphs are symmetric.
.vp_matrix <- function(model, graph = c("requires", "excludes", "atleastone")) {
  graph <- match.arg(graph)
  key <- paste("matrix", graph, .vp_key(model), sep = "|")
  if (!is.null(.vp_cache[[key]])) {
    return(.vp_cache[[key]])
  }
  .vp_cache[[key]] <- .vp_matrix_build(model, graph)
  .vp_cache[[key]]
}
.vp_matrix_build <- function(model, graph) {
  nodes <- .vp_nodes(model)
  links <- model[[graph]]
  n <- length(nodes)
  if (is.null(links)) {
    return(Matrix::sparseMatrix(
      i = integer(0),
      j = integer(0),
      x = 0,
      dims = c(n, n),
      dimnames = list(nodes, nodes)
    ))
  }
  i <- match(links$from, nodes)
  j <- match(links$to, nodes)
  if (graph != "requires") {
    i2 <- c(i, j)
    j <- c(j, i)
    i <- i2
  }
  mtx <- Matrix::sparseMatrix(
    i = i,
    j = j,
    x = 1,
    dims = c(n, n),
    dimnames = list(nodes, nodes)
  )
  mtx@x[] <- 1
  mtx
}

# Atomic sets computed from the requires graph: its strongly connected
# components (version 1 wrote no atomic.txt).
.vp_atomic_from_graph <- function(model) {
  nodes <- .vp_nodes(model)
  g <- igraph::graph_from_data_frame(
    model$requires,
    directed = TRUE,
    vertices = nodes
  )
  comp <- igraph::components(g, mode = "strong")$membership
  sizes <- tabulate(comp)
  big <- which(sizes[comp] > 1)
  if (length(big) == 0) {
    return(tibble::tibble(set = integer(0), feature = character(0)))
  }
  set <- as.integer(factor(comp[big], levels = unique(comp[big])))
  tibble::tibble(set = set, feature = nodes[big])
}

# For each variable feature, the representative of its atomic set (itself if it
# is in none).
.vp_representative <- function(model) {
  nodes <- .vp_nodes(model)
  rep <- stats::setNames(nodes, nodes)
  if (nrow(model$atomic) > 0) {
    first <- model$atomic$feature[!duplicated(model$atomic$set)]
    rep[model$atomic$feature] <- first[model$atomic$set]
  }
  rep
}

# The graphs with each atomic set merged into its representative (the "merged"
# or "quotient" graphs). They have no cycles, which the measures of hierarchy.R
# need. Cached in an environment so that it is computed once per model. What
# identifies a model in the cache: where it comes from, and a cheap fingerprint
# of its contents, so that a model whose links were changed (by a user, or by
# vp_subset()) never gets the answers of another one.
.vp_key <- function(model) {
  fp <- function(l) {
    if (is.null(l)) {
      "-"
    } else {
      paste(
        nrow(l),
        sum(nchar(l$from)),
        sum(nchar(l$to)),
        sum(match(l$from, .vp_nodes(model)) * seq_len(nrow(l)), na.rm = TRUE)
      )
    }
  }
  p <- model$prefix # a part of a large model has a long prefix (all its names):
  if (nchar(p) > 500) {
    # keep the key short, as R limits the names of variables
    x <- as.numeric(utf8ToInt(p))
    p <- paste0(
      substr(p, 1, 200),
      "#",
      length(x),
      "#",
      sum(x * seq_along(x)) %% 2147483647,
      "#",
      sum(x * rev(seq_along(x))) %% 2147483629
    )
  }
  paste(
    p,
    model$name,
    model$form,
    nrow(model$features),
    sum(nchar(model$features$feature)),
    fp(model$requires),
    fp(model$excludes),
    fp(model$atleastone),
    sep = "|"
  )
}
.vp_merged <- function(model) {
  key <- paste("merged", .vp_key(model), sep = "|")
  if (!is.null(.vp_cache[[key]])) {
    return(.vp_cache[[key]])
  }
  rep <- .vp_representative(model)
  reps <- unique(unname(rep))
  merge <- function(links, directed) {
    if (is.null(links)) {
      return(NULL)
    }
    l <- tibble::tibble(
      from = unname(rep[links$from]),
      to = unname(rep[links$to])
    )
    l <- l[l$from != l$to, ]
    if (!directed) {
      l <- .vp_sort_pairs(l, reps)
    }
    dplyr::distinct(l)
  }
  m <- list(
    rep = rep,
    nodes = reps,
    requires = merge(model$requires, TRUE),
    excludes = merge(model$excludes, FALSE),
    atleastone = merge(model$atleastone, FALSE)
  )
  mat <- function(links, directed) {
    n <- length(reps)
    if (is.null(links) || nrow(links) == 0) {
      return(Matrix::sparseMatrix(
        i = integer(0),
        j = integer(0),
        x = 0,
        dims = c(n, n),
        dimnames = list(reps, reps)
      ))
    }
    i <- match(links$from, reps)
    j <- match(links$to, reps)
    if (!directed) {
      i2 <- c(i, j)
      j <- c(j, i)
      i <- i2
    }
    mtx <- Matrix::sparseMatrix(
      i = i,
      j = j,
      x = 1,
      dims = c(n, n),
      dimnames = list(reps, reps)
    )
    mtx@x[] <- 1
    mtx
  }
  m$D <- mat(m$requires, TRUE)
  m$C <- mat(m$excludes, FALSE)
  m$A <- if (is.null(m$atleastone)) NULL else mat(m$atleastone, FALSE)
  m$graph <- igraph::graph_from_data_frame(
    m$requires,
    directed = TRUE,
    vertices = reps
  )
  .vp_cache[[key]] <- m
  m
}

# The rows bound into one tibble; with no row at all, the empty `template`, so
# that an empty answer keeps its columns.
.vp_rows <- function(rows, template) {
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0) {
    return(template)
  }
  dplyr::bind_rows(rows)
}

# Check that the features given by the user are features of the model, and say
# what is wrong if they are not.
.vp_check_features <- function(model, features, allow_fixed = FALSE) {
  features <- unique(as.character(features))
  known <- if (allow_fixed) model$features$feature else .vp_nodes(model)
  unknown <- setdiff(features, known)
  if (length(unknown) > 0) {
    status <- model$features$status[match(unknown, model$features$feature)]
    why <- ifelse(
      is.na(status),
      "is not a feature of the model (check the spelling)",
      paste0("is ", status, ", so it is not a node of the graphs")
    )
    stop(paste0("\"", unknown, "\" ", why, collapse = "\n"), call. = FALSE)
  }
  features
}

# The complete graphs, whatever the form of the model: inferences call this
# first.
.vp_complete <- function(model) {
  if (identical(model$form, "minimal")) vp_expand(model) else model
}

# A run read in its minimal form: the files of the minimal form, the atomic sets
# as `sets`.
.vp_read_minimal <- function(prefix, name) {
  file <- function(ending) paste0(prefix, "__", ending)
  if (!file.exists(file("requires_skeleton.net"))) {
    stop(
      "There is no file ",
      file("requires_skeleton.net"),
      ": the run wrote no minimal form.",
      call. = FALSE
    )
  }
  req <- .vp_read_pajek(file("requires_skeleton.net"))
  exc <- .vp_read_pajek(file("excludes_primitive.net"))
  alo <- if (file.exists(file("atleastone_primitive.net"))) {
    .vp_read_pajek(file("atleastone_primitive.net"))
  } else {
    NULL
  }
  nodes <- req$names
  links <- function(g) {
    if (is.null(g)) {
      NULL
    } else {
      tibble::tibble(from = nodes[g$from], to = nodes[g$to])
    }
  }
  core <- .vp_read_list(file("core.txt"))
  dead <- .vp_read_list(file("dead.txt"))
  sets <- if (file.exists(file("atomic.txt"))) {
    l <- readLines(file("atomic.txt"), warn = FALSE, encoding = "UTF-8")
    l <- strsplit(l[nzchar(l)], "\t", fixed = TRUE)
    tibble::tibble(
      set = rep(seq_along(l), lengths(l)),
      feature = as.character(unlist(l)),
      representative = rep(vapply(l, `[`, "", 1), lengths(l))
    )
  } else {
    tibble::tibble(
      set = integer(0),
      feature = character(0),
      representative = character(0)
    )
  }
  model <- list(
    name = if (is.null(name)) basename(prefix) else name,
    prefix = paste0(prefix, "#minimal"),
    features = tibble::tibble(
      feature = c(nodes, core, dead),
      status = rep(
        c("variable", "core", "dead"),
        c(length(nodes), length(core), length(dead))
      )
    ),
    requires = links(req),
    excludes = .vp_sort_pairs(links(exc), nodes),
    atleastone = .vp_sort_pairs(links(alo), nodes),
    atomic = tibble::tibble(set = integer(0), feature = character(0)),
    sets = sets,
    variables = NULL,
    summary = NULL,
    legacy = FALSE,
    form = "minimal"
  )
  if (file.exists(file("variables.csv"))) {
    # the order of the features in the complete graphs
    v <- utils::read.csv(
      file("variables.csv"),
      stringsAsFactors = FALSE,
      na.strings = ""
    )
    v <- v[!is.na(v$node_id) & v$status == "variable", ]
    model$node_order <- v$output_name[order(v$node_id, method = "radix")]
  }
  class(model) <- "vp_model"
  model
}
