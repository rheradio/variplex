# One row of numbers per model

One row of numbers that describe a model. Give one model, or several
(they are stacked, one row each).

## Usage

``` r
vp_summary(...)
```

## Arguments

- ...:

  One or more models (from vp_read). Named arguments give the column
  `model` its values.

## Value

A tibble with one row per model and the columns model, features
(variable), core, dead, atomic_sets, requires, excludes, atleastone (NA
without or_graph = TRUE), skeleton (arrows), primitive_conflicts,
implicit_requires (share of arrows that follow from others),
implicit_excludes (share of conflicts that are inherited),
density_requires, density_excludes, depth, width, cross_tree_share,
hierarchy_share, gini_required_by, gini_excludes, mean_decision_power,
isolated (features in no graph), coupling (share of features with at
least one strong relationship), skeleton_per_feature (links of the
skeleton per node: density by meaning), largest_atomic_set (the size of
the largest group of mutually dependent features, Baldwin et al.'s
"core"), largest_alternative_group, representativeness (the share of
vp_representativeness(), NA when the run did not measure it).

## Details

The counts, densities, concentrations, isolated and coupling read the
graphs as they are given (on the minimal form, vp_minimal(), they
describe the written structure); the other numbers are inferences and
use the complete graphs.

## See also

Other whole model:
[`vp_check()`](https://rheradio.github.io/variplex/reference/vp_check.md),
[`vp_degree_distribution()`](https://rheradio.github.io/variplex/reference/vp_degree_distribution.md),
[`vp_gini()`](https://rheradio.github.io/variplex/reference/vp_gini.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"))
axtls <- vp_generate(vp_example("axTLS.uvl"))
vp_summary(band = band, axTLS = axtls)
#> # A tibble: 2 × 28
#>   model form     features  core  dead atomic_sets requires excludes atleastone
#>   <chr> <chr>       <int> <int> <int>       <int>    <int>    <int>      <int>
#> 1 band  complete       11     8     0           2       36       18         NA
#> 2 axTLS complete       61    19    11           7       56       13         NA
#> # ℹ 19 more variables: skeleton <int>, primitive_conflicts <int>,
#> #   implicit_requires <dbl>, implicit_excludes <dbl>, density_requires <dbl>,
#> #   density_excludes <dbl>, depth <int>, width <int>, cross_tree_share <dbl>,
#> #   hierarchy_share <dbl>, gini_required_by <dbl>, gini_excludes <dbl>,
#> #   mean_decision_power <dbl>, isolated <int>, coupling <dbl>,
#> #   skeleton_per_feature <dbl>, largest_atomic_set <int>,
#> #   largest_alternative_group <dbl>, representativeness <dbl>
```
