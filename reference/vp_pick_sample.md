# A small covering sample chosen from given configurations

A small sample that covers every combination, chosen from configurations
that you already have (for example, all the valid configurations of a
small model, or the output of a sampling tool). It picks, again and
again, the configuration that covers most of what is still uncovered.
The result is small but not always the smallest.

## Usage

``` r
vp_pick_sample(model, pool, t = 2)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- pool:

  Candidate configurations, in the format of a sample. They should be
  valid.

- t:

  1 or 2.

## Value

The rows of `pool` that were picked, in the order they were picked, with
a column `newly_covered`.

## See also

Other testing:
[`vp_combinations_to_cover()`](https://rheradio.github.io/variplex/reference/vp_combinations_to_cover.md),
[`vp_coverage()`](https://rheradio.github.io/variplex/reference/vp_coverage.md),
[`vp_min_sample_size()`](https://rheradio.github.io/variplex/reference/vp_min_sample_size.md),
[`vp_sample_violations()`](https://rheradio.github.io/variplex/reference/vp_sample_violations.md),
[`vp_uncovered()`](https://rheradio.github.io/variplex/reference/vp_uncovered.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
nodes <- with(vp_features(band), feature[status == "variable"])
# every selection of the variable features that breaks no link of the graphs
pool <- expand.grid(rep(list(0:1), length(nodes)))
names(pool) <- nodes
bad <- unique(vp_sample_violations(band, pool)$configuration)
pool <- pool[-bad, ]
vp_pick_sample(band, pool, t = 2)
#> # A tibble: 8 × 12
#>   Screen TouchScreen  OLED CapacityButton ContactlessPayment MovementFilter
#>    <int>       <int> <int>          <int>              <int>          <int>
#> 1      1           0     1              1                  0              0
#> 2      0           0     0              0                  0              0
#> 3      1           1     1              1                  1              0
#> 4      1           0     1              1                  0              1
#> 5      1           1     1              1                  0              0
#> 6      0           0     0              0                  0              0
#> 7      1           0     1              1                  0              0
#> 8      1           0     1              1                  0              0
#> # ℹ 6 more variables: HeartRateSensor <int>, BLEv40 <int>, BLEv42 <int>,
#> #   BT40 <int>, NFC <int>, newly_covered <int>
```
