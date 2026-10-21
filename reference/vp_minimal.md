# The minimal form: what was written, roughly

The minimal form of a model: the skeleton (arrows that do not follow
from others), the primitive conflicts and, with or_graph = TRUE, the
primitive at-least-one lines, with each atomic set as one node. It holds
the same information as the complete graphs (vp_expand() gives them
back), with far fewer links: close to what was written, while the
complete graphs hold everything that follows.

## Usage

``` r
vp_minimal(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A model with `form` "minimal"; its atomic sets are in `sets` (the
members of each node).

## Details

Measures (counts, degrees, densities, centralities, similarity,
communities, comparisons between versions) read the graphs they are
given, so on the minimal form they measure the written structure:
vp_feature_table(vp_minimal(m)) counts direct requirements, and
vp_compare() of two minimal forms compares what was written. Inferences
(can these go together, coverage, explanations, the kernel...) always
need the complete graphs: given a minimal form, they expand it first, so
their answers do not change.

## See also

Other reading:
[`vp_classify()`](https://rheradio.github.io/variplex/reference/vp_classify.md),
[`vp_example()`](https://rheradio.github.io/variplex/reference/vp_example.md),
[`vp_expand()`](https://rheradio.github.io/variplex/reference/vp_expand.md),
[`vp_features()`](https://rheradio.github.io/variplex/reference/vp_features.md),
[`vp_functions()`](https://rheradio.github.io/variplex/reference/vp_functions.md),
[`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md),
[`vp_history()`](https://rheradio.github.io/variplex/reference/vp_history.md),
[`vp_igraph()`](https://rheradio.github.io/variplex/reference/vp_igraph.md),
[`vp_links()`](https://rheradio.github.io/variplex/reference/vp_links.md),
[`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
[`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md),
[`vp_read_uvl_tree()`](https://rheradio.github.io/variplex/reference/vp_read_uvl_tree.md),
[`vp_representativeness()`](https://rheradio.github.io/variplex/reference/vp_representativeness.md),
[`vp_subset()`](https://rheradio.github.io/variplex/reference/vp_subset.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
mini <- vp_minimal(band)
mini
#> variplex model "miband3"
#>   features: 8 variable (the nodes of the graphs), 8 core, 0 dead
#>   requires: 6 arrows   excludes: 3 lines
#>   at least one: 1 lines
#>   minimal form: skeleton, primitive conflicts and primitive at-least-one lines;
#>   each atomic set is one node (2 sets)
vp_links(mini, "requires")
#> # A tibble: 6 × 2
#>   from               to             
#>   <chr>              <chr>          
#> 1 TouchScreen        BLEv42         
#> 2 ContactlessPayment TouchScreen    
#> 3 MovementFilter     BLEv40         
#> 4 BLEv40             Screen         
#> 5 BLEv42             Screen         
#> 6 BLEv42             HeartRateSensor
```
