# What a random model of the same shape would give

A baseline: shuffle the skeleton many times, keeping how many direct
requirements and dependants each feature has (and the order of the
features, so that no cycle appears), and count the arrows that the
shuffled hierarchy implies. Compare the real number with the spread of
the shuffled ones to see whether the model is unusual or just what any
hierarchy of that shape would give.

## Usage

``` r
vp_baseline(model, runs = 200, seed = 1)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- runs:

  How many randomised models to build.

- seed:

  The seed of the random numbers, so that the result can be repeated.
  The random state of the session is left as it was.

## Value

A tibble with one row per shuffle: `run`, `arrows` (of the complete
graph it implies) and `implicit_share`; its attribute "observed" holds
the real values.

## Details

Only the requires graph: conflicts and at-least-one lines play no part,
neither in the shuffle nor in the numbers. (vp_triangle_significance()
also shuffles the primitive conflicts, for triangles; nothing here
shuffles the at-least-one lines.)

## See also

Other patterns:
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
[`vp_triangle_significance()`](https://rheradio.github.io/variplex/reference/vp_triangle_significance.md),
[`vp_triangles()`](https://rheradio.github.io/variplex/reference/vp_triangles.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
b <- vp_baseline(band, runs = 20)
summary(b$arrows)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   11.00   12.00   12.00   12.70   12.75   15.00 
attr(b, "observed")
#>         arrows implicit_share 
#>           12.0            0.5 
```
