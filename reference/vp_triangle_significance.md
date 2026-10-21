# Which kinds of triangle occur more, or less, often than by chance

Which kinds of triangle occur more, or less, often than by chance? The
triangles are counted on the minimal form (the skeleton and the
primitive conflicts), where each link is close to one decision of
whoever wrote the model. Chance is a model of the same shape: the
skeleton is shuffled keeping how many direct requirements and dependants
each feature has, and the order of its features (so that no cycle
appears), and the primitive conflicts are shuffled keeping how many
conflicts each feature has, independently of the requirements. A kind
that is far more frequent in the real model than in the shuffled ones is
a modelling idiom (a "network motif"); far less frequent, an anti-motif.

## Usage

``` r
vp_triangle_significance(model, runs = 100, seed = 1)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- runs:

  How many shuffled models to build.

- seed:

  The seed of the random numbers, so that the result can be repeated.
  The random state of the session is left as it was.

## Value

A tibble with `kind`, `observed`, `random_mean`, `random_sd`, `z`
((observed - mean) / sd; NA when the shuffled models never vary),
`p_more` (the share of shuffled models with at least as many) and
`p_fewer` (at most as many). The attribute "runs" says how many shuffles
were kept (a shuffle of the conflicts that repeats a line is thrown
away).

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
[`vp_robustness()`](https://rheradio.github.io/variplex/reference/vp_robustness.md),
[`vp_similar_features()`](https://rheradio.github.io/variplex/reference/vp_similar_features.md),
[`vp_triangles()`](https://rheradio.github.io/variplex/reference/vp_triangles.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_triangle_significance(band, runs = 20)
#> # A tibble: 5 × 7
#>   kind            observed random_mean random_sd      z p_more p_fewer
#>   <chr>              <dbl>       <dbl>     <dbl>  <dbl>  <dbl>   <dbl>
#> 1 no conflict            0        0        0     NA       1        1  
#> 2 one conflict           1        0.05     0.224  4.25    0.05     1  
#> 3 two conflicts          0        0        0     NA       1        1  
#> 4 three conflicts        0        0        0     NA       1        1  
#> 5 impossible             0        0.6      0.681 -0.882   1        0.5
```
