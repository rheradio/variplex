# Which combinations a sample misses

The combinations of two features that are possible but that the sample
does not have.

## Usage

``` r
vp_uncovered(model, sample)
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

A tibble with `feature_1`, `value_1`, `feature_2`, `value_2` (TRUE =
selected).

## See also

Other testing:
[`vp_combinations_to_cover()`](https://rheradio.github.io/variplex/reference/vp_combinations_to_cover.md),
[`vp_coverage()`](https://rheradio.github.io/variplex/reference/vp_coverage.md),
[`vp_min_sample_size()`](https://rheradio.github.io/variplex/reference/vp_min_sample_size.md),
[`vp_pick_sample()`](https://rheradio.github.io/variplex/reference/vp_pick_sample.md),
[`vp_sample_violations()`](https://rheradio.github.io/variplex/reference/vp_sample_violations.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
nodes <- with(vp_features(band), feature[status == "variable"])
sample <- as.data.frame(matrix(
  c(1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1),
  nrow = 2,
  dimnames = list(NULL, nodes)
))
head(vp_uncovered(band, sample))
#> # A tibble: 6 × 4
#>   feature_1 value_1 feature_2          value_2
#>   <chr>     <lgl>   <chr>              <lgl>  
#> 1 Screen    TRUE    TouchScreen        FALSE  
#> 2 Screen    FALSE   OLED               FALSE  
#> 3 Screen    TRUE    CapacityButton     TRUE   
#> 4 Screen    FALSE   CapacityButton     FALSE  
#> 5 Screen    TRUE    ContactlessPayment TRUE   
#> 6 Screen    FALSE   ContactlessPayment FALSE  
```
