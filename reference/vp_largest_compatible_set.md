# The most features without a conflict among them

The largest set of features with no conflict among them. No product can
have more variable features selected than this. Exact for small models;
for large ones (more than `exact_limit` features) a quick greedy search
gives a set that is as large as it could find, so the true largest set
may be larger.

## Usage

``` r
vp_largest_compatible_set(model, exact_limit = 60)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- exact_limit:

  Up to this number of variable features the search is exact; above it,
  a greedy search is used.

## Value

A tibble with the column `feature`.

## See also

Other conflicts:
[`vp_alternative_groups()`](https://rheradio.github.io/variplex/reference/vp_alternative_groups.md),
[`vp_candidate_groups()`](https://rheradio.github.io/variplex/reference/vp_candidate_groups.md),
[`vp_colouring()`](https://rheradio.github.io/variplex/reference/vp_colouring.md),
[`vp_conflict_cover()`](https://rheradio.github.io/variplex/reference/vp_conflict_cover.md),
[`vp_explain_conflict()`](https://rheradio.github.io/variplex/reference/vp_explain_conflict.md),
[`vp_explain_requires()`](https://rheradio.github.io/variplex/reference/vp_explain_requires.md),
[`vp_opposites()`](https://rheradio.github.io/variplex/reference/vp_opposites.md),
[`vp_primitive_atleastone()`](https://rheradio.github.io/variplex/reference/vp_primitive_atleastone.md),
[`vp_primitive_conflicts()`](https://rheradio.github.io/variplex/reference/vp_primitive_conflicts.md),
[`vp_requires_from_conflicts()`](https://rheradio.github.io/variplex/reference/vp_requires_from_conflicts.md),
[`vp_twins()`](https://rheradio.github.io/variplex/reference/vp_twins.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_largest_compatible_set(band)
#> # A tibble: 8 × 1
#>   feature           
#>   <chr>             
#> 1 Screen            
#> 2 TouchScreen       
#> 3 OLED              
#> 4 CapacityButton    
#> 5 ContactlessPayment
#> 6 HeartRateSensor   
#> 7 BLEv42            
#> 8 NFC               
```
