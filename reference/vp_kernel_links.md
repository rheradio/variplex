# The arrows and red lines of the kernel

The links of the kernel between its classes: "requires" (a class brings
another along) and "excludes" (a root conflict). The same as
\_\_kernel_requires.net and \_\_kernel_excludes.net.

## Usage

``` r
vp_kernel_links(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with `from`, `link` and `to` (class labels).

## See also

Other configuration:
[`vp_can_go_together()`](https://rheradio.github.io/variplex/reference/vp_can_go_together.md),
[`vp_consequences()`](https://rheradio.github.io/variplex/reference/vp_consequences.md),
[`vp_count_graph_products()`](https://rheradio.github.io/variplex/reference/vp_count_graph_products.md),
[`vp_kernel()`](https://rheradio.github.io/variplex/reference/vp_kernel.md),
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
band <- vp_generate(vp_example("miband3.uvl"))
vp_kernel_links(band)
#> # A tibble: 15 × 3
#>    from               link     to             
#>    <chr>              <chr>    <chr>          
#>  1 TouchScreen        requires Screen         
#>  2 TouchScreen        requires HeartRateSensor
#>  3 TouchScreen        requires BLEv42         
#>  4 ContactlessPayment requires Screen         
#>  5 ContactlessPayment requires TouchScreen    
#>  6 ContactlessPayment requires HeartRateSensor
#>  7 ContactlessPayment requires BLEv42         
#>  8 MovementFilter     requires Screen         
#>  9 MovementFilter     requires BLEv40         
#> 10 BLEv40             requires Screen         
#> 11 BLEv42             requires Screen         
#> 12 BLEv42             requires HeartRateSensor
#> 13 Screen             excludes BT40           
#> 14 MovementFilter     excludes HeartRateSensor
#> 15 BLEv40             excludes BLEv42         
```
