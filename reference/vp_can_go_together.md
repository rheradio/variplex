# Can these features be in one product? (a wish list)

Can these features be selected together in one product? (A wish list, or
partial configuration that only selects.)

## Usage

``` r
vp_can_go_together(model, wishes)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- wishes:

  A character vector of features, or a list of such vectors to check
  several wish lists at once.

## Value

A tibble with one row per wish list: `wish`, `possible` (FALSE:
certainly not; TRUE: no two features stand in each other's way, which a
rule over three or more features can still contradict) and `reasons`
(the root conflicts that forbid it, separated by ";").

## See also

Other configuration:
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
[`vp_team_order()`](https://rheradio.github.io/variplex/reference/vp_team_order.md),
[`vp_teams()`](https://rheradio.github.io/variplex/reference/vp_teams.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_can_go_together(band, c("TouchScreen", "HeartRateSensor"))
#> # A tibble: 1 × 3
#>   wish                         possible reasons
#>   <chr>                        <lgl>    <chr>  
#> 1 TouchScreen, HeartRateSensor TRUE     ""     
vp_can_go_together(band, list(c("Screen", "BT40"), c("Screen", "NFC")))
#> # A tibble: 2 × 3
#>   wish         possible reasons               
#>   <chr>        <lgl>    <chr>                 
#> 1 Screen, BT40 FALSE    "Screen excludes BT40"
#> 2 Screen, NFC  TRUE     ""                    
```
