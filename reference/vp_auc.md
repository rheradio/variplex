# How good a ranking is (area under the curve)

The area under the ROC curve of a score: the chance that a case with the
outcome gets a higher score than a case without it. 0.5 is a coin toss,
1 a perfect ranking.

## Usage

``` r
vp_auc(score, outcome)
```

## Arguments

- score:

  A numeric score of each case (higher: the outcome is predicted more
  strongly).

- outcome:

  A logical vector: whether each case had the outcome.

## Value

A number between 0 and 1, or `NA` when `outcome` has only one value.

## See also

Other evolution:
[`vp_attachment()`](https://rheradio.github.io/variplex/reference/vp_attachment.md),
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
[`vp_top_movers()`](https://rheradio.github.io/variplex/reference/vp_top_movers.md),
[`vp_version_distance()`](https://rheradio.github.io/variplex/reference/vp_version_distance.md)

## Examples

``` r
vp_auc(c(0.9, 0.8, 0.3, 0.1), c(TRUE, TRUE, FALSE, FALSE))
#> [1] 1
vp_auc(c(0.1, 0.8, 0.3, 0.9), c(TRUE, TRUE, FALSE, FALSE))
#> [1] 0.25
```
