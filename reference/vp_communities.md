# Groups of closely linked features

Communities: groups of features with more links inside than a random
graph of the same degrees would give, found on the minimal form (the
complete graph links every feature to everything above it, which hides
the groups). By default only the skeleton counts; `graphs` adds the
primitive conflicts and the primitive at-least-one lines (which need
or_graph = TRUE). The algorithm (Louvain) has a random element: fix
`seed` to get the same groups again, and compare several seeds before
trusting them.

## Usage

``` r
vp_communities(model, seed = 1, graphs = "requires")
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- seed:

  The seed of the random numbers, so that the result can be repeated.
  The random state of the session is left as it was.

- graphs:

  Which graphs of the minimal form link features: any of "requires",
  "excludes", "atleastone".

## Value

A tibble with `feature` and `community` (a number); its attribute
"modularity" says how good the split is (NA when the skeleton has no
arrow: each feature is then a community of its own).

## See also

Other patterns:
[`vp_baseline()`](https://rheradio.github.io/variplex/reference/vp_baseline.md),
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
vp_communities(band)
#> # A tibble: 11 × 2
#>    feature            community
#>    <chr>                  <int>
#>  1 Screen                     1
#>  2 TouchScreen                2
#>  3 OLED                       1
#>  4 CapacityButton             1
#>  5 ContactlessPayment         2
#>  6 MovementFilter             1
#>  7 HeartRateSensor            3
#>  8 BLEv40                     1
#>  9 BLEv42                     3
#> 10 BT40                       4
#> 11 NFC                        2
```
