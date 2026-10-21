# Rename features of a model

Features are matched by name when two versions are compared, so a
feature that changed its name looks like one removed and one added, and
its links drop out of the comparison. `vp_rename()` gives the features
of a version the names they have in the other one, before comparing (it
does what the option `--rename` of the command `strong4vm diff` does).
[`vp_rename_candidates()`](https://rheradio.github.io/variplex/reference/vp_rename_candidates.md)
suggests the renames.

## Usage

``` r
vp_rename(model, renames)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md).

- renames:

  The renames: a named character vector (`c(old = "new")`), a data frame
  with the columns `old` and `new` (such as the answer of
  [`vp_rename_candidates()`](https://rheradio.github.io/variplex/reference/vp_rename_candidates.md)),
  or the path of a file with one rename per line (the old name, a space,
  the new name; a tab instead of the space when a name has spaces; lines
  that start with `#` and empty lines are ignored), such as the file
  that
  [`vp_rename_candidates()`](https://rheradio.github.io/variplex/reference/vp_rename_candidates.md)
  writes.

## Value

The model with the features renamed in its features, graphs and atomic
sets. A rename whose old name is not a feature of the model changes
nothing, with a warning.

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
[`vp_rename_candidates()`](https://rheradio.github.io/variplex/reference/vp_rename_candidates.md),
[`vp_ripple()`](https://rheradio.github.io/variplex/reference/vp_ripple.md),
[`vp_state_moves()`](https://rheradio.github.io/variplex/reference/vp_state_moves.md),
[`vp_top_movers()`](https://rheradio.github.io/variplex/reference/vp_top_movers.md),
[`vp_version_distance()`](https://rheradio.github.io/variplex/reference/vp_version_distance.md)

## Examples

``` r
old <- vp_generate(vp_example("miband3_planned_old.uvl"), or_graph = TRUE)
new <- vp_generate(vp_example("miband3_realized.uvl"), or_graph = TRUE)
vp_compare(old, new) # BLEv40Old and BLEv40 look different
#> # A tibble: 3 × 10
#>   graph     kept added removed old_links new_links gained  lost jaccard spearman
#>   <chr>    <int> <int>   <int>     <int>     <int>  <int> <int>   <dbl>    <dbl>
#> 1 requires    10     1       1        10        17      7     0   0.588    0.922
#> 2 excludes    10     1       1         1         8      7     0   0.125   NA    
#> 3 atleast…    10     1       1         0         3      3     0   0       NA    
vp_compare(vp_rename(old, c(BLEv40Old = "BLEv40")), new)
#> # A tibble: 3 × 10
#>   graph     kept added removed old_links new_links gained  lost jaccard spearman
#>   <chr>    <int> <int>   <int>     <int>     <int>  <int> <int>   <dbl>    <dbl>
#> 1 requires    11     0       0        10        21     11     0   0.476    0.867
#> 2 excludes    11     0       0         3        10      7     0   0.3     NA    
#> 3 atleast…    11     0       0         0         3      3     0   0       NA    
```
