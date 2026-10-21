# What some features bring along

What some features need: the features themselves and every feature they
require (their "up-set").

## Usage

``` r
vp_upset(model, features)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- features:

  One feature or several.

## Value

A tibble with the columns `feature` and `brought_by` (the first given
feature that brings it; a given feature is brought by itself).

## See also

Other hierarchy:
[`vp_atomic_sets()`](https://rheradio.github.io/variplex/reference/vp_atomic_sets.md),
[`vp_chains()`](https://rheradio.github.io/variplex/reference/vp_chains.md),
[`vp_common_dependants()`](https://rheradio.github.io/variplex/reference/vp_common_dependants.md),
[`vp_common_requirements()`](https://rheradio.github.io/variplex/reference/vp_common_requirements.md),
[`vp_depth()`](https://rheradio.github.io/variplex/reference/vp_depth.md),
[`vp_downset()`](https://rheradio.github.io/variplex/reference/vp_downset.md),
[`vp_false_optional()`](https://rheradio.github.io/variplex/reference/vp_false_optional.md),
[`vp_feature_tree()`](https://rheradio.github.io/variplex/reference/vp_feature_tree.md),
[`vp_foundations()`](https://rheradio.github.io/variplex/reference/vp_foundations.md),
[`vp_implied_requires()`](https://rheradio.github.io/variplex/reference/vp_implied_requires.md),
[`vp_largest_free_set()`](https://rheradio.github.io/variplex/reference/vp_largest_free_set.md),
[`vp_largest_unrelated_set()`](https://rheradio.github.io/variplex/reference/vp_largest_unrelated_set.md),
[`vp_leaves()`](https://rheradio.github.io/variplex/reference/vp_leaves.md),
[`vp_levels()`](https://rheradio.github.io/variplex/reference/vp_levels.md),
[`vp_longest_chain()`](https://rheradio.github.io/variplex/reference/vp_longest_chain.md),
[`vp_longest_decision_chain()`](https://rheradio.github.io/variplex/reference/vp_longest_decision_chain.md),
[`vp_redundant_candidates()`](https://rheradio.github.io/variplex/reference/vp_redundant_candidates.md),
[`vp_skeleton()`](https://rheradio.github.io/variplex/reference/vp_skeleton.md),
[`vp_tree_agreement()`](https://rheradio.github.io/variplex/reference/vp_tree_agreement.md),
[`vp_width()`](https://rheradio.github.io/variplex/reference/vp_width.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_upset(band, "TouchScreen")
#> # A tibble: 6 × 2
#>   feature         brought_by 
#>   <chr>           <chr>      
#> 1 TouchScreen     TouchScreen
#> 2 Screen          TouchScreen
#> 3 OLED            TouchScreen
#> 4 CapacityButton  TouchScreen
#> 5 HeartRateSensor TouchScreen
#> 6 BLEv42          TouchScreen
```
