# Why two features exclude each other

Why do two features exclude each other? The answer is a chain: the first
feature requires some feature x, the second requires some feature y, and
x and y have a primitive conflict. When several primitive conflicts can
explain it, each one is an `origin` of its own (all of them must be
removed for the conflict to disappear).

## Usage

``` r
vp_explain_conflict(model, a, b)
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

A tibble with one row per link: `origin`, `step`, `from`, `link`
("requires" or "excludes") and `to`. No rows if the two features do not
exclude each other.

## See also

Other conflicts:
[`vp_alternative_groups()`](https://rheradio.github.io/variplex/reference/vp_alternative_groups.md),
[`vp_candidate_groups()`](https://rheradio.github.io/variplex/reference/vp_candidate_groups.md),
[`vp_colouring()`](https://rheradio.github.io/variplex/reference/vp_colouring.md),
[`vp_conflict_cover()`](https://rheradio.github.io/variplex/reference/vp_conflict_cover.md),
[`vp_explain_requires()`](https://rheradio.github.io/variplex/reference/vp_explain_requires.md),
[`vp_largest_compatible_set()`](https://rheradio.github.io/variplex/reference/vp_largest_compatible_set.md),
[`vp_opposites()`](https://rheradio.github.io/variplex/reference/vp_opposites.md),
[`vp_primitive_atleastone()`](https://rheradio.github.io/variplex/reference/vp_primitive_atleastone.md),
[`vp_primitive_conflicts()`](https://rheradio.github.io/variplex/reference/vp_primitive_conflicts.md),
[`vp_requires_from_conflicts()`](https://rheradio.github.io/variplex/reference/vp_requires_from_conflicts.md),
[`vp_twins()`](https://rheradio.github.io/variplex/reference/vp_twins.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_explain_conflict(band, "TouchScreen", "BT40")
#> # A tibble: 3 × 5
#>   origin  step from        link     to    
#>    <int> <int> <chr>       <chr>    <chr> 
#> 1      1     1 TouchScreen requires BLEv42
#> 2      1     2 BLEv42      requires Screen
#> 3      1     3 Screen      excludes BT40  
```
