#' variplex: analysis of strong dependency and conflict graphs of variability models
#'
#' \if{html}{\figure{logo.svg}{options: style='float: right' alt='variplex logo' width='120'}}
#' variplex computes, for a variability model, every relationship between two
#' features that holds in all its valid configurations, and analyses the
#' resulting graphs.
#'
#' * [vp_generate()] reads a feature model in UVL, or the Boolean formula
#'   (DIMACS) of a model written in any other notation, such as the Kconfig
#'   files of Linux, and computes the **requires**, **excludes** and
#'   **at-least-one** graphs with a SAT solver.
#' * More than a hundred functions, all named `vp_*`, answer questions about the
#'   graphs and return tibbles: measures of each feature, the hierarchy,
#'   conflicts and their causes, configuration, teams, combinatorial testing,
#'   network patterns and the evolution of a model through its versions.
#'   [vp_functions()] lists them by topic.
#' * [vp_plot()] draws a model or part of it; [vp_dot()] gives the Graphviz
#'   source of the drawing.
#'
#' Start with `vignette("variplex")`. The graphs hold relationships between
#' **two** features only: a rule that ties three or more features at once is in
#' no graph, unless it implies a relationship between two of them
#' (`vignette("limits-theory", package = "variplex")`).
#'
#' The engine is Strong4VM (<https://github.com/rheradio/strong4vm>), whose C++
#' code, with the SAT solver Glucose 3.0, the backbone solver BoneDigger and the
#' ANTLR 4 parser runtime, is compiled into the package.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @useDynLib variplex, .registration = TRUE
#' @importFrom Rcpp sourceCpp
## usethis namespace: end
NULL
