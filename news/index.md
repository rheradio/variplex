# Changelog

## variplex 0.1.0

- First release. variplex brings the engine of Strong4VM 2.0 and its R
  functions together in one package:
  - [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
    computes the requires, excludes and at-least-one graphs of a feature
    model (UVL) or of the Boolean formula (DIMACS) of a model written in
    any notation; it replaces the command line `strong4vm generate`.
    [`vp_classify()`](https://rheradio.github.io/variplex/reference/vp_classify.md)
    replaces `--classify-only`, and
    [`vp_history()`](https://rheradio.github.io/variplex/reference/vp_history.md)
    runs every version of a model.
  - The R functions of Strong4VM, renamed from `sg_*` to `vp_*`, analyse
    the graphs: reading, measures of each feature, hierarchy, the whole
    model, conflicts, configuration and teams, testing, patterns and
    evolution.
  - [`vp_plot()`](https://rheradio.github.io/variplex/reference/vp_plot.md)
    draws with the R package DiagrammeR, so Graphviz no longer needs to
    be installed; `engine = "graphviz"` still uses an installed
    Graphviz.
- The two manuals of Strong4VM (the user manual and the manual of the R
  analysis) are now vignettes.
