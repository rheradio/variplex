# variplex 0.1.0

* First release:
  * `vp_generate()` computes the requires, excludes and at-least-one graphs of a feature model (UVL) or of the
    Boolean formula (DIMACS) of a model written in any notation. `vp_classify()` only classifies the features, and
    `vp_history()` runs every version of a model.
  * The `vp_*` functions analyse the graphs: reading, measures of each feature, hierarchy, the whole model,
    conflicts, configuration and teams, testing, patterns and evolution.
  * `vp_plot()` draws with the R package DiagrammeR, so Graphviz does not need to be installed;
    `engine = "graphviz"` uses an installed Graphviz instead.
