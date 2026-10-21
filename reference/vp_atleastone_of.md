# What leaving a feature out forces

The features joined to a given feature in the at-least-one graph:
leaving it out forces all of them in.

## Usage

``` r
vp_atleastone_of(model, feature)
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
[`vp_conflicts_of()`](https://rheradio.github.io/variplex/reference/vp_conflicts_of.md),
[`vp_feature_table()`](https://rheradio.github.io/variplex/reference/vp_feature_table.md),
[`vp_genuine_hubs()`](https://rheradio.github.io/variplex/reference/vp_genuine_hubs.md),
[`vp_required_by()`](https://rheradio.github.io/variplex/reference/vp_required_by.md),
[`vp_requirements()`](https://rheradio.github.io/variplex/reference/vp_requirements.md),
[`vp_warning_zone()`](https://rheradio.github.io/variplex/reference/vp_warning_zone.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_atleastone_of(band, "BT40")
#> # A tibble: 3 × 1
#>   feature       
#>   <chr>         
#> 1 Screen        
#> 2 OLED          
#> 3 CapacityButton
```
