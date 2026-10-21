# The four combinations of two features: which are possible

Everything the graphs say about two features: which of the four
combinations (both, only the first, only the second, neither) can occur
in a valid product. For two features the answer is exact.

## Usage

``` r
vp_pair(model, a, b)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- a:

  The name of a variable feature of the model.

- b:

  The name of another variable feature of the model.

## Value

A tibble with four rows: `combination`, `a`, `b` (TRUE = selected),
`possible` and `ruled_out_by`. Without the at-least-one graph, the row
"neither" has `possible` NA.

## See also

Other configuration:
[`vp_can_go_together()`](https://rheradio.github.io/variplex/reference/vp_can_go_together.md),
[`vp_consequences()`](https://rheradio.github.io/variplex/reference/vp_consequences.md),
[`vp_count_graph_products()`](https://rheradio.github.io/variplex/reference/vp_count_graph_products.md),
[`vp_kernel()`](https://rheradio.github.io/variplex/reference/vp_kernel.md),
[`vp_kernel_links()`](https://rheradio.github.io/variplex/reference/vp_kernel_links.md),
[`vp_mig()`](https://rheradio.github.io/variplex/reference/vp_mig.md),
[`vp_most_decisive()`](https://rheradio.github.io/variplex/reference/vp_most_decisive.md),
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
vp_pair(band, "BLEv40", "BT40")
#> # A tibble: 4 × 5
#>   combination a     b     possible ruled_out_by          
#>   <chr>       <lgl> <lgl> <lgl>    <chr>                 
#> 1 both        TRUE  TRUE  FALSE    "BLEv40 excludes BT40"
#> 2 only BLEv40 TRUE  FALSE TRUE     ""                    
#> 3 only BT40   FALSE TRUE  TRUE     ""                    
#> 4 neither     FALSE FALSE TRUE     ""                    
```
