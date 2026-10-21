# A feature tree rebuilt from the skeleton

A feature tree rebuilt from the skeleton: each feature gets as parent
one of the features it requires directly. When there are several
candidates, the least required one is chosen, and the others become
cross-tree arrows.

## Usage

``` r
vp_feature_tree(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with the columns `feature`, `parent` (NA for a feature that
needs nothing), `candidates` (how many features it requires directly)
and `cross_tree` (the candidates that were not chosen, separated by
commas).

## See also

Other hierarchy:
[`vp_atomic_sets()`](https://rheradio.github.io/variplex/reference/vp_atomic_sets.md),
[`vp_chains()`](https://rheradio.github.io/variplex/reference/vp_chains.md),
[`vp_common_dependants()`](https://rheradio.github.io/variplex/reference/vp_common_dependants.md),
[`vp_common_requirements()`](https://rheradio.github.io/variplex/reference/vp_common_requirements.md),
[`vp_depth()`](https://rheradio.github.io/variplex/reference/vp_depth.md),
[`vp_downset()`](https://rheradio.github.io/variplex/reference/vp_downset.md),
[`vp_false_optional()`](https://rheradio.github.io/variplex/reference/vp_false_optional.md),
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
[`vp_upset()`](https://rheradio.github.io/variplex/reference/vp_upset.md),
[`vp_width()`](https://rheradio.github.io/variplex/reference/vp_width.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_feature_tree(band)
#> # A tibble: 8 × 4
#>   feature            parent          candidates cross_tree
#>   <chr>              <chr>                <int> <chr>     
#> 1 Screen             NA                       0 ""        
#> 2 TouchScreen        BLEv42                   1 ""        
#> 3 ContactlessPayment TouchScreen              1 ""        
#> 4 MovementFilter     BLEv40                   1 ""        
#> 5 HeartRateSensor    NA                       0 ""        
#> 6 BLEv40             Screen                   1 ""        
#> 7 BLEv42             HeartRateSensor          2 "Screen"  
#> 8 BT40               NA                       0 ""        
```
