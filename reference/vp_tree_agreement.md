# Does the declared tree hide layers of requirements?

How far the declared tree is from the meaning. For each feature whose
declared parent is in the graphs: does the feature require its parent
directly (the parent is one of its direct requirements in the skeleton),
or do other features stand in between (it requires something that
requires the parent)? Features in between mean that the tree hides a
layer of the hierarchy: a "hierarchy violation" by meaning (Berger and
Guo).

## Usage

``` r
vp_tree_agreement(model, tree)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- tree:

  The feature tree of the model, from
  [`vp_read_uvl_tree()`](https://rheradio.github.io/variplex/reference/vp_read_uvl_tree.md).

## Value

A tibble with `feature`, `parent`, `direct` (TRUE/FALSE) and
`in_between` (the features between them).

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
[`vp_upset()`](https://rheradio.github.io/variplex/reference/vp_upset.md),
[`vp_width()`](https://rheradio.github.io/variplex/reference/vp_width.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
tree <- vp_read_uvl_tree(vp_example("miband3.uvl"))
vp_tree_agreement(band, tree)
#> # A tibble: 1 × 4
#>   feature     parent direct in_between
#>   <chr>       <chr>  <lgl>  <chr>     
#> 1 TouchScreen Screen FALSE  BLEv42    
```
