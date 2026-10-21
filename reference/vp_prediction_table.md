# One row per feature and version, for predictions

One row per feature and version, with measures taken in that version
(the predictors) and what happened to the feature afterwards (the
outcomes): the table that a prediction model learns from.

## Usage

``` r
vp_prediction_table(history, horizon = 3)
```

## Arguments

- history:

  A history: the versions of a model, from
  [`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md)
  or
  [`vp_history()`](https://rheradio.github.io/variplex/reference/vp_history.md),
  oldest first.

- horizon:

  How many versions ahead `gone_later` looks.

## Value

A tibble with `version`, `feature`, `age` (versions since it could first
vary), the measures `required_by`, `requires`, `excludes`, `level`,
`direct_dependants`, `betweenness`, and the outcomes `gone_next` (absent
in the next version), `gone_later` (absent `horizon` versions later; NA
near the end) and `new_dependants` (new features that require it
directly in the next version).

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
vp_prediction_table(history, horizon = 2)
#> # A tibble: 36 × 12
#>    version feature     age required_by requires excludes level direct_dependants
#>    <fct>   <chr>     <dbl>       <int>    <int>    <int> <int>             <int>
#>  1 miband2 Screen        0           2        2        0     0                 0
#>  2 miband2 OLED          0           2        2        0     0                 0
#>  3 miband2 Capacity…     0           2        2        0     0                 0
#>  4 miband2 Movement…     0           0        0        0     0                 0
#>  5 miband2 HeartRat…     0           0        0        0     0                 0
#>  6 miband2 BLEv40        0           0        0        2     0                 0
#>  7 miband2 BLEv42        0           0        0        2     0                 0
#>  8 miband2 BT40          0           0        0        2     0                 0
#>  9 miband3 Screen        1           6        2        1     0                 3
#> 10 miband3 TouchScr…     0           0        3        1     1                 0
#> # ℹ 26 more rows
#> # ℹ 4 more variables: betweenness <dbl>, gone_next <lgl>, gone_later <lgl>,
#> #   new_dependants <int>
```
