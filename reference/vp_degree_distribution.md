# How many features have each degree

How many features have each degree in one graph: the data of a
degree-distribution plot.

## Usage

``` r
vp_degree_distribution(
  model,
  graph = c("requires", "excludes", "atleastone", "skeleton"),
  direction = c("in", "out")
)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- graph:

  "requires", "excludes", "atleastone" or "skeleton".

- direction:

  For requires and skeleton: "in" (how many require the feature) or
  "out" (how many it requires).

## Value

A tibble with `degree` and `features` (how many features have that
degree).

## See also

Other whole model:
[`vp_check()`](https://rheradio.github.io/variplex/reference/vp_check.md),
[`vp_gini()`](https://rheradio.github.io/variplex/reference/vp_gini.md),
[`vp_summary()`](https://rheradio.github.io/variplex/reference/vp_summary.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_degree_distribution(band, "requires", "in")
#> # A tibble: 6 × 2
#>   degree features
#>    <int>    <int>
#> 1      0        2
#> 2      1        3
#> 3      2        1
#> 4      3        1
#> 5      4        1
#> 6      8        3
```
