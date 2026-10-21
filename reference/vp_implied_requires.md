# The arrows that follow from others, and through what

The arrows of the requires graph that follow from others, with one
feature through which each one passes.

## Usage

``` r
vp_implied_requires(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with the columns `from`, `to` and `via`: from requires via, and
via requires to.

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
vp_implied_requires(band)
#> # A tibble: 6 × 3
#>   from               to              via        
#>   <chr>              <chr>           <chr>      
#> 1 TouchScreen        Screen          BLEv42     
#> 2 TouchScreen        HeartRateSensor BLEv42     
#> 3 ContactlessPayment Screen          TouchScreen
#> 4 ContactlessPayment HeartRateSensor TouchScreen
#> 5 ContactlessPayment BLEv42          TouchScreen
#> 6 MovementFilter     Screen          BLEv40     
```
