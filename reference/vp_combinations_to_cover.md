# How many combinations a t-wise sample must cover

How many combinations of values a t-wise sample must cover.

## Usage

``` r
vp_combinations_to_cover(model, t = 2)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- t:

  1 (every feature selected and left out) or 2 (every valid combination
  of two features).

## Value

One row: `t`, `combinations` and `exact` (FALSE for t = 2 without the
at-least-one graph: then the count is an upper limit, because some
"neither" combinations may be impossible).

## See also

Other testing:
[`vp_coverage()`](https://rheradio.github.io/variplex/reference/vp_coverage.md),
[`vp_min_sample_size()`](https://rheradio.github.io/variplex/reference/vp_min_sample_size.md),
[`vp_pick_sample()`](https://rheradio.github.io/variplex/reference/vp_pick_sample.md),
[`vp_sample_violations()`](https://rheradio.github.io/variplex/reference/vp_sample_violations.md),
[`vp_uncovered()`](https://rheradio.github.io/variplex/reference/vp_uncovered.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_combinations_to_cover(band, t = 1)
#> # A tibble: 1 × 3
#>       t combinations exact
#>   <int>        <dbl> <lgl>
#> 1     1           22 TRUE 
vp_combinations_to_cover(band, t = 2)
#> # A tibble: 1 × 3
#>       t combinations exact
#>   <int>        <dbl> <lgl>
#> 1     2          163 TRUE 
```
