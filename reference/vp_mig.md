# The modal implication graph: every implication between two decisions

The modal implication graph (MIG): every implication between two
decisions ("f selected" or "f left out") that the graphs give. It is the
form of the graphs best suited to reasoning (the implication graph of
the SAT literature; the modal implication graph of Krieter et al.,
restricted to what always holds): following its arrows from some
decisions gives everything they force, which is what vp_consequences()
does.

## Usage

``` r
vp_mig(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with `from`, `from_selected`, `to`, `to_selected` and `because`
("requires", "excludes" or "atleastone"): deciding `from` as
`from_selected` forces `to` to be `to_selected`.

## Details

It reads the graphs it is given. On the complete graphs every
implication is one arrow; on the minimal form
(vp_mig(vp_minimal(model))) it is the compact MIG: far fewer arrows, and
following them still reaches every implication (a conflict is inherited
through the contrapositive of a requirement, an at-least-one line
through requirements), with one node per atomic set. The compact one is
the one to draw: vp_plot() draws a MIG directly, with nodes "A" and "not
A" and each arrow in the colour of the link it comes from.

## See also

Other configuration:
[`vp_can_go_together()`](https://rheradio.github.io/variplex/reference/vp_can_go_together.md),
[`vp_consequences()`](https://rheradio.github.io/variplex/reference/vp_consequences.md),
[`vp_count_graph_products()`](https://rheradio.github.io/variplex/reference/vp_count_graph_products.md),
[`vp_kernel()`](https://rheradio.github.io/variplex/reference/vp_kernel.md),
[`vp_kernel_links()`](https://rheradio.github.io/variplex/reference/vp_kernel_links.md),
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
vp_mig(vp_minimal(band))
#> # A tibble: 20 × 5
#>    from               from_selected to                 to_selected because   
#>    <chr>              <lgl>         <chr>              <lgl>       <chr>     
#>  1 TouchScreen        TRUE          BLEv42             TRUE        requires  
#>  2 ContactlessPayment TRUE          TouchScreen        TRUE        requires  
#>  3 MovementFilter     TRUE          BLEv40             TRUE        requires  
#>  4 BLEv40             TRUE          Screen             TRUE        requires  
#>  5 BLEv42             TRUE          Screen             TRUE        requires  
#>  6 BLEv42             TRUE          HeartRateSensor    TRUE        requires  
#>  7 BLEv42             FALSE         TouchScreen        FALSE       requires  
#>  8 TouchScreen        FALSE         ContactlessPayment FALSE       requires  
#>  9 BLEv40             FALSE         MovementFilter     FALSE       requires  
#> 10 Screen             FALSE         BLEv40             FALSE       requires  
#> 11 Screen             FALSE         BLEv42             FALSE       requires  
#> 12 HeartRateSensor    FALSE         BLEv42             FALSE       requires  
#> 13 Screen             TRUE          BT40               FALSE       excludes  
#> 14 MovementFilter     TRUE          HeartRateSensor    FALSE       excludes  
#> 15 BLEv40             TRUE          BLEv42             FALSE       excludes  
#> 16 BT40               TRUE          Screen             FALSE       excludes  
#> 17 HeartRateSensor    TRUE          MovementFilter     FALSE       excludes  
#> 18 BLEv42             TRUE          BLEv40             FALSE       excludes  
#> 19 Screen             FALSE         BT40               TRUE        atleastone
#> 20 BT40               FALSE         Screen             TRUE        atleastone
```
