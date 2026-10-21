# How independent each team is: links inside and outside, features it decides alone

How much each team depends on the others: its features, the links inside
it and towards other teams, how many teams it is linked to, and how many
of its features are free (no link to another team: the team decides them
alone). A measure, like vp_team_links().

## Usage

``` r
vp_teams(model, teams)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- teams:

  The team of each feature: a tibble with the columns `feature` and
  `team`, or a named character vector (feature = team).

## Value

A tibble with `team`, `features`, `links_inside`, `links_outside`,
`teams_linked`, `free_features` and `free_share` (free features /
features).

## See also

Other configuration:
[`vp_can_go_together()`](https://rheradio.github.io/variplex/reference/vp_can_go_together.md),
[`vp_consequences()`](https://rheradio.github.io/variplex/reference/vp_consequences.md),
[`vp_count_graph_products()`](https://rheradio.github.io/variplex/reference/vp_count_graph_products.md),
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
[`vp_team_order()`](https://rheradio.github.io/variplex/reference/vp_team_order.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
teams <- c(
  Screen = "display",
  TouchScreen = "display",
  OLED = "display",
  CapacityButton = "display",
  ContactlessPayment = "payments",
  NFC = "payments",
  MovementFilter = "sensors",
  HeartRateSensor = "sensors",
  BLEv40 = "radio",
  BLEv42 = "radio",
  BT40 = "radio"
)
vp_teams(band, teams)
#> # A tibble: 4 × 7
#>   team     features links_inside links_outside teams_linked free_features
#>   <chr>       <int>        <int>         <int>        <int>         <int>
#> 1 display         4            9            28            3             0
#> 2 payments        2            2            18            3             0
#> 3 radio           3            3            25            3             0
#> 4 sensors         2            1            13            3             0
#> # ℹ 1 more variable: free_share <dbl>
```
