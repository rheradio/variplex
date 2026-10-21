# variplex: strong dependency and conflict graphs of variability models

variplex computes, for a variability model, every relationship between
two features that holds in all its valid configurations, and analyses
the resulting graphs.

## Details

- [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  reads a feature model in UVL, or the Boolean formula (DIMACS) of a
  model written in any other notation, such as the Kconfig files of
  Linux, and computes the **requires**, **excludes** and
  **at-least-one** graphs with a SAT solver.

- More than a hundred functions, all named `vp_*`, answer questions
  about the graphs and return tibbles: measures of each feature, the
  hierarchy, conflicts and their causes, configuration, teams,
  combinatorial testing, network patterns and the evolution of a model
  through its versions.
  [`vp_functions()`](https://rheradio.github.io/variplex/reference/vp_functions.md)
  lists them by topic.

- [`vp_plot()`](https://rheradio.github.io/variplex/reference/vp_plot.md)
  draws a model or part of it;
  [`vp_dot()`](https://rheradio.github.io/variplex/reference/vp_dot.md)
  gives the Graphviz source of the drawing.

Start with
[`vignette("variplex")`](https://rheradio.github.io/variplex/articles/variplex.md).
The graphs hold relationships between **two** features only: a rule that
ties three or more features at once is in no graph, unless it implies a
relationship between two of them
([`vignette("limits-theory", package = "variplex")`](https://rheradio.github.io/variplex/articles/limits-theory.md)).

The engine is Strong4VM (<https://github.com/rheradio/strong4vm>), whose
C++ code, with the SAT solver Glucose 3.0, the backbone solver
BoneDigger and the ANTLR 4 parser runtime, is compiled into the package.

## See also

Useful links:

- <https://github.com/rheradio/variplex>

- <https://github.com/rheradio/strong4vm>

- Report bugs at <https://github.com/rheradio/variplex/issues>

## Author

**Maintainer**: Rubén Heradio <rheradio@issi.uned.es>
([ORCID](https://orcid.org/0000-0002-7131-0482)) (first author of
Strong4VM and BoneDigger) \[copyright holder\]

Authors:

- Rubén Heradio <rheradio@issi.uned.es>
  ([ORCID](https://orcid.org/0000-0002-7131-0482)) (first author of
  Strong4VM and BoneDigger) \[copyright holder\]

Other contributors:

- Luis Cambelo (Strong4VM and BoneDigger) \[contributor, copyright
  holder\]

- Miguel A. Olivero (Strong4VM) \[contributor, copyright holder\]

- José Manuel Sánchez Ruíz (Strong4VM) \[contributor, copyright holder\]

- Alberto Pérez García-Plaza (Strong4VM) \[contributor, copyright
  holder\]

- David Fernández Amorós (Strong4VM) \[contributor, copyright holder\]

- Gilles Audemard (Glucose SAT solver) \[contributor, copyright holder\]

- Laurent Simon (Glucose SAT solver) \[contributor, copyright holder\]

- Niklas Eén (MiniSat, on which Glucose is based) \[contributor,
  copyright holder\]

- Niklas Sörensson (MiniSat, on which Glucose is based) \[contributor,
  copyright holder\]

- Dictino Chaos (BoneDigger backbone solver) \[contributor, copyright
  holder\]

- Terence Parr (ANTLR 4 C++ runtime) \[contributor\]

- The ANTLR Project (ANTLR 4 C++ runtime) \[copyright holder\]
