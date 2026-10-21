# In which order teams decide, which decide together, which must agree

In which order the teams should decide. A team waits for another when
one of its features requires a feature of the other: the requirement is
decided first, as in vp_rounds(). Teams that wait for each other
(directly or through others) must decide together. Conflicts and
at-least-one lines between teams have no right order: whoever decides
first narrows what the other can choose, so those teams must agree.

## Usage

``` r
vp_team_order(model, teams)
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

A tibble with `team`, `round` (round 1 waits for nobody), `waits_for`,
`decide_together_with` and `must_agree_with` (team names separated by
commas; "" for none).

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
vp_team_order(band, teams)
#> # A tibble: 4 × 5
#>   team     round waits_for                 decide_together_with must_agree_with 
#>   <chr>    <int> <chr>                     <chr>                <chr>           
#> 1 display      1 ""                        "radio, sensors"     radio, sensors  
#> 2 radio        1 ""                        "display, sensors"   display, paymen…
#> 3 sensors      1 ""                        "display, radio"     display, paymen…
#> 4 payments     2 "display, radio, sensors" ""                   radio, sensors  
```
