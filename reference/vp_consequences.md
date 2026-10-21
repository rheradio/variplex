# What some decisions force

What some decisions force. Selecting a feature selects what it requires
and leaves out what it excludes; leaving a feature out leaves out what
requires it and selects what it is joined to in the at-least-one graph.

## Usage

``` r
vp_consequences(model, selected = character(0), deselected = character(0))
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- selected:

  Features that the product must have.

- deselected:

  Features that the product must not have.

## Value

A tibble with `feature`, `value` ("selected" or "left out") and
`forced_by` (the decision that forces it, written as "A" for "A
selected" and "not A" for "A left out"; a decision you gave is forced by
itself).

## See also

Other configuration:
[`vp_can_go_together()`](https://rheradio.github.io/variplex/reference/vp_can_go_together.md),
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
[`vp_team_order()`](https://rheradio.github.io/variplex/reference/vp_team_order.md),
[`vp_teams()`](https://rheradio.github.io/variplex/reference/vp_teams.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_consequences(band, selected = "TouchScreen")
#> # A tibble: 9 × 3
#>   feature         value    forced_by  
#>   <chr>           <chr>    <chr>      
#> 1 TouchScreen     selected TouchScreen
#> 2 Screen          selected TouchScreen
#> 3 OLED            selected TouchScreen
#> 4 CapacityButton  selected TouchScreen
#> 5 HeartRateSensor selected TouchScreen
#> 6 BLEv42          selected TouchScreen
#> 7 MovementFilter  left out TouchScreen
#> 8 BLEv40          left out TouchScreen
#> 9 BT40            left out TouchScreen
```
