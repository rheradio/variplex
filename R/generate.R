# ==============================================================================
# Generating the graphs: the command line of Strong4VM as one R function
#
# vp_generate() reads a variability model (UVL) or a Boolean formula (DIMACS)
# and computes, with a SAT solver, every strong binary relationship between its
# features: the requires and excludes graphs and, with or_graph = TRUE, the
# at-least-one graph. The engine is the C++ code of Strong4VM, compiled into
# this package; its option table checks the arguments, exactly as the program
# does.
# ==============================================================================

#' Compute the strong dependency and conflict graphs of a variability model
#'
#' Reads a variability model written in UVL, or the Boolean formula of a model
#' written in any other notation (a DIMACS file, such as those that KMax,
#' KConfigReader, KconfigSampler or TraVarT produce from Kconfig and other
#' languages), and computes every *strong* binary relationship between its
#' features, that is, every relationship that holds in all the valid
#' configurations:
#'
#' * **requires**: selecting `A` always selects `B` (an arrow `A -> B`);
#' * **excludes**: `A` and `B` are never selected together;
#' * **at least one** (with `or_graph = TRUE`): every valid configuration has
#'   `A` or `B`.
#'
#' It also finds the core features (in every product), the dead features (in
#' none), the atomic sets (features that are always selected together), the
#' minimal form of the graphs (`vp_minimal()`), and, with `kernel = TRUE`, the
#' kernel (`vp_kernel()`). The results are written as files (Pajek graphs,
#' lists, a CSV report and a JSON summary) into `output_dir`, and read back as a
#' model, the object that every other function of the package takes.
#'
#' This is the command `strong4vm generate` of the Strong4VM program; every
#' option of the command line is an argument. Its other sub-commands are
#' functions of the package: `check` is [vp_check()], `expand` is [vp_expand()],
#' `explain` is [vp_explain_conflict()] and [vp_explain_requires()], and `diff`
#' is [vp_compare()] and [vp_changed_links()].
#'
#' @section What the graphs cannot show: The graphs hold relationships between
#'   **two** features. A rule that involves three or more features at once (such
#'   as "A requires B or C", or "A, B and C cannot all be selected") is not in
#'   any graph, unless it implies a relationship between two features.
#'   Everything the graphs say is true; what they do not say may still be ruled
#'   out by such a rule. `representativeness = TRUE` measures how much of the
#'   model the graphs leave out (see [vp_representativeness()]).
#'
#' @param input The path of a `.uvl` file (a feature model in the Universal
#'   Variability Language), or of a `.dimacs` or `.cnf` file (a Boolean formula
#'   in DIMACS format, whose comments `c <number> <name>` name the variables).
#' @param output_dir The folder for the files of the run. By default (`NULL`) a
#'   new temporary folder, which R deletes at the end of the session; give a
#'   folder to keep the files.
#' @param threads Number of threads for the solver. More than the number of
#'   cores is reduced to the cores.
#' @param or_graph Also compute the at-least-one graph. It roughly doubles the
#'   work of the solver, and it is needed for everything that concerns leaving
#'   features out.
#' @param kernel Also compute the kernel (see [vp_kernel()]).
#' @param atomic,minimal,check Write the atomic sets, the minimal form, and run
#'   the consistency checks on the output.
#' @param fail_on_check If a consistency check fails, stop with an error (the
#'   default) or only warn.
#' @param mig Use a modal implication graph to skip solver calls (same graphs,
#'   usually faster).
#' @param keep_dimacs For UVL input: also keep the DIMACS translation in
#'   `output_dir`.
#' @param tseitin For UVL input: translate with the Tseitin encoding (auxiliary
#'   variables) instead of the straightforward one.
#' @param strict_uvl For UVL input: a constraint that cannot be translated (not
#'   Boolean, or naming a feature that the model does not declare) is an error
#'   instead of a warning.
#' @param translator The tool that made a DIMACS file, which decides which of
#'   its variables are real options: `"auto"` detects it from the comments of
#'   the file.
#' @param tristate Tristate options `X` / `X_MODULE` of Kconfig: one node "X
#'   built in or as a module" (`"merge"`), `X` only (`"builtin"`), or both.
#' @param nonbool Value variables of non-Boolean options: one node "P is set"
#'   (`"merge"`), none (`"drop"`) or one node per value (`"keep"`).
#' @param visibility KMax visibility variables: `"drop"` or `"keep"`.
#' @param abstract_groups TraVarT abstract group features (`_xor`, `_or`,
#'   `_alt`): `"merge"` into their parent, or `"keep"`.
#' @param synthetic_root The synthetic root `__Root__` added by some
#'   translations: `"drop"` or `"keep"`.
#' @param abstract UVL features marked `{abstract}` (the root included):
#'   `"drop"`, `"keep"`, or `"merge"` into an equivalent feature that is not
#'   abstract, if there is one.
#' @param fixed_nodes Core and dead options as nodes of the graphs (`"keep"`),
#'   or only in their lists (`"drop"`).
#' @param unnamed Variables without a name comment: `"drop"`, or `"keep"` (named
#'   `v<n>`).
#' @param unknown_names Names that match no rule of the translator profile:
#'   `"keep"`, `"drop"` or `"error"`. `NULL`: `"drop"` for KMax, KConfigReader
#'   and KconfigSampler, `"keep"` otherwise.
#' @param decls A file of declared option names, one per line: other variables
#'   are dropped.
#' @param decls_unconstrained Declared names absent from the formula:
#'   `"ignore"`, or `"add"` as isolated nodes.
#' @param keep_type_prefix Keep the prefixes `boolean_` and `tristate_`
#'   (KconfigSampler).
#' @param strip_config_prefix Strip the prefix `CONFIG_`.
#' @param keep_pattern,drop_pattern Regular expressions: names to keep whatever
#'   the other rules say, or to drop.
#' @param drop_names A file of names to drop, one per line.
#' @param filter_at `"input"`: dropped variables are never queried; `"output"`:
#'   query all, filter when writing (for testing).
#' @param max_matrix_memory Above this estimate, in GB, the minimal form and the
#'   checks use sparse algorithms.
#' @param representativeness Count, with the model counter GANAK, the valid
#'   configurations and those that the graphs allow (turns on `or_graph`). Needs
#'   GANAK; see [vp_representativeness()].
#' @param ganak The GANAK program: a path, or a name found on the `PATH`.
#' @param legacy Reproduce the output of Strong4VM 1.x.
#' @param quiet Print nothing but warnings and errors. `FALSE` prints the
#'   progress of the run.
#' @param read Read the results and return the model (`TRUE`), or only return
#'   the prefix of the files.
#'
#' @return With `read = TRUE`, a model (an object of class `vp_model`, see
#'   [vp_read()]). With `read = FALSE`, the prefix of the files written
#'   (invisibly): the path of the output files without their ending.
#'
#' @seealso [vp_read()] to read the files of an earlier run; [vp_example()] for
#'   the models that come with the package.
#' @family reading
#' @export
#' @examples
#' band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#' band
#' vp_features(band)
#' vp_links(band, "excludes")
#'
#' # A Boolean formula in DIMACS format
#' f <- vp_generate(vp_example("eleven_options.dimacs"), translator = "kmax")
#' vp_links(f, "requires")
vp_generate <- function(
  input,
  output_dir = NULL,
  threads = 1,
  or_graph = FALSE,
  kernel = FALSE,
  atomic = TRUE,
  minimal = TRUE,
  check = TRUE,
  fail_on_check = TRUE,
  mig = TRUE,
  keep_dimacs = FALSE,
  tseitin = FALSE,
  strict_uvl = FALSE,
  translator = c(
    "auto",
    "kmax",
    "kconfigreader",
    "kconfigsampler",
    "travart",
    "uvl",
    "generic"
  ),
  tristate = c("merge", "builtin", "both"),
  nonbool = c("merge", "drop", "keep"),
  visibility = c("drop", "keep"),
  abstract_groups = c("merge", "keep"),
  synthetic_root = c("drop", "keep"),
  abstract = c("drop", "keep", "merge"),
  fixed_nodes = c("drop", "keep"),
  unnamed = c("drop", "keep"),
  unknown_names = NULL,
  decls = NULL,
  decls_unconstrained = c("ignore", "add"),
  keep_type_prefix = FALSE,
  strip_config_prefix = FALSE,
  keep_pattern = character(0),
  drop_pattern = character(0),
  drop_names = NULL,
  filter_at = c("input", "output"),
  max_matrix_memory = 2,
  representativeness = FALSE,
  ganak = "ganak",
  legacy = FALSE,
  quiet = TRUE,
  read = TRUE
) {
  .vp_run_engine(as.list(environment()))
}

