# The Graphviz (DOT) source of a drawing

The source of a drawing in the DOT language of Graphviz.
[`vp_plot()`](https://rheradio.github.io/variplex/reference/vp_plot.md)
renders it; use it directly to edit the source by hand, or to render it
with any Graphviz tool. It needs no other package.

## Usage

``` r
vp_dot(
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
)
```

## Arguments

- x:

  What to draw: a model (from vp_read(), complete or minimal: the
  drawing shows the links it has, so a minimal form, vp_minimal(model),
  is much easier to read); or a tibble of links with `from` and `to`
  (the answer of vp_skeleton(), vp_primitive_conflicts(),
  vp_kernel_links(), vp_changed_links()...), with an optional column
  `graph` ("requires", "excludes" or "atleastone", or a column `link` as
  in vp_kernel_links(); without either, every link is a requirement); or
  a feature tree, from vp_feature_tree() or vp_read_uvl_tree() (whose
  abstract features get a dashed border); or a modal implication graph,
  from vp_mig(): its nodes are decisions, "A" and "not A" (white), and
  every arrow is an implication, in the colour and line of the link it
  comes from (`graphs` selects which; `features` and `highlight` take
  decisions).

- graphs:

  Which graphs of a model to draw.

- features:

  Draw only these features and the links among them (NULL: all).

- highlight:

  Features to fill in yellow.

- highlight_links:

  A tibble with `from` and `to`: links to draw thick.

- fill:

  A named vector: feature -\> fill colour (for example, one colour per
  community).

- merge_atomic:

  Draw each atomic set of a model as one box, with the names of its
  features one under the other.

- rankdir:

  For the layout dot: "BT" puts the features that are required at the
  top, "TB" at the bottom, "LR" and "RL" left to right and right to
  left. NULL: "BT" for graphs, "TB" for a tree (parents at the top).

- layout:

  The Graphviz program that places the nodes: "dot" (layers: best for
  requirements), "neato" and "fdp" (springs: best for conflicts), "sfdp"
  (springs, for large graphs), "circo" (a circle), "twopi" (rings around
  a centre).

- max_nodes:

  Refuse to draw more nodes than this (the layout gets slow, and the
  drawing unreadable): draw a part instead.

## Value

A character string: the DOT source.

## See also

Other drawing:
[`vp_dot_compare()`](https://rheradio.github.io/variplex/reference/vp_dot_compare.md),
[`vp_plot()`](https://rheradio.github.io/variplex/reference/vp_plot.md),
[`vp_plot_compare()`](https://rheradio.github.io/variplex/reference/vp_plot_compare.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
cat(vp_dot(vp_minimal(band)))
#> digraph strong_graphs {
#>   graph [fontname="Helvetica", fontsize=10, bgcolor="transparent", rankdir=BT, nodesep=0.2, ranksep=0.45, overlap=false, sep="+2", splines=true];
#>   node [fontname="Helvetica", fontsize=10, shape=box, style="rounded,filled", fillcolor="#F2F5FA", color="#1F2A44", fontcolor="#1F2A44", height=0.3, margin="0.06,0.04"];
#>   edge [color="#1F2A44", arrowsize=0.75];
#>   "Screen" [label="Screen\nCapacityButton\nOLED"];
#>   "TouchScreen";
#>   "ContactlessPayment" [label="ContactlessPayment\nNFC"];
#>   "MovementFilter";
#>   "HeartRateSensor";
#>   "BLEv40";
#>   "BLEv42";
#>   "BT40";
#>   "TouchScreen" -> "BLEv42" [color="#0B3D91"];
#>   "ContactlessPayment" -> "TouchScreen" [color="#0B3D91"];
#>   "MovementFilter" -> "BLEv40" [color="#0B3D91"];
#>   "BLEv40" -> "Screen" [color="#0B3D91"];
#>   "BLEv42" -> "Screen" [color="#0B3D91"];
#>   "BLEv42" -> "HeartRateSensor" [color="#0B3D91"];
#>   "BT40" -> "Screen" [dir=none, style=dashed, color="#B3261E", constraint=false];
#>   "HeartRateSensor" -> "MovementFilter" [dir=none, style=dashed, color="#B3261E", constraint=false];
#>   "BLEv40" -> "BLEv42" [dir=none, style=dashed, color="#B3261E", constraint=false];
#>   "BT40" -> "Screen" [dir=none, style=dotted, penwidth=1.8, color="#1B7F3B", constraint=false];
#> }
cat(vp_dot(vp_skeleton(band), highlight = "Screen"))
#> digraph strong_graphs {
#>   graph [fontname="Helvetica", fontsize=10, bgcolor="transparent", rankdir=BT, nodesep=0.2, ranksep=0.45, overlap=false, sep="+2", splines=true];
#>   node [fontname="Helvetica", fontsize=10, shape=box, style="rounded,filled", fillcolor="#F2F5FA", color="#1F2A44", fontcolor="#1F2A44", height=0.3, margin="0.06,0.04"];
#>   edge [color="#1F2A44", arrowsize=0.75];
#>   "TouchScreen";
#>   "ContactlessPayment";
#>   "MovementFilter";
#>   "BLEv40";
#>   "BLEv42";
#>   "Screen" [fillcolor="#FFE9B8", penwidth=1.8];
#>   "HeartRateSensor";
#>   "TouchScreen" -> "BLEv42" [color="#0B3D91"];
#>   "ContactlessPayment" -> "TouchScreen" [color="#0B3D91"];
#>   "MovementFilter" -> "BLEv40" [color="#0B3D91"];
#>   "BLEv40" -> "Screen" [color="#0B3D91"];
#>   "BLEv42" -> "Screen" [color="#0B3D91"];
#>   "BLEv42" -> "HeartRateSensor" [color="#0B3D91"];
#> }
```
