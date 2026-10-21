# A lower bound on the size of any covering sample

A lower bound on the size of any t-wise sample: no sample that covers
every combination can have fewer configurations. The bound is the size
of the largest set of things to cover that are incompatible two by two
(no configuration can contain two of them).

## Usage

``` r
vp_min_sample_size(model, t = 1, max_features = 40, exact = NULL)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- t:

  1 or 2. For t = 2 the model must be small (the graph of pairs has
  about 2 n^2 nodes); `max_features`.

- max_features:

  For t = 2, the largest number of variable features accepted.

- exact:

  TRUE searches the largest such set exactly; FALSE uses a quick greedy
  search, whose bound is still valid but may be lower. By default
  (NULL): exact for t = 1, which is fast on the sparse graphs of real
  models, and for t = 2 only when the graph of pairs has at most 250
  nodes (about 11 features), because there the exact search can take
  hours.

## Value

A list-free tibble: one row per member of the incompatible set, with
`t`, `bound` (the size) and `item` (a decision such as "A" or "not A"
for t = 1; a pair of decisions for t = 2).

## See also

Other testing:
[`vp_combinations_to_cover()`](https://rheradio.github.io/variplex/reference/vp_combinations_to_cover.md),
[`vp_coverage()`](https://rheradio.github.io/variplex/reference/vp_coverage.md),
[`vp_pick_sample()`](https://rheradio.github.io/variplex/reference/vp_pick_sample.md),
[`vp_sample_violations()`](https://rheradio.github.io/variplex/reference/vp_sample_violations.md),
[`vp_uncovered()`](https://rheradio.github.io/variplex/reference/vp_uncovered.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_min_sample_size(band, t = 1)
#> # A tibble: 3 × 3
#>       t bound item       
#>   <int> <int> <chr>      
#> 1     1     3 not Screen 
#> 2     1     3 BLEv40     
#> 3     1     3 TouchScreen
```
