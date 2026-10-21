# Features grouped by their measures

Features grouped by their measures (the columns of vp_feature_table()):
features in the same group play a similar role. Hierarchical clustering
on the scaled measures.

## Usage

``` r
vp_feature_groups(
  model,
  groups = 4,
  measures = c("required_by", "requires", "excludes", "level", "betweenness")
)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- groups:

  How many groups.

- measures:

  The columns of
  [`vp_feature_table()`](https://rheradio.github.io/variplex/reference/vp_feature_table.md)
  to group by.

## Value

A tibble with `feature` and `group`.

## See also

Other patterns:
[`vp_baseline()`](https://rheradio.github.io/variplex/reference/vp_baseline.md),
[`vp_communities()`](https://rheradio.github.io/variplex/reference/vp_communities.md),
[`vp_compare_groupings()`](https://rheradio.github.io/variplex/reference/vp_compare_groupings.md),
[`vp_coreness()`](https://rheradio.github.io/variplex/reference/vp_coreness.md),
[`vp_cut_features()`](https://rheradio.github.io/variplex/reference/vp_cut_features.md),
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
vp_feature_groups(band, groups = 3)
#> # A tibble: 11 × 2
#>    feature            group
#>    <chr>              <int>
#>  1 Screen                 1
#>  2 TouchScreen            2
#>  3 OLED                   1
#>  4 CapacityButton         1
#>  5 ContactlessPayment     2
#>  6 MovementFilter         2
#>  7 HeartRateSensor        1
#>  8 BLEv40                 2
#>  9 BLEv42                 2
#> 10 BT40                   3
#> 11 NFC                    2
```
