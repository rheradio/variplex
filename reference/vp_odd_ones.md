# Alike in conflicts, different in requirements

The odd ones out: pairs of features that are very alike in their
conflicts but differ in what they require. Such a difference may be
intended, or a sign of a missing rule: a question for whoever maintains
the model.

## Usage

``` r
vp_odd_ones(model, threshold = 0.6)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- threshold:

  How alike the conflicts must be (Jaccard, 0.6 by default).

## Value

A tibble with `feature_1`, `feature_2`, `conflict_similarity`,
`requires_similarity` and `differs_in`.

## See also

Other patterns:
[`vp_baseline()`](https://rheradio.github.io/variplex/reference/vp_baseline.md),
[`vp_communities()`](https://rheradio.github.io/variplex/reference/vp_communities.md),
[`vp_compare_groupings()`](https://rheradio.github.io/variplex/reference/vp_compare_groupings.md),
[`vp_coreness()`](https://rheradio.github.io/variplex/reference/vp_coreness.md),
[`vp_cut_features()`](https://rheradio.github.io/variplex/reference/vp_cut_features.md),
[`vp_feature_groups()`](https://rheradio.github.io/variplex/reference/vp_feature_groups.md),
[`vp_independent_parts()`](https://rheradio.github.io/variplex/reference/vp_independent_parts.md),
[`vp_power_law()`](https://rheradio.github.io/variplex/reference/vp_power_law.md),
[`vp_robustness()`](https://rheradio.github.io/variplex/reference/vp_robustness.md),
[`vp_similar_features()`](https://rheradio.github.io/variplex/reference/vp_similar_features.md),
[`vp_triangle_significance()`](https://rheradio.github.io/variplex/reference/vp_triangle_significance.md),
[`vp_triangles()`](https://rheradio.github.io/variplex/reference/vp_triangles.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_odd_ones(band, threshold = 0.5)
#> # A tibble: 4 × 5
#>   feature_1         feature_2 conflict_similarity requires_similarity differs_in
#>   <chr>             <chr>                   <dbl>               <dbl> <chr>     
#> 1 ContactlessPayme… BLEv42                      1               0.667 Contactle…
#> 2 BLEv42            NFC                         1               0.667 NFC alone…
#> 3 TouchScreen       Contactl…                   1               0.833 Contactle…
#> 4 TouchScreen       NFC                         1               0.833 NFC alone…
```