#' Classify the variables of a formula without computing any graph
#'
#' Decides, for every variable of the formula, whether it is a real option (a
#' node of the graphs), a helper variable of the translation, or a value of a
#' non-Boolean option, with the rule that decided it. Nothing is solved, so it
#' is fast even for the Linux kernel: use it to check the options of
#' [vp_generate()] (`translator`, `tristate`, `nonbool`, ...) before a long run.
#'
#' @inheritParams vp_generate
#' @param ... Further arguments of [vp_generate()] that change the
#'   classification, such as `translator`, `tristate`, `nonbool` or
#'   `keep_pattern`.
#' @return A tibble with one row per variable of the formula: the contents of
#'   the file `__variables.csv` (its columns are described in the vignette
#'   `vignette("graphs", package = "variplex")`).
#' @family reading
#' @export
#' @examples
#' vp_classify(vp_example("eleven_options.dimacs"), translator = "kmax")
vp_classify <- function(input, output_dir = NULL, ...) {
  given <- list(...)
  unknown <- setdiff(names(given), names(formals(vp_generate)))
  if (length(unknown) || (length(given) && is.null(names(given)))) {
    stop(
      "Unknown argument(s) of vp_classify(): ",
      paste(unknown, collapse = ", "),
      call. = FALSE
    )
  }
  defaults <- lapply(formals(vp_generate)[-1], eval)
  a <- utils::modifyList(
    defaults,
    c(
      list(
        input = input,
        output_dir = output_dir,
        read = FALSE,
        classify_only = TRUE
      ),
      given
    )
  )
  prefix <- .vp_run_engine(a)
  tibble::as_tibble(utils::read.csv(
    paste0(prefix, "__variables.csv"),
    stringsAsFactors = FALSE,
    na.strings = ""
  ))
}

