# How unevenly a quantity is spread

The Gini coefficient of a vector of numbers: 0 when all are equal, close
to 1 when one holds almost everything.

## Usage

``` r
vp_gini(x)
```

## Arguments

- x:

  A numeric vector.

## Value

A number between 0 and 1.

## See also

Other whole model:
[`vp_check()`](https://rheradio.github.io/variplex/reference/vp_check.md),
[`vp_degree_distribution()`](https://rheradio.github.io/variplex/reference/vp_degree_distribution.md),
[`vp_summary()`](https://rheradio.github.io/variplex/reference/vp_summary.md)

## Examples

``` r
vp_gini(c(1, 1, 1, 1))
#> [1] 0
vp_gini(c(0, 0, 0, 10))
#> [1] 0.75
```
