# Parts of the model that no relationship ties together

Independent parts: groups of features that no relationship ties to the
rest (connected pieces of the three graphs taken together). As far as
relationships between two features go, each part can be configured, and
tested, on its own: a choice in one part never forces or forbids
anything in another.

## Usage

``` r
vp_independent_parts(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with `part`, `size` and `feature`, the largest parts first (a
feature in no graph is a part alone).

## See also

Other patterns:
[`vp_baseline()`](https://rheradio.github.io/variplex/reference/vp_baseline.md),
[`vp_communities()`](https://rheradio.github.io/variplex/reference/vp_communities.md),
[`vp_compare_groupings()`](https://rheradio.github.io/variplex/reference/vp_compare_groupings.md),
[`vp_coreness()`](https://rheradio.github.io/variplex/reference/vp_coreness.md),
[`vp_cut_features()`](https://rheradio.github.io/variplex/reference/vp_cut_features.md),
[`vp_feature_groups()`](https://rheradio.github.io/variplex/reference/vp_feature_groups.md),
[`vp_odd_ones()`](https://rheradio.github.io/variplex/reference/vp_odd_ones.md),
[`vp_power_law()`](https://rheradio.github.io/variplex/reference/vp_power_law.md),
[`vp_robustness()`](https://rheradio.github.io/variplex/reference/vp_robustness.md),
[`vp_similar_features()`](https://rheradio.github.io/variplex/reference/vp_similar_features.md),
[`vp_triangle_significance()`](https://rheradio.github.io/variplex/reference/vp_triangle_significance.md),
[`vp_triangles()`](https://rheradio.github.io/variplex/reference/vp_triangles.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_independent_parts(band)
#> # A tibble: 11 × 3
#>     part  size feature           
#>    <int> <int> <chr>             
#>  1     1    11 Screen            
#>  2     1    11 TouchScreen       
#>  3     1    11 OLED              
#>  4     1    11 CapacityButton    
#>  5     1    11 ContactlessPayment
#>  6     1    11 MovementFilter    
#>  7     1    11 HeartRateSensor   
#>  8     1    11 BLEv40            
#>  9     1    11 BLEv42            
#> 10     1    11 BT40              
#> 11     1    11 NFC               
```
