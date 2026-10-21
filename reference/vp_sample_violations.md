# Configurations of a sample that break a link

Configurations of a sample that break a link of the graphs. Such a
configuration is not valid (or the graphs are wrong). A configuration
that breaks no link can still be invalid, because of a rule over three
or more features.

## Usage

``` r
vp_sample_violations(model, sample)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- sample:

  A sample of configurations: a data frame with one row per
  configuration and one column per variable feature, holding 0/1 or
  `FALSE`/`TRUE` (other columns are ignored).

## Value

A tibble with `configuration` (the row number), `rule` and `features`.

## See also

Other testing:
[`vp_combinations_to_cover()`](https://rheradio.github.io/variplex/reference/vp_combinations_to_cover.md),
[`vp_coverage()`](https://rheradio.github.io/variplex/reference/vp_coverage.md),
[`vp_min_sample_size()`](https://rheradio.github.io/variplex/reference/vp_min_sample_size.md),
[`vp_pick_sample()`](https://rheradio.github.io/variplex/reference/vp_pick_sample.md),
[`vp_uncovered()`](https://rheradio.github.io/variplex/reference/vp_uncovered.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
nodes <- with(vp_features(band), feature[status == "variable"])
sample <- as.data.frame(matrix(
  c(1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1),
  nrow = 2,
  dimnames = list(NULL, nodes)
))
vp_sample_violations(band, sample)
#> # A tibble: 26 × 3
#>    configuration rule     features                     
#>            <int> <chr>    <chr>                        
#>  1             1 requires Screen -> CapacityButton     
#>  2             1 requires TouchScreen -> CapacityButton
#>  3             1 requires TouchScreen -> BLEv42        
#>  4             1 requires OLED -> CapacityButton       
#>  5             1 excludes Screen -- BT40               
#>  6             1 excludes TouchScreen -- BT40          
#>  7             1 excludes OLED -- BT40                 
#>  8             2 requires OLED -> Screen               
#>  9             2 requires CapacityButton -> Screen     
#> 10             2 requires ContactlessPayment -> Screen 
#> # ℹ 16 more rows
```