#' The example models that come with the package
#'
#' The package includes the variability models and data used in the examples and
#' vignettes:
#'
#' * the Mi Band smart band, in seven generations, as planned and as realised
#'   (`miband*_planned.uvl`, `miband*_realized.uvl`; `miband3.uvl` is the Mi
#'   Band 3), and variants of the Mi Band 3 that the vignettes use to show
#'   special cases (`miband3_battery.uvl`, `miband3_dead.uvl`,
#'   `miband3_void.uvl`, `miband3_no_ble.uvl`, `miband3_planned_old.uvl`,
#'   `miband3_wish.uvl`, `miband3_battery_wish.uvl`, `miband8_refactored.uvl`),
#'   with the valid configurations of two of them (`miband3_products.csv`,
#'   `miband3_battery_products.csv`), a sample of five (`sample.csv`) and a file
#'   of renames (`miband3_renames.txt`);
#' * small models with numbers, imports and other constructs of UVL
#'   (`tiny_band.uvl`, `numbers_band.uvl`, `power_band.uvl`,
#'   `power_band_boolean.uvl`, `void_numbers.uvl`, `imports_band.uvl`,
#'   `uvl_tour.uvl`);
#' * the feature models of axTLS, uClibc and fifteen versions of BusyBox in UVL
#'   (`axTLS.uvl`, `uClibc.uvl`, `busybox_01.uvl` to `busybox_15.uvl`), and a
#'   Boolean formula with eleven options of the Linux kernel in DIMACS format
#'   (`eleven_options.dimacs`);
#' * the folder `busybox`: the graphs of 37 monthly versions of BusyBox from the
#'   dataset of Strong4VM (<doi:10.5281/zenodo.17277788>), made by version 1 of
#'   Strong4VM, to read with [vp_read_history()].
#'
#' @param file The names of one or more example files. `NULL` lists them all.
#' @return The full paths of the files, or, with `file = NULL`, the names of all
#'   the example files.
#' @family reading
#' @export
#' @examples
#' vp_example()
#' vp_example("miband3.uvl")
vp_example <- function(file = NULL) {
  dir <- system.file("extdata", package = "variplex", mustWork = TRUE)
  if (is.null(file)) {
    return(.vp_sort(list.files(dir)))
  }
  path <- file.path(dir, file)
  if (!all(file.exists(path))) {
    stop(
      "There is no example file ",
      paste0("\"", file[!file.exists(path)], "\"", collapse = ", "),
      ". vp_example() lists them.",
      call. = FALSE
    )
  }
  path
}

