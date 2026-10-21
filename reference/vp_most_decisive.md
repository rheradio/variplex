# The features whose selection decides the most

The features whose selection decides the most (decision power). They
describe the model; they are not necessarily the best questions to ask
first, because the answer can be "no": the order that needs the fewest
questions follows the entropy of each question (Heradio et al., Entropy
2014), which needs the probabilities of the features, beyond what the
graphs give.

## Usage

``` r
vp_most_decisive(model, n = 10)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- n:

  How many rows to return.

## Value

The columns feature, decision_power, requires and excludes of
vp_feature_table(), the `n` largest first.

## See also

Other configuration:
[`vp_can_go_together()`](https://rheradio.github.io/variplex/reference/vp_can_go_together.md),
[`vp_consequences()`](https://rheradio.github.io/variplex/reference/vp_consequences.md),
[`vp_count_graph_products()`](https://rheradio.github.io/variplex/reference/vp_count_graph_products.md),
[`vp_kernel()`](https://rheradio.github.io/variplex/reference/vp_kernel.md),
[`vp_kernel_links()`](https://rheradio.github.io/variplex/reference/vp_kernel_links.md),
[`vp_mig()`](https://rheradio.github.io/variplex/reference/vp_mig.md),
[`vp_pair()`](https://rheradio.github.io/variplex/reference/vp_pair.md),
[`vp_partial_configuration()`](https://rheradio.github.io/variplex/reference/vp_partial_configuration.md),
[`vp_rounds()`](https://rheradio.github.io/variplex/reference/vp_rounds.md),
[`vp_split_after()`](https://rheradio.github.io/variplex/reference/vp_split_after.md),
[`vp_splitting_decisions()`](https://rheradio.github.io/variplex/reference/vp_splitting_decisions.md),
[`vp_team_links()`](https://rheradio.github.io/variplex/reference/vp_team_links.md),
[`vp_team_moves()`](https://rheradio.github.io/variplex/reference/vp_team_moves.md),
[`vp_team_order()`](https://rheradio.github.io/variplex/reference/vp_team_order.md),
[`vp_teams()`](https://rheradio.github.io/variplex/reference/vp_teams.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_most_decisive(band, n = 5)
#> # A tibble: 5 × 4
#>   feature            decision_power requires excludes
#>   <chr>                       <dbl>    <int>    <int>
#> 1 ContactlessPayment            1          7        3
#> 2 MovementFilter                1          4        6
#> 3 NFC                           1          7        3
#> 4 BT40                          0.9        0        9
#> 5 TouchScreen                   0.8        5        3
```
