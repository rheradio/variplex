# Features that behave identically

Twins: features with exactly the same requirements, dependants and
conflicts (and at-least-one links). For the graphs they are
interchangeable. "alternatives" exclude each other; "extras" do not.

## Usage

``` r
vp_twins(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with `group`, `kind` and `feature`.

## See also

Other conflicts:
[`vp_alternative_groups()`](https://rheradio.github.io/variplex/reference/vp_alternative_groups.md),
[`vp_candidate_groups()`](https://rheradio.github.io/variplex/reference/vp_candidate_groups.md),
[`vp_colouring()`](https://rheradio.github.io/variplex/reference/vp_colouring.md),
[`vp_conflict_cover()`](https://rheradio.github.io/variplex/reference/vp_conflict_cover.md),
[`vp_explain_conflict()`](https://rheradio.github.io/variplex/reference/vp_explain_conflict.md),
[`vp_explain_requires()`](https://rheradio.github.io/variplex/reference/vp_explain_requires.md),
[`vp_largest_compatible_set()`](https://rheradio.github.io/variplex/reference/vp_largest_compatible_set.md),
[`vp_opposites()`](https://rheradio.github.io/variplex/reference/vp_opposites.md),
[`vp_primitive_atleastone()`](https://rheradio.github.io/variplex/reference/vp_primitive_atleastone.md),
[`vp_primitive_conflicts()`](https://rheradio.github.io/variplex/reference/vp_primitive_conflicts.md),
[`vp_requires_from_conflicts()`](https://rheradio.github.io/variplex/reference/vp_requires_from_conflicts.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_twins(band)
#> # A tibble: 0 × 3
#> # ℹ 3 variables: group <int>, kind <chr>, feature <chr>
```
