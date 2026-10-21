# Draw a model, some links or a feature tree

Draws what
[`vp_dot()`](https://rheradio.github.io/variplex/reference/vp_dot.md)
describes: requirements as blue arrows (from the feature that requires
to the one required), conflicts as dashed red lines and at-least-one
lines as dotted green lines. A minimal form
([`vp_minimal()`](https://rheradio.github.io/variplex/reference/vp_minimal.md))
is much easier to read than the complete graphs, which have an arrow for
every consequence.

## Usage

``` r
vp_plot(
  x,
  file = NULL,
  layout = c("dot", "neato", "fdp", "sfdp", "circo", "twopi"),
  engine = c("diagrammer", "graphviz"),
  width = NULL,
  height = NULL,
  ...
)
```

## Arguments

- x:

  What to draw; see
  [`vp_dot()`](https://rheradio.github.io/variplex/reference/vp_dot.md).

- file:

  Where to save the drawing: a file ending in `.svg`, `.pdf` or `.png`.
  `NULL`: no file (with `engine = "graphviz"`, a temporary PDF file).

- layout:

  How the nodes are placed: `"dot"` (layers: best for requirements),
  `"neato"` and `"fdp"` (springs: best for conflicts), `"sfdp"`
  (springs, for large graphs; drawn as `"fdp"` by DiagrammeR), `"circo"`
  (a circle) or `"twopi"` (rings around a centre).

- engine:

  `"diagrammer"` (the R packages DiagrammeR, DiagrammeRsvg and rsvg) or
  `"graphviz"` (the programs of Graphviz).

- width, height:

  The size of the htmlwidget (any CSS size, or a number of pixels);
  `NULL` lets it fill the space.

- ...:

  More arguments of
  [`vp_dot()`](https://rheradio.github.io/variplex/reference/vp_dot.md),
  such as `graphs`, `features`, `highlight`, `fill` or `rankdir`.

## Value

Without `file` and with DiagrammeR, an htmlwidget. With `file`, the path
of the file, invisibly.

## Details

By default the drawing is made by the package DiagrammeR, which includes
its own copy of Graphviz: nothing needs to be installed outside R.
Without `file` the result is an htmlwidget, which RStudio shows in its
viewer and R Markdown puts in the document. With `file` the drawing is
saved; SVG needs the package DiagrammeRsvg, and PDF or PNG also need
rsvg. With `engine = "graphviz"` the drawing is made by the programs of
Graphviz, if it is installed (they are looked for in
`getOption("variplex.graphviz")`, the variable `GRAPHVIZ`, the `PATH`
and the usual folders), and always saved to a file.

## See also

[`vp_dot()`](https://rheradio.github.io/variplex/reference/vp_dot.md)
for the source of the drawing and the meaning of its arguments.

Other drawing:
[`vp_dot()`](https://rheradio.github.io/variplex/reference/vp_dot.md),
[`vp_dot_compare()`](https://rheradio.github.io/variplex/reference/vp_dot_compare.md),
[`vp_plot_compare()`](https://rheradio.github.io/variplex/reference/vp_plot_compare.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
if (requireNamespace("DiagrammeR", quietly = TRUE)) {
  vp_plot(vp_minimal(band))
  vp_plot(vp_minimal(band), graphs = "excludes", layout = "neato")
  vp_plot(vp_feature_tree(band))
}

{"x":{"diagram":"digraph strong_graphs {\n  graph [layout=dot];\n  graph [fontname=\"Helvetica\", fontsize=10, bgcolor=\"transparent\", rankdir=TB, nodesep=0.2, ranksep=0.45, overlap=false, sep=\"+2\", splines=true];\n  node [fontname=\"Helvetica\", fontsize=10, shape=box, style=\"rounded,filled\", fillcolor=\"#F2F5FA\", color=\"#1F2A44\", fontcolor=\"#1F2A44\", height=0.3, margin=\"0.06,0.04\"];\n  edge [color=\"#1F2A44\", arrowsize=0.75];\n  \"Screen\";\n  \"TouchScreen\";\n  \"ContactlessPayment\";\n  \"MovementFilter\";\n  \"HeartRateSensor\";\n  \"BLEv40\";\n  \"BLEv42\";\n  \"BT40\";\n  \"BLEv42\" -> \"TouchScreen\" [arrowhead=none, color=\"#1F2A44\", penwidth=1.4];\n  \"TouchScreen\" -> \"ContactlessPayment\" [arrowhead=none, color=\"#1F2A44\", penwidth=1.4];\n  \"BLEv40\" -> \"MovementFilter\" [arrowhead=none, color=\"#1F2A44\", penwidth=1.4];\n  \"Screen\" -> \"BLEv40\" [arrowhead=none, color=\"#1F2A44\", penwidth=1.4];\n  \"HeartRateSensor\" -> \"BLEv42\" [arrowhead=none, color=\"#1F2A44\", penwidth=1.4];\n  \"BLEv42\" -> \"Screen\" [color=\"#0B3D91\", style=dashed, constraint=false];\n}","config":{"engine":"dot","options":null}},"evals":[],"jsHooks":[]}# \donttest{
if (requireNamespace("DiagrammeRsvg", quietly = TRUE)) {
  file <- vp_plot(vp_minimal(band), file = tempfile(fileext = ".svg"))
  file.exists(file)
}
#> [1] TRUE
# }
```
