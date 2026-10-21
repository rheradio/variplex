# Why one feature requires another

Why does a feature require another? The first route is a chain of arrows
of the skeleton. When the run has the at-least-one graph, further routes
may appear: a excludes g, and every product has g or b, so a product
with a has b.

## Usage

``` r
vp_explain_requires(model, a, b, max_routes = 3)
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

- max_routes:

  How many routes of the second kind to show at most.

## Value

A tibble like that of vp_explain_conflict(), with `route` instead of
`origin`; the link "atleastone" means "every product has from or to".

## See also

Other conflicts:
[`vp_alternative_groups()`](https://rheradio.github.io/variplex/reference/vp_alternative_groups.md),
[`vp_candidate_groups()`](https://rheradio.github.io/variplex/reference/vp_candidate_groups.md),
[`vp_colouring()`](https://rheradio.github.io/variplex/reference/vp_colouring.md),
[`vp_conflict_cover()`](https://rheradio.github.io/variplex/reference/vp_conflict_cover.md),
[`vp_explain_conflict()`](https://rheradio.github.io/variplex/reference/vp_explain_conflict.md),
[`vp_largest_compatible_set()`](https://rheradio.github.io/variplex/reference/vp_largest_compatible_set.md),
[`vp_opposites()`](https://rheradio.github.io/variplex/reference/vp_opposites.md),
[`vp_primitive_atleastone()`](https://rheradio.github.io/variplex/reference/vp_primitive_atleastone.md),
[`vp_primitive_conflicts()`](https://rheradio.github.io/variplex/reference/vp_primitive_conflicts.md),
[`vp_requires_from_conflicts()`](https://rheradio.github.io/variplex/reference/vp_requires_from_conflicts.md),
[`vp_twins()`](https://rheradio.github.io/variplex/reference/vp_twins.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_explain_requires(band, "TouchScreen", "OLED")
#> # A tibble: 5 × 5
#>   route  step from        link       to    
#>   <int> <int> <chr>       <chr>      <chr> 
#> 1     1     1 TouchScreen requires   BLEv42
#> 2     1     2 BLEv42      requires   Screen
#> 3     1     3 Screen      requires   OLED  
#> 4     2     1 TouchScreen excludes   BT40  
#> 5     2     2 BT40        atleastone OLED  
```
