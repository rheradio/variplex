# The features that changed most over a history (hotspots)

How much each feature changed over a history: the links of the chosen
graphs it gained or lost, step by step (among the features that can vary
on both sides of each step, as in vp_compare()). The features that
change most are the hotspots of the history; a hotspot that many
features require is a risky foundation.

## Usage

``` r
vp_feature_churn(history, graphs = c("requires", "excludes", "atleastone"))
```

## Arguments

- history:

  A history: the versions of a model, from
  [`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md)
  or
  [`vp_history()`](https://rheradio.github.io/variplex/reference/vp_history.md),
  oldest first.

- graphs:

  The graphs whose links count.

## Value

A tibble with `feature`, `versions` (in how many it can vary),
`steps_changed`, `gained`, `lost`, `churn` (gained + lost) and
`required_by` (in the last version where it can vary), the most changed
first.

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
vp_feature_churn(history)
#> # A tibble: 21 × 7
#>    feature         versions steps_changed gained  lost churn required_by
#>    <chr>              <int>         <int>  <int> <int> <int>       <int>
#>  1 BLEv42                 4             3     15     6    21           0
#>  2 Gyroscope              2             1     19     0    19           8
#>  3 ProximitySensor        2             1     19     0    19           8
#>  4 CapacityButton         4             3     12     6    18           4
#>  5 MovementFilter         4             3     16     2    18           0
#>  6 OLED                   4             3     12     6    18           4
#>  7 BLEv50                 2             1     13     4    17           8
#>  8 BLEv40                 4             3     13     2    15           1
#>  9 TouchScreen            3             2     11     4    15          11
#> 10 FullColor              2             1     13     2    15           8
#> # ℹ 11 more rows
```
