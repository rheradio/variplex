# How the skeleton falls apart when hubs are removed

Robustness: remove the most required features one at a time and see how
much of the skeleton survives. With `strategy = "random"` the features
are removed at random instead, which gives the baseline.

## Usage

``` r
vp_robustness(model, steps = 5, strategy = c("hubs", "random"), seed = 1)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- steps:

  How many features to remove.

- strategy:

  `"hubs"` removes the most required features first; `"random"` removes
  them at random (the baseline).

- seed:

  The seed of the random numbers, so that the result can be repeated.
  The random state of the session is left as it was.

## Value

A tibble with `removed` (how many), `feature` (the one removed at that
step), `links_left` (arrows of the skeleton among the remaining
features) and `largest_piece` (features in the largest connected piece).

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
[`vp_power_law()`](https://rheradio.github.io/variplex/reference/vp_power_law.md),
[`vp_similar_features()`](https://rheradio.github.io/variplex/reference/vp_similar_features.md),
[`vp_triangle_significance()`](https://rheradio.github.io/variplex/reference/vp_triangle_significance.md),
[`vp_triangles()`](https://rheradio.github.io/variplex/reference/vp_triangles.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_robustness(band, steps = 3)
#> # A tibble: 4 × 4
#>   removed feature         links_left largest_piece
#>     <int> <chr>                <dbl>         <dbl>
#> 1       0 NA                       6             7
#> 2       1 Screen                   4             4
#> 3       2 HeartRateSensor          3             3
#> 4       3 BLEv42                   2             2
```
