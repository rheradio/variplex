# Features most alike in one graph

The features most alike a given one in one graph (Jaccard similarity of
their neighbours: 1 for the same neighbours, 0 for none in common).

## Usage

``` r
vp_similar_features(
  model,
  feature,
  graph = c("excludes", "requires", "atleastone")
)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- feature:

  The name of a variable feature of the model.

- graph:

  Which graph: `"requires"`, `"excludes"` or `"atleastone"` (the last
  one needs `or_graph = TRUE` in
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)).

## Value

A tibble with `feature` and `similarity`, the most similar first.

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
[`vp_triangle_significance()`](https://rheradio.github.io/variplex/reference/vp_triangle_significance.md),
[`vp_triangles()`](https://rheradio.github.io/variplex/reference/vp_triangles.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_similar_features(band, "BLEv40")
#> # A tibble: 10 × 2
#>    feature            similarity
#>    <chr>                   <dbl>
#>  1 MovementFilter          0.833
#>  2 BT40                    0.4  
#>  3 Screen                  0.2  
#>  4 OLED                    0.2  
#>  5 CapacityButton          0.2  
#>  6 TouchScreen             0.143
#>  7 ContactlessPayment      0.143
#>  8 BLEv42                  0.143
#>  9 NFC                     0.143
#> 10 HeartRateSensor         0    
```
