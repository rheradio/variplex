# The longest chain of forced decisions (all three graphs)

The longest chain of decisions: each decision forces the next, by a
requirement, a conflict or an at-least-one line (the modal implication
graph of vp_mig()). Decisions that force each other count as one step
(for example "Screen left out" and "BT40 selected", which are
opposites). It is the counterpart of the depth with the three graphs:
how long the longest explanation of a forced decision can get, conflicts
included.

## Usage

``` r
vp_longest_decision_chain(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with `step` and `decisions` (the decisions of the step, written
"A" for "A selected" and "not A" for "A left out", joined by " = " when
they force each other). Its number of rows is the length of the chain;
like the depth, it counts decisions, so a model whose features are all
free has a chain of one.

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
[`vp_redundant_candidates()`](https://rheradio.github.io/variplex/reference/vp_redundant_candidates.md),
[`vp_skeleton()`](https://rheradio.github.io/variplex/reference/vp_skeleton.md),
[`vp_tree_agreement()`](https://rheradio.github.io/variplex/reference/vp_tree_agreement.md),
[`vp_upset()`](https://rheradio.github.io/variplex/reference/vp_upset.md),
[`vp_width()`](https://rheradio.github.io/variplex/reference/vp_width.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_longest_decision_chain(band)
#> # A tibble: 5 × 2
#>    step decisions                       
#>   <int> <chr>                           
#> 1     1 MovementFilter                  
#> 2     2 not HeartRateSensor             
#> 3     3 not BLEv42                      
#> 4     4 not TouchScreen                 
#> 5     5 not ContactlessPayment = not NFC
```
