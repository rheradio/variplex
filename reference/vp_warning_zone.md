# Features both highly required and highly dependent

The warning zone: features that are among the most required and, at the
same time, among those that require most. Many things break when they
change, and many things can break them.

## Usage

``` r
vp_warning_zone(model, top = 0.1)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- top:

  The share of features that counts as "among the most" (0.1: the top
  tenth).

## Value

The rows of vp_feature_table() of the features in the zone.

## See also

Other features:
[`vp_atleastone_of()`](https://rheradio.github.io/variplex/reference/vp_atleastone_of.md),
[`vp_conflicts_of()`](https://rheradio.github.io/variplex/reference/vp_conflicts_of.md),
[`vp_feature_table()`](https://rheradio.github.io/variplex/reference/vp_feature_table.md),
[`vp_genuine_hubs()`](https://rheradio.github.io/variplex/reference/vp_genuine_hubs.md),
[`vp_required_by()`](https://rheradio.github.io/variplex/reference/vp_required_by.md),
[`vp_requirements()`](https://rheradio.github.io/variplex/reference/vp_requirements.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_warning_zone(band, top = 0.3)
#> # A tibble: 0 × 16
#> # ℹ 16 variables: feature <chr>, required_by <int>, requires <int>,
#> #   excludes <int>, atleastone <int>, decision_power <dbl>,
#> #   decision_power_off <dbl>, level <int>, direct_required_by <int>,
#> #   direct_requires <int>, betweenness <dbl>, closeness_out <dbl>,
#> #   closeness_in <dbl>, harmonic <dbl>, atomic_set <chr>, isolated <lgl>
```
