# The links between features of different teams: where teams interfere

The links between teams: every link of the graphs whose two features
belong to different teams. Each one is a place where a decision of one
team forces, forbids or needs a decision of another. A measure: on the
complete graphs it lists every pair of features of two teams that
constrain each other; on the minimal form, roughly what was written
between them.

## Usage

``` r
vp_team_links(model, teams)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- teams:

  A tibble with `feature` and `team`, or a named character vector
  (feature = team).

## Value

A tibble with `from`, `from_team`, `link` ("requires": `from` requires
`to`; "excludes"; "atleastone") , `to` and `to_team`.

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
[`vp_team_moves()`](https://rheradio.github.io/variplex/reference/vp_team_moves.md),
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
vp_team_links(band, teams)
#> # A tibble: 42 × 5
#>    from               from_team link     to              to_team
#>    <chr>              <chr>     <chr>    <chr>           <chr>  
#>  1 TouchScreen        display   requires HeartRateSensor sensors
#>  2 TouchScreen        display   requires BLEv42          radio  
#>  3 ContactlessPayment payments  requires Screen          display
#>  4 ContactlessPayment payments  requires TouchScreen     display
#>  5 ContactlessPayment payments  requires OLED            display
#>  6 ContactlessPayment payments  requires CapacityButton  display
#>  7 ContactlessPayment payments  requires HeartRateSensor sensors
#>  8 ContactlessPayment payments  requires BLEv42          radio  
#>  9 MovementFilter     sensors   requires Screen          display
#> 10 MovementFilter     sensors   requires OLED            display
#> # ℹ 32 more rows
```
