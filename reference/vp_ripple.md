# How many consequences each written change had

The ripple of each step: how many links of the complete graphs changed
for each link of the minimal form (what was written, roughly) that
changed. A ripple of 10 means that each written change had, on average,
ten consequences: features far from the edit gained or lost dependencies
or conflicts. Count the graphs together (the default): a written
requirement also makes conflicts, which are inherited downwards
(property P2).

## Usage

``` r
vp_ripple(history, by_graph = FALSE)
```

## Arguments

- history:

  A history: the versions of a model, from
  [`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md)
  or
  [`vp_history()`](https://rheradio.github.io/variplex/reference/vp_history.md),
  oldest first.

- by_graph:

  FALSE: one row per step, the graphs added up; TRUE: one row per step
  and graph.

## Value

A tibble with `step`, `from`, `to`, (`graph`,) `written_gained`,
`written_lost` (in the minimal forms), `gained`, `lost` (in the complete
graphs) and `ripple` (complete changes over written changes; NA when
nothing written changed).

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
[`vp_state_moves()`](https://rheradio.github.io/variplex/reference/vp_state_moves.md),
[`vp_top_movers()`](https://rheradio.github.io/variplex/reference/vp_top_movers.md),
[`vp_version_distance()`](https://rheradio.github.io/variplex/reference/vp_version_distance.md)

## Examples

``` r
gens <- c("miband1", "miband2", "miband3", "miband4", "miband6")
history <- vp_history(
  vp_example(paste0(gens, "_realized.uvl")),
  versions = gens,
  or_graph = TRUE
)
vp_ripple(history)
#> # A tibble: 4 × 8
#>    step from    to      written_gained written_lost gained  lost ripple
#>   <int> <fct>   <fct>            <int>        <int>  <int> <int>  <dbl>
#> 1     1 miband1 miband2              0            0      0     0  NA   
#> 2     2 miband2 miband3              7            2     20     0   2.22
#> 3     3 miband3 miband4              2            1     19    12  10.3 
#> 4     4 miband4 miband6              6            4     68     8   7.6 
```
