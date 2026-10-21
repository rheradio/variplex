# How far apart every two versions are

How far apart every two versions are: the Jaccard similarity of one
graph among the features that can vary in both (the measure of
vp_compare()), for every pair of versions, not only consecutive ones. A
version much closer to an older one than to the one just before it
reverted a change.

## Usage

``` r
vp_version_distance(history, graph = c("requires", "excludes", "atleastone"))
```

## Arguments

- history:

  A history: the versions of a model, from
  [`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md)
  or
  [`vp_history()`](https://rheradio.github.io/variplex/reference/vp_history.md),
  oldest first.

- graph:

  Which graph: `"requires"`, `"excludes"` or `"atleastone"` (the last
  one needs `or_graph = TRUE` in
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)).

## Value

A tibble with `from`, `to` (every pair, the older first), `kept`,
`jaccard` and `distance` (1 - jaccard).

## See also

Other evolution:
[`vp_attachment()`](https://rheradio.github.io/variplex/reference/vp_attachment.md),
[`vp_auc()`](https://rheradio.github.io/variplex/reference/vp_auc.md),
[`vp_changed_links()`](https://rheradio.github.io/variplex/reference/vp_changed_links.md),
[`vp_co_change()`](https://rheradio.github.io/variplex/reference/vp_co_change.md),
[`vp_community_history()`](https://rheradio.github.io/variplex/reference/vp_community_history.md),
[`vp_compare()`](https://rheradio.github.io/variplex/reference/vp_compare.md),
[`vp_disruptions()`](https://rheradio.github.io/variplex/reference/vp_disruptions.md),
[`vp_edit_type()`](https://rheradio.github.io/variplex/reference/vp_edit_type.md),
[`vp_eras()`](https://rheradio.github.io/variplex/reference/vp_eras.md),
[`vp_feature_churn()`](https://rheradio.github.io/variplex/reference/vp_feature_churn.md),
[`vp_feature_states()`](https://rheradio.github.io/variplex/reference/vp_feature_states.md),
[`vp_flip_flops()`](https://rheradio.github.io/variplex/reference/vp_flip_flops.md),
[`vp_forecast_size()`](https://rheradio.github.io/variplex/reference/vp_forecast_size.md),
[`vp_growth()`](https://rheradio.github.io/variplex/reference/vp_growth.md),
[`vp_history_apply()`](https://rheradio.github.io/variplex/reference/vp_history_apply.md),
[`vp_history_changes()`](https://rheradio.github.io/variplex/reference/vp_history_changes.md),
[`vp_history_sizes()`](https://rheradio.github.io/variplex/reference/vp_history_sizes.md),
[`vp_hub_stability()`](https://rheradio.github.io/variplex/reference/vp_hub_stability.md),
[`vp_interaction_changes()`](https://rheradio.github.io/variplex/reference/vp_interaction_changes.md),
[`vp_life_cycle()`](https://rheradio.github.io/variplex/reference/vp_life_cycle.md),
[`vp_link_lifetime()`](https://rheradio.github.io/variplex/reference/vp_link_lifetime.md),
[`vp_prediction_table()`](https://rheradio.github.io/variplex/reference/vp_prediction_table.md),
[`vp_rename()`](https://rheradio.github.io/variplex/reference/vp_rename.md),
[`vp_rename_candidates()`](https://rheradio.github.io/variplex/reference/vp_rename_candidates.md),
[`vp_ripple()`](https://rheradio.github.io/variplex/reference/vp_ripple.md),
[`vp_state_moves()`](https://rheradio.github.io/variplex/reference/vp_state_moves.md),
[`vp_top_movers()`](https://rheradio.github.io/variplex/reference/vp_top_movers.md)

## Examples

``` r
gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
history <- vp_history(
  vp_example(paste0(gens, "_realized.uvl")),
  versions = gens,
  or_graph = TRUE
)
vp_version_distance(history)
#> # A tibble: 10 × 5
#>    from    to       kept jaccard distance
#>    <fct>   <fct>   <int>   <dbl>    <dbl>
#>  1 miband1 miband2     0   1        0    
#>  2 miband1 miband3     0   1        0    
#>  3 miband1 miband4     0   1        0    
#>  4 miband1 miband6     0   1        0    
#>  5 miband2 miband3     8   0.353    0.647
#>  6 miband2 miband4     8   0.364    0.636
#>  7 miband2 miband6     8   0.235    0.765
#>  8 miband3 miband4    11   0.344    0.656
#>  9 miband3 miband6    11   0.586    0.414
#> 10 miband4 miband6    17   0.364    0.636
```
