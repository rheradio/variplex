# Does a degree distribution follow a power law?

A formal test of whether a degree distribution follows a power law
(Clauset et al.). A small p-value (below 0.1) rejects the power law.
Test the skeleton: in the complete graph, any deep hierarchy gives a
long tail by itself.

## Usage

``` r
vp_power_law(model, graph = c("skeleton", "requires", "excludes"), seed = 1)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- graph:

  Which graph: `"requires"`, `"excludes"` or `"atleastone"` (the last
  one needs `or_graph = TRUE` in
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)).

- seed:

  The seed of the random numbers, so that the result can be repeated.
  The random state of the session is left as it was.

## Value

One row: `graph`, `features` (with a degree above 0), `alpha`, `xmin`,
`p_value` and `verdict`. The p-value comes from a simulation; `seed`
makes it repeatable.

## See also

Other patterns:
[`vp_baseline()`](https://rheradio.github.io/variplex/reference/vp_baseline.md),
[`vp_communities()`](https://rheradio.github.io/variplex/reference/vp_communities.md),
[`vp_compare_groupings()`](https://rheradio.github.io/variplex/reference/vp_compare_groupings.md),
[`vp_coreness()`](https://rheradio.github.io/variplex/reference/vp_coreness.md),
[`vp_cut_features()`](https://rheradio.github.io/variplex/reference/vp_cut_features.md),
[`vp_feature_groups()`](https://rheradio.github.io/variplex/reference/vp_feature_groups.md),
[`vp_independent_parts()`](https://rheradio.github.io/variplex/reference/vp_independent_parts.md),
[`vp_odd_ones()`](https://rheradio.github.io/variplex/reference/vp_odd_ones.md),
[`vp_robustness()`](https://rheradio.github.io/variplex/reference/vp_robustness.md),
[`vp_similar_features()`](https://rheradio.github.io/variplex/reference/vp_similar_features.md),
[`vp_triangle_significance()`](https://rheradio.github.io/variplex/reference/vp_triangle_significance.md),
[`vp_triangles()`](https://rheradio.github.io/variplex/reference/vp_triangles.md)

## Examples

``` r
# \donttest{
bb <- vp_generate(vp_example("busybox_01.uvl"))
vp_power_law(bb)
#> # A tibble: 1 × 6
#>   graph    features alpha  xmin p_value verdict        
#>   <chr>       <int> <dbl> <dbl>   <dbl> <chr>          
#> 1 skeleton      159  1.98     1  0.0092 not a power law
# }
```
