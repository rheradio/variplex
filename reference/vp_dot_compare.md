# The Graphviz (DOT) source of a drawing of what changed

The source, in the DOT language of Graphviz, of the drawing of
[`vp_plot_compare()`](https://rheradio.github.io/variplex/reference/vp_plot_compare.md).

## Usage

``` r
vp_dot_compare(
  old,
  new,
  graph = c("requires", "excludes", "atleastone"),
  minimal = TRUE,
  context = TRUE,
  rankdir = "BT",
  max_nodes = 400
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

- graph:

  The graph to compare: `"requires"`, `"excludes"` or `"atleastone"`.

- minimal:

  Compare the minimal forms (`TRUE`) or the complete graphs (`FALSE`:
  every consequence, often a tangle).

- context:

  `TRUE`: only the features with a gained or lost link, and those added
  or removed; `FALSE`: all.

- rankdir:

  The direction of the layers: `"BT"` puts the features that are
  required at the top, `"TB"` at the bottom, `"LR"` and `"RL"` left to
  right and right to left.

- max_nodes:

  Refuse to draw more nodes than this: compare a part instead, with
  [`vp_subset()`](https://rheradio.github.io/variplex/reference/vp_subset.md)
  on both versions.

## Value

A character string: the DOT source.

## See also

Other drawing:
[`vp_dot()`](https://rheradio.github.io/variplex/reference/vp_dot.md),
[`vp_plot()`](https://rheradio.github.io/variplex/reference/vp_plot.md),
[`vp_plot_compare()`](https://rheradio.github.io/variplex/reference/vp_plot_compare.md)

## Examples

``` r
old <- vp_generate(vp_example("miband3_planned.uvl"))
new <- vp_generate(vp_example("miband3_realized.uvl"))
cat(vp_dot_compare(old, new))
#> digraph strong_graphs {
#>   graph [fontname="Helvetica", fontsize=10, bgcolor="transparent", rankdir=BT, nodesep=0.2, ranksep=0.45, overlap=false, sep="+2", splines=true];
#>   node [fontname="Helvetica", fontsize=10, shape=box, style="rounded,filled", fillcolor="#F2F5FA", color="#1F2A44", fontcolor="#1F2A44", height=0.3, margin="0.06,0.04"];
#>   edge [color="#1F2A44", arrowsize=0.75];
#>   "Screen";
#>   "MovementFilter";
#>   "HeartRateSensor";
#>   "BLEv40";
#>   "BLEv42";
#>   "MovementFilter" -> "BLEv40" [color="#0B3D91", style=solid, penwidth=2.6];
#>   "BLEv40" -> "Screen" [color="#0B3D91", style=solid, penwidth=2.6];
#>   "BLEv42" -> "Screen" [color="#0B3D91", style=solid, penwidth=2.6];
#>   "BLEv42" -> "HeartRateSensor" [color="#0B3D91", style=solid, penwidth=2.6];
#>   label="requires (minimal forms): thick = gained, dashed orange = lost, grey = kept\nyellow = new feature, dashed box = removed feature"; labelloc=b; fontsize=9; fontcolor="#8A93A6";
#> }
```
