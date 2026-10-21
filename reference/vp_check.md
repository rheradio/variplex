# Are the files consistent?

Check that the files are consistent: the properties that the graphs of
any model must have. A FALSE means that the files are incomplete or were
damaged (for example, filtered by hand in one graph and not in the
other).

## Usage

``` r
vp_check(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with one row per property: `property`, `holds` (TRUE/FALSE) and
`violations` (how many cases break it).

## See also

Other whole model:
[`vp_degree_distribution()`](https://rheradio.github.io/variplex/reference/vp_degree_distribution.md),
[`vp_gini()`](https://rheradio.github.io/variplex/reference/vp_gini.md),
[`vp_summary()`](https://rheradio.github.io/variplex/reference/vp_summary.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_check(band)
#> # A tibble: 6 × 3
#>   property                                                      holds violations
#>   <chr>                                                         <lgl>      <int>
#> 1 requires is complete: A -> B and B -> C give A -> C           TRUE           0
#> 2 conflicts are inherited: A -> B and B excludes C give A excl… TRUE           0
#> 3 no feature requires two features that exclude each other      TRUE           0
#> 4 no pair both requires and excludes                            TRUE           0
#> 5 at-least-one is inherited upwards: A or B, and B -> C give A… TRUE           0
#> 6 A excludes B and (B or C) give A -> C                         TRUE           0
```