# ------------------------------------------------------------- internal helpers

# Runs the engine for vp_generate() and vp_classify(): checks the arguments `a`
# (a list with every argument of vp_generate(), and `classify_only`), writes
# them as the command line of Strong4VM, and reads the result.
.vp_run_engine <- function(a) {
  input <- a$input
  if (!is.character(input) || length(input) != 1 || is.na(input)) {
    stop("`input` must be the path of one file.", call. = FALSE)
  }
  if (!file.exists(input)) {
    stop("The input file \"", input, "\" does not exist.", call. = FALSE)
  }
  input <- normalizePath(input, winslash = "/")
  ext <- tolower(tools::file_ext(input))
  if (!ext %in% c("uvl", "dimacs", "cnf")) {
    stop(
      "The input must be a .uvl, .dimacs or .cnf file, not .",
      ext,
      ".",
      call. = FALSE
    )
  }
  out <- a$output_dir
  if (is.null(out)) {
    out <- tempfile("variplex_")
  }
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(out)) {
    stop("Cannot create the folder \"", out, "\".", call. = FALSE)
  }
  out <- normalizePath(out, winslash = "/")

  flag <- function(name, value) if (isTRUE(value)) name
  onoff <- function(name, value) c(name, if (isTRUE(value)) "on" else "off")
  choice <- function(name, arg) {
    # only when it differs from the default (the first value)
    choices <- eval(formals(vp_generate)[[arg]])
    v <- match.arg(a[[arg]], choices)
    if (!identical(v, choices[1])) c(name, v)
  }
  file_arg <- function(name, value) {
    if (is.null(value)) {
      return(NULL)
    }
    if (!file.exists(value)) {
      stop("The file \"", value, "\" does not exist.", call. = FALSE)
    }
    c(name, normalizePath(value, winslash = "/"))
  }
  num <- function(x, what, min = 0) {
    if (!is.numeric(x) || length(x) != 1 || is.na(x) || x < min) {
      stop(
        "`",
        what,
        "` must be a number of at least ",
        min,
        ".",
        call. = FALSE
      )
    }
    format(x, scientific = FALSE, trim = TRUE)
  }
  repeated <- function(name, values) {
    as.vector(rbind(rep(name, length(values)), as.character(values)))
  }
  ganak_arg <- if (isTRUE(a$representativeness)) {
    g <- a$ganak
    path <- if (file.exists(g)) g else Sys.which(g)
    if (!nzchar(path)) {
      stop(
        "The model counter GANAK (\"",
        g,
        "\") was not found. Install it ",
        paste0(
          "(https://github.com/meelgroup/ganak/releases) and put it on the ",
          "PATH, or give its path with "
        ),
        "`ganak`.",
        call. = FALSE
      )
    }
    c("--ganak", normalizePath(path, winslash = "/"))
  }
  unknown <- if (!is.null(a$unknown_names)) {
    c("--unknown-names", match.arg(a$unknown_names, c("keep", "drop", "error")))
  }

  args <- c(
    input,
    "-o",
    out,
    "-t",
    num(a$threads, "threads", 1),
    "--progress",
    "off",
    if (isTRUE(a$quiet)) "-q",
    flag("--or-graph", a$or_graph),
    flag("--kernel", a$kernel),
    if (!isTRUE(a$atomic)) onoff("--atomic", FALSE),
    if (!isTRUE(a$minimal)) onoff("--minimal", FALSE),
    if (!isTRUE(a$check)) onoff("--check", FALSE),
    flag("--no-fail-on-check", !isTRUE(a$fail_on_check)),
    if (!isTRUE(a$mig)) onoff("--mig", FALSE),
    flag("-k", a$keep_dimacs),
    flag("-e", a$tseitin),
    flag("--strict-uvl", a$strict_uvl),
    choice("--translator", "translator"),
    choice("--tristate", "tristate"),
    choice("--nonbool", "nonbool"),
    choice("--visibility", "visibility"),
    choice("--abstract-groups", "abstract_groups"),
    choice("--synthetic-root", "synthetic_root"),
    choice("--abstract", "abstract"),
    choice("--fixed-nodes", "fixed_nodes"),
    choice("--unnamed", "unnamed"),
    unknown,
    file_arg("--decls", a$decls),
    choice("--decls-unconstrained", "decls_unconstrained"),
    flag("--keep-type-prefix", a$keep_type_prefix),
    flag("--strip-config-prefix", a$strip_config_prefix),
    repeated("--keep-pattern", a$keep_pattern),
    repeated("--drop-pattern", a$drop_pattern),
    file_arg("--drop-names", a$drop_names),
    choice("--filter-at", "filter_at"),
    if (!identical(a$max_matrix_memory, 2)) {
      c("--max-matrix-memory", num(a$max_matrix_memory, "max_matrix_memory"))
    },
    flag("--representativeness", a$representativeness),
    ganak_arg,
    flag("--legacy", a$legacy),
    flag("--classify-only", isTRUE(a$classify_only))
  )

  r <- .vp_generate_cpp(args, paste(c("strong4vm", args), collapse = " "))
  for (w in r$warnings) {
    warning(w, call. = FALSE)
  }
  if (r$exit_code != 0) {
    kind <- c(
      "usage",
      "input",
      "void_model",
      "solver",
      "unknown_name",
      "strict_uvl",
      "check_failed"
    )[r$exit_code]
    msg <- trimws(sub("^Error: ", "", r$error))
    if (r$exit_code == 3) {
      msg <- paste0(
        msg,
        "\n  The model has no valid configuration: every feature is dead."
      )
    }
    stop(errorCondition(
      msg,
      class = c(paste0("variplex_", kind), "variplex_error"),
      exit_code = r$exit_code,
      call = NULL
    ))
  }
  prefix <- file.path(out, tools::file_path_sans_ext(basename(input)))
  if (!isTRUE(a$read) || isTRUE(a$classify_only)) {
    return(invisible(prefix))
  }
  vp_read(prefix)
}

