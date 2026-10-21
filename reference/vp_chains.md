# The fewest chains that cover all features

The smallest set of chains that covers all the features (Dilworth's
theorem): each chain goes from a feature to one it requires, and so on.
There are as many chains as the width.

## Usage

``` r
vp_chains(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with the columns `chain`, `position` and `feature`.

## See also

Other hierarchy:
[`vp_atomic_sets()`](https://rheradio.github.io/variplex/reference/vp_atomic_sets.md),
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
[`vp_upset()`](https://rheradio.github.io/variplex/reference/vp_upset.md),
[`vp_width()`](https://rheradio.github.io/variplex/reference/vp_width.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_chains(band)
#> # A tibble: 8 × 3
#>   chain position feature           
#>   <int>    <int> <chr>             
#> 1     1        1 ContactlessPayment
#> 2     1        2 TouchScreen       
#> 3     1        3 BLEv42            
#> 4     1        4 HeartRateSensor   
#> 5     2        1 MovementFilter    
#> 6     2        2 BLEv40            
#> 7     2        3 Screen            
#> 8     3        1 BT40              
```
