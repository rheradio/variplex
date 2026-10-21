# Is this mix of selected and left-out features possible?

Is a mix of decisions possible: some features selected and others left
out? The graphs say what each decision forces; the mix is impossible
when it forces a feature both in and out.

## Usage

``` r
vp_partial_configuration(
  model,
  selected = character(0),
  deselected = character(0)
)
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

A list with `possible` (TRUE or FALSE) and `explanation`: a tibble with
one row per feature that the decisions force both in and out, with
`feature`, `in_because` and `out_because` (the decision that forces it
in, and out: "your choice" when it is one of the decisions given, else
the decision that forces it, "A" for "A selected" and "not A" for "A
left out") and `reason` (the same, as a sentence). No rows when the mix
is possible.

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
vp_partial_configuration(
  band,
  selected = "TouchScreen",
  deselected = "HeartRateSensor"
)
#> $possible
#> [1] FALSE
#> 
#> $explanation
#> # A tibble: 3 × 4
#>   feature         in_because  out_because         reason                        
#>   <chr>           <chr>       <chr>               <chr>                         
#> 1 TouchScreen     your choice not HeartRateSensor TouchScreen would be both in …
#> 2 HeartRateSensor TouchScreen your choice         HeartRateSensor would be both…
#> 3 BLEv42          TouchScreen not HeartRateSensor BLEv42 would be both in (forc…
#> 
```
