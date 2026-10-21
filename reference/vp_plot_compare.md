# Draw what changed between two versions

Draws what changed between two versions in one graph: links kept (grey),
gained (thick, in the colour of their graph) and lost (dashed orange);
features added (yellow) and removed (white, dashed border). By default
only the features touched by a change are drawn, and the minimal forms
are compared, so that the drawing shows what was written (an atomic set
is drawn as requirements both ways between its features, so that a
feature joining or leaving a set shows). The drawing is made as in
[`vp_plot()`](https://rheradio.github.io/variplex/reference/vp_plot.md).

## Usage

``` r
vp_plot_compare(
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
)
```

## Arguments

- old:

  The older version of a model (from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md)).

- new:

  The newer version of the same model.

- file:

  Where to save the drawing: a file ending in `.svg`, `.pdf` or `.png`.
  `NULL`: no file (with `engine = "graphviz"`, a temporary PDF file).

- graph:

  The graph to compare: `"requires"`, `"excludes"` or `"atleastone"`.

- minimal:

  Compare the minimal forms (`TRUE`) or the complete graphs (`FALSE`:
  every consequence, often a tangle).

- context:

  `TRUE`: only the features with a gained or lost link, and those added
  or removed; `FALSE`: all.

- layout:

  How the nodes are placed: `"dot"` (layers: best for requirements),
  `"neato"` and `"fdp"` (springs: best for conflicts), `"sfdp"`
  (springs, for large graphs; drawn as `"fdp"` by DiagrammeR), `"circo"`
  (a circle) or `"twopi"` (rings around a centre).

- engine:

  `"diagrammer"` (the R packages DiagrammeR, DiagrammeRsvg and rsvg) or
  `"graphviz"` (the programs of Graphviz).

- rankdir:

  The direction of the layers: `"BT"` puts the features that are
  required at the top, `"TB"` at the bottom, `"LR"` and `"RL"` left to
  right and right to left.

- max_nodes:

  Refuse to draw more nodes than this: compare a part instead, with
  [`vp_subset()`](https://rheradio.github.io/variplex/reference/vp_subset.md)
  on both versions.

- width, height:

  The size of the htmlwidget (any CSS size, or a number of pixels);
  `NULL` lets it fill the space.

## Value

Without `file` and with DiagrammeR, an htmlwidget. With `file`, the path
of the file, invisibly.

## See also

Other drawing:
[`vp_dot()`](https://rheradio.github.io/variplex/reference/vp_dot.md),
[`vp_dot_compare()`](https://rheradio.github.io/variplex/reference/vp_dot_compare.md),
[`vp_plot()`](https://rheradio.github.io/variplex/reference/vp_plot.md)

## Examples

``` r
old <- vp_generate(vp_example("miband3_planned.uvl"))
new <- vp_generate(vp_example("miband3_realized.uvl"))
if (requireNamespace("DiagrammeR", quietly = TRUE)) {
  vp_plot_compare(old, new)
}

{"x":{"diagram":"digraph strong_graphs {\n  graph [layout=dot];\n  graph [fontname=\"Helvetica\", fontsize=10, bgcolor=\"transparent\", rankdir=BT, nodesep=0.2, ranksep=0.45, overlap=false, sep=\"+2\", splines=true];\n  node [fontname=\"Helvetica\", fontsize=10, shape=box, style=\"rounded,filled\", fillcolor=\"#F2F5FA\", color=\"#1F2A44\", fontcolor=\"#1F2A44\", height=0.3, margin=\"0.06,0.04\"];\n  edge [color=\"#1F2A44\", arrowsize=0.75];\n  \"Screen\";\n  \"MovementFilter\";\n  \"HeartRateSensor\";\n  \"BLEv40\";\n  \"BLEv42\";\n  \"MovementFilter\" -> \"BLEv40\" [color=\"#0B3D91\", style=solid, penwidth=2.6];\n  \"BLEv40\" -> \"Screen\" [color=\"#0B3D91\", style=solid, penwidth=2.6];\n  \"BLEv42\" -> \"Screen\" [color=\"#0B3D91\", style=solid, penwidth=2.6];\n  \"BLEv42\" -> \"HeartRateSensor\" [color=\"#0B3D91\", style=solid, penwidth=2.6];\n  label=\"requires (minimal forms): thick = gained, dashed orange = lost, grey = kept\\nyellow = new feature, dashed box = removed feature\"; labelloc=b; fontsize=9; fontcolor=\"#8A93A6\";\n}","config":{"engine":"dot","options":null}},"evals":[],"jsHooks":[]}
```
