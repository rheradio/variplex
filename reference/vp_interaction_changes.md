# Combinations of two features a step made possible or impossible (and the tests they touch)

The combinations of two features that a step made possible or
impossible. Among the features that can vary in both versions, a
combination of two features is possible exactly when no link forbids it
(property P3), so a gained link forbids one combination and a lost link
allows one: a lost "a requires b" allows "a without b", a lost conflict
allows "a and b", a lost at-least-one line allows "neither". With a
sample of configurations (the tests of the old version), `in_sample`
counts the configurations that have the combination: a test with a
combination now impossible is no longer valid; a combination now
possible with in_sample 0 is a new interaction that no test exercises.

## Usage

``` r
vp_interaction_changes(old, new, sample = NULL)
```

## Arguments

- old:

  The older version of a model (from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md)).

- new:

  The newer version of the same model.

- sample:

  Optional: a data frame with one 0/1 (or FALSE/TRUE) column per
  feature, one row per configuration.

## Value

A tibble with `feature_1`, `value_1`, `feature_2`, `value_2` (TRUE =
selected), `change` ("now possible" or "now impossible"), `graph` (the
link that changed) and, with a sample, `in_sample`.

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
old <- vp_generate(vp_example("miband3_planned.uvl"), or_graph = TRUE)
new <- vp_generate(vp_example("miband3_realized.uvl"), or_graph = TRUE)
vp_interaction_changes(old, new)
#> # A tibble: 21 × 6
#>    feature_1      value_1 feature_2      value_2 change         graph   
#>    <chr>          <lgl>   <chr>          <lgl>   <chr>          <chr>   
#>  1 MovementFilter TRUE    Screen         FALSE   now impossible requires
#>  2 MovementFilter TRUE    OLED           FALSE   now impossible requires
#>  3 MovementFilter TRUE    CapacityButton FALSE   now impossible requires
#>  4 MovementFilter TRUE    BLEv40         FALSE   now impossible requires
#>  5 BLEv40         TRUE    Screen         FALSE   now impossible requires
#>  6 BLEv40         TRUE    OLED           FALSE   now impossible requires
#>  7 BLEv40         TRUE    CapacityButton FALSE   now impossible requires
#>  8 BLEv42         TRUE    Screen         FALSE   now impossible requires
#>  9 BLEv42         TRUE    OLED           FALSE   now impossible requires
#> 10 BLEv42         TRUE    CapacityButton FALSE   now impossible requires
#> # ℹ 11 more rows
```
