# Groups of any features that all exclude each other (at most one per product)

Groups of features that all exclude one another (cliques of the excludes
graph): at most one of each group can be in a product. They are groups
of alternatives, whether or not the model declares them as such.

## Usage

``` r
vp_alternative_groups(model, min_size = 3)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- min_size:

  The smallest group to report (3 by default; every conflict is a group
  of 2).

## Value

A tibble with `group`, `size` and `feature`, the largest groups first.

## See also

Other conflicts:
[`vp_candidate_groups()`](https://rheradio.github.io/variplex/reference/vp_candidate_groups.md),
[`vp_colouring()`](https://rheradio.github.io/variplex/reference/vp_colouring.md),
[`vp_conflict_cover()`](https://rheradio.github.io/variplex/reference/vp_conflict_cover.md),
[`vp_explain_conflict()`](https://rheradio.github.io/variplex/reference/vp_explain_conflict.md),
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
vp_alternative_groups(band)
#> # A tibble: 24 × 3
#>    group  size feature           
#>    <int> <int> <chr>             
#>  1     1     3 BLEv40            
#>  2     1     3 BT40              
#>  3     1     3 TouchScreen       
#>  4     2     3 BLEv40            
#>  5     2     3 BT40              
#>  6     2     3 ContactlessPayment
#>  7     3     3 BLEv40            
#>  8     3     3 BT40              
#>  9     3     3 BLEv42            
#> 10     4     3 BLEv40            
#> # ℹ 14 more rows
```