#' Compute the graphs of every version of a model
#'
#' Runs [vp_generate()] on each version of a model and gathers the results into
#' a history, the object that the functions of evolution take (as
#' [vp_read_history()] does for runs made earlier).
#'
#' @param inputs The model files of the versions (UVL or DIMACS), oldest first.
#' @param versions Names for the versions; by default the names of the files
#'   without their ending.
#' @param ... Further arguments of [vp_generate()], the same for every version
#'   (such as `or_graph = TRUE`).
#' @return A tibble with one row per version: `version` (a factor that keeps the
#'   order) and `model` (a list column of models).
#' @family reading
#' @export
#' @examples
#' gens <- c("miband1", "miband2", "miband3")
#' history <- vp_history(
#'   vp_example(paste0(gens, "_realized.uvl")),
#'   versions = gens
#' )
#' history
#' vp_history_sizes(history)
vp_history <- function(inputs, versions = NULL, ...) {
  if (is.null(versions)) {
    versions <- tools::file_path_sans_ext(basename(inputs))
  }
  if (length(versions) != length(inputs)) {
    stop("Give one name in `versions` for each input.", call. = FALSE)
  }
  if (anyDuplicated(versions)) {
    stop("The names in `versions` must be different.", call. = FALSE)
  }
  models <- lapply(inputs, vp_generate, ...)
  for (i in seq_along(models)) {
    models[[i]]$name <- versions[i]
  }
  tibble::tibble(version = factor(versions, levels = versions), model = models)
}
