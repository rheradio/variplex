# What changed at every step

What changed at every step of a history (each version against the one
before).

## Usage

``` r
vp_history_changes(history)
```

## Arguments

- history:

  A history: the versions of a model, from
  [`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md)
  or
  [`vp_history()`](https://rheradio.github.io/variplex/reference/vp_history.md),
  oldest first.

## Value

The rows of vp_compare() for every step, with the columns `from` and
`to` (the two versions) in front.

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
vp_history_changes(history)
#> # A tibble: 12 × 13
#>     step from   to    graph  kept added removed old_links new_links gained  lost
#>    <int> <fct>  <fct> <chr> <int> <int>   <int>     <int>     <int>  <int> <int>
#>  1     1 miban… miba… requ…     0     8       0         0         0      0     0
#>  2     1 miban… miba… excl…     0     8       0         0         0      0     0
#>  3     1 miban… miba… atle…     0     8       0         0         0      0     0
#>  4     2 miban… miba… requ…     8     3       0         6        17     11     0
#>  5     2 miban… miba… excl…     8     3       0         3         9      6     0
#>  6     2 miban… miba… atle…     8     3       0         0         3      3     0
#>  7     3 miban… miba… requ…    11     6       0        21        22     11    10
#>  8     3 miban… miba… excl…    11     6       0        10        18      8     0
#>  9     3 miban… miba… atle…    11     6       0         3         1      0     2
#> 10     4 miban… miba… requ…    17     4       0        32        73     45     4
#> 11     4 miban… miba… excl…    17     4       0        35        54     23     4
#> 12     4 miban… miba… atle…    17     4       0         1         1      0     0
#> # ℹ 2 more variables: jaccard <dbl>, spearman <dbl>
```
