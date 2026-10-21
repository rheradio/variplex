# Single decisions that split the model most, taken before the teams start

Single decisions that split the model most: for each candidate feature,
selected and left out, how many features the decision settles and the
size of the largest part left (vp_split_after()). The best decisions to
take first, together, before the teams start. Every variable feature can
be selected and can be left out, so each decision is possible.

## Usage

``` r
vp_splitting_decisions(model, candidates = NULL)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- candidates:

  The features to try; by default all of them up to 200 features, else
  the 50 with most links.

## Value

A tibble with `feature`, `decision` ("selected" or "left out"),
`decided`, `parts` and `largest_part`; the smallest largest part first.
Its attribute "largest_before" is the largest independent part with no
decision.

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
[`vp_team_links()`](https://rheradio.github.io/variplex/reference/vp_team_links.md),
[`vp_team_moves()`](https://rheradio.github.io/variplex/reference/vp_team_moves.md),
[`vp_team_order()`](https://rheradio.github.io/variplex/reference/vp_team_order.md),
[`vp_teams()`](https://rheradio.github.io/variplex/reference/vp_teams.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_splitting_decisions(band)
#> # A tibble: 22 × 5
#>    feature            decision decided parts largest_part
#>    <chr>              <chr>      <int> <int>        <int>
#>  1 ContactlessPayment selected      11     0            0
#>  2 MovementFilter     selected      11     0            0
#>  3 NFC                selected      11     0            0
#>  4 BT40               selected      10     1            1
#>  5 CapacityButton     left out      10     1            1
#>  6 OLED               left out      10     1            1
#>  7 Screen             left out      10     1            1
#>  8 BLEv40             selected       9     1            2
#>  9 TouchScreen        selected       9     1            2
#> 10 BLEv42             selected       8     1            3
#> # ℹ 12 more rows
```
