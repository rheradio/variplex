# The four kinds of triangle

The four kinds of triangle: three features all related to one another,
by requirement (in either direction) or by conflict. Each kind is a
modelling idiom. A fifth pattern must never occur: a feature that
requires two features that exclude each other (it would be dead).

## Usage

``` r
vp_triangles(model, minimal = FALSE)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- minimal:

  TRUE to count on the skeleton and the primitive conflicts, which drops
  the triangles that are mere consequences of others.

## Value

A tibble with `kind`, `meaning` and `count`.

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
[`vp_triangle_significance()`](https://rheradio.github.io/variplex/reference/vp_triangle_significance.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_triangles(band)
#> # A tibble: 5 × 3
#>   kind            meaning                                                  count
#>   <chr>           <chr>                                                    <dbl>
#> 1 no conflict     a chain of requirements                                      8
#> 2 one conflict    alternatives with a common requirement                       6
#> 3 two conflicts   an inherited conflict                                       21
#> 4 three conflicts three alternatives                                           6
#> 5 impossible      a feature requiring, directly or through the third, two…     0
```
