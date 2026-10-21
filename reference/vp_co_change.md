# Features whose links change in the same steps

Features that change together: pairs of features whose links change in
the same steps, as version histories of code reveal files that are
always edited together. Two features that change together without a link
between them may be tied by something the graphs do not hold (a rule
over three features, shared code, the same developer).

## Usage

``` r
vp_co_change(
  history,
  graphs = c("requires", "excludes", "atleastone"),
  min_together = 2
)
```

## Arguments

- history:

  A history: the versions of a model, from
  [`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md)
  or
  [`vp_history()`](https://rheradio.github.io/variplex/reference/vp_history.md),
  oldest first.

- graphs:

  Which graphs: any of `"requires"`, `"excludes"` and `"atleastone"`.

- min_together:

  Keep the pairs that changed together in at least this many steps.

## Value

A tibble with `feature_1`, `feature_2`, `together` (steps in which both
changed), `steps_1`, `steps_2`, `jaccard` (together over the steps in
which either changed), `through_their_link` (steps in which a link
between the two themselves changed) and `linked` (a link joins them in
the last version that has both; NA if none has).

## See also

Other evolution:
[`vp_attachment()`](https://rheradio.github.io/variplex/reference/vp_attachment.md),
[`vp_auc()`](https://rheradio.github.io/variplex/reference/vp_auc.md),
[`vp_changed_links()`](https://rheradio.github.io/variplex/reference/vp_changed_links.md),
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
vp_co_change(history, min_together = 1)
#> # A tibble: 136 × 8
#>    feature_1 feature_2       together steps_1 steps_2 jaccard through_their_link
#>    <chr>     <chr>              <int>   <int>   <int>   <dbl>              <int>
#>  1 BLEv40    BLEv42                 3       3       3       1                  0
#>  2 BLEv40    BT40                   3       3       3       1                  0
#>  3 BLEv40    CapacityButton         3       3       3       1                  3
#>  4 BLEv40    HeartRateSensor        3       3       3       1                  0
#>  5 BLEv40    MovementFilter         3       3       3       1                  1
#>  6 BLEv40    OLED                   3       3       3       1                  3
#>  7 BLEv40    Screen                 3       3       3       1                  1
#>  8 BLEv42    BT40                   3       3       3       1                  0
#>  9 BLEv42    CapacityButton         3       3       3       1                  3
#> 10 BLEv42    HeartRateSensor        3       3       3       1                  1
#> # ℹ 126 more rows
#> # ℹ 1 more variable: linked <lgl>
```
