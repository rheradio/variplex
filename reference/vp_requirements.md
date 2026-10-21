# What a feature requires

The features that a given feature requires: selecting it selects all of
them.

## Usage

``` r
vp_requirements(model, feature)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- feature:

  The name of a variable feature of the model.

## Value

A tibble with the column `feature`.

## See also

Other features:
[`vp_atleastone_of()`](https://rheradio.github.io/variplex/reference/vp_atleastone_of.md),
[`vp_conflicts_of()`](https://rheradio.github.io/variplex/reference/vp_conflicts_of.md),
[`vp_feature_table()`](https://rheradio.github.io/variplex/reference/vp_feature_table.md),
[`vp_genuine_hubs()`](https://rheradio.github.io/variplex/reference/vp_genuine_hubs.md),
[`vp_required_by()`](https://rheradio.github.io/variplex/reference/vp_required_by.md),
[`vp_warning_zone()`](https://rheradio.github.io/variplex/reference/vp_warning_zone.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_requirements(band, "TouchScreen")
#> # A tibble: 5 × 1
#>   feature        
#>   <chr>          
#> 1 Screen         
#> 2 OLED           
#> 3 CapacityButton 
#> 4 HeartRateSensor
#> 5 BLEv42         
```
