# How much of them a sample covers

How much of the combinations to cover a sample covers.

## Usage

``` r
vp_coverage(model, sample)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- sample:

  One row per configuration, one 0/1 or logical column per variable
  feature.

## Value

One row per t (1 and 2): `t`, `covered`, `to_cover` and `coverage` (the
share). Combinations that the sample has but that are impossible are not
counted (see vp_sample_violations()).

## See also

Other testing:
[`vp_combinations_to_cover()`](https://rheradio.github.io/variplex/reference/vp_combinations_to_cover.md),
[`vp_min_sample_size()`](https://rheradio.github.io/variplex/reference/vp_min_sample_size.md),
[`vp_pick_sample()`](https://rheradio.github.io/variplex/reference/vp_pick_sample.md),
[`vp_sample_violations()`](https://rheradio.github.io/variplex/reference/vp_sample_violations.md),
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
vp_coverage(band, sample)
#> # A tibble: 2 × 4
#>       t covered to_cover coverage
#>   <int>   <int>    <dbl>    <dbl>
#> 1     1      21       22    0.955
#> 2     2      84      163    0.515
```
