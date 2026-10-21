# How many products the graphs allow (small models)

How many products the graphs allow, by trying every selection of the
variable features. Only for small models (`max_features`, 20 by
default). It shows how much of the model the graphs capture: compare the
last number with the number of valid configurations of the model, when
it is known.

## Usage

``` r
vp_count_graph_products(model, max_features = 20, products = NULL)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- max_features:

  The largest number of variable features to try (2^n selections).

- products:

  The number of valid products of the model, if you know it (from a
  model counter): then two more columns say how much of the model the
  graphs explain, on a scale of yes/no choices (bits).

## Value

One row: `selections` (2^n), `respect_requires`, `and_excludes`,
`and_atleastone` (NA without or_graph = TRUE); with `products`, also
`bits_model` (how many of the n yes/no choices the model takes away: n -
log2(products)) and `explained` (the share of them that the graphs take
away).

## See also

Other configuration:
[`vp_can_go_together()`](https://rheradio.github.io/variplex/reference/vp_can_go_together.md),
[`vp_consequences()`](https://rheradio.github.io/variplex/reference/vp_consequences.md),
[`vp_kernel()`](https://rheradio.github.io/variplex/reference/vp_kernel.md),
[`vp_kernel_links()`](https://rheradio.github.io/variplex/reference/vp_kernel_links.md),
[`vp_mig()`](https://rheradio.github.io/variplex/reference/vp_mig.md),
[`vp_most_decisive()`](https://rheradio.github.io/variplex/reference/vp_most_decisive.md),
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
vp_count_graph_products(band)
#> # A tibble: 1 × 4
#>   selections respect_requires and_excludes and_atleastone
#>        <dbl>            <int>        <int>          <int>
#> 1       2048               34           12             10
```
