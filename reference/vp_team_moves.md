# Features with more links to another team than to their own

Features that sit better in another team: those with more links to some
other team than to their own. Moving one removes links between teams
(its links to the other team become inside links, those to its own team
become outside links). A candidate for a person to judge: who knows the
feature matters more than where its links go.

## Usage

``` r
vp_team_moves(model, teams)
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

A tibble with `feature`, `team`, `links_own` (links to features of its
own team), `better_team` and `links_better`; the largest gains first.

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
[`vp_team_order()`](https://rheradio.github.io/variplex/reference/vp_team_order.md),
[`vp_teams()`](https://rheradio.github.io/variplex/reference/vp_teams.md)

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
vp_team_moves(band, teams)
#> # A tibble: 7 × 5
#>   feature            team     links_own better_team links_better
#>   <chr>              <chr>        <int> <chr>              <int>
#> 1 BT40               radio            2 display                7
#> 2 MovementFilter     sensors          1 display                4
#> 3 BLEv40             radio            2 display                4
#> 4 BLEv42             radio            2 display                4
#> 5 ContactlessPayment payments         2 display                4
#> 6 NFC                payments         2 display                4
#> 7 HeartRateSensor    sensors          1 payments               2
```
