# Changelog

## variplex 0.1.0

- First release:
  - [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
    computes the requires, excludes and at-least-one graphs of a feature
    model (UVL) or of the Boolean formula (DIMACS) of a model written in
    any notation.
    [`vp_classify()`](https://rheradio.github.io/variplex/reference/vp_classify.md)
    only classifies the features, and
    [`vp_history()`](https://rheradio.github.io/variplex/reference/vp_history.md)
    runs every version of a model.
  - The `vp_*` functions analyse the graphs: reading, measures of each
    feature, hierarchy, the whole model, conflicts, configuration and
    teams, testing, patterns and evolution.
  - [`vp_plot()`](https://rheradio.github.io/variplex/reference/vp_plot.md)
    draws with the R package DiagrammeR, so Graphviz does not need to be
    installed; `engine = "graphviz"` uses an installed Graphviz instead.
