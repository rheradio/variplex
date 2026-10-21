# The kernel: a small map for 'can these go together?'

The kernel: the features grouped into classes that behave alike for the
question "can these be together?". The class of the trouble-free
features (they exclude nothing, by themselves or through what they
bring) is marked. The same as the file \_\_kernel_classes.txt of
Strong4VM (vp_generate(kernel = TRUE)).

## Usage

``` r
vp_kernel(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with `class` (a number), `label` (the first feature of the
class), `feature` and `trouble_free`.

## See also

Other configuration:
[`vp_can_go_together()`](https://rheradio.github.io/variplex/reference/vp_can_go_together.md),
[`vp_consequences()`](https://rheradio.github.io/variplex/reference/vp_consequences.md),
[`vp_count_graph_products()`](https://rheradio.github.io/variplex/reference/vp_count_graph_products.md),
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
band <- vp_generate(vp_example("miband3.uvl"))
vp_kernel(band)
#> # A tibble: 11 × 4
#>    class label              feature            trouble_free
#>    <int> <chr>              <chr>              <lgl>       
#>  1     1 Screen             Screen             FALSE       
#>  2     1 Screen             OLED               FALSE       
#>  3     1 Screen             CapacityButton     FALSE       
#>  4     2 TouchScreen        TouchScreen        FALSE       
#>  5     3 ContactlessPayment ContactlessPayment FALSE       
#>  6     3 ContactlessPayment NFC                FALSE       
#>  7     4 MovementFilter     MovementFilter     FALSE       
#>  8     5 HeartRateSensor    HeartRateSensor    FALSE       
#>  9     6 BLEv40             BLEv40             FALSE       
#> 10     7 BLEv42             BLEv42             FALSE       
#> 11     8 BT40               BT40               FALSE       
```
