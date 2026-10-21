# Mutually exclusive children of one parent: the alternative groups a feature model would declare

Candidate alternative groups: for each feature, its direct dependants
(in the skeleton) that exclude one another. In a feature model this is
the shape of an alternative group under a common parent, so the result
suggests groups that a model rebuilt from the graphs could declare,
whether or not the original model declares them.

## Usage

``` r
vp_candidate_groups(model, min_size = 2)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- min_size:

  The smallest group (2 by default).

## Value

A tibble with `parent`, `group`, `size` and `feature`.

## See also

Other conflicts:
[`vp_alternative_groups()`](https://rheradio.github.io/variplex/reference/vp_alternative_groups.md),
[`vp_colouring()`](https://rheradio.github.io/variplex/reference/vp_colouring.md),
[`vp_conflict_cover()`](https://rheradio.github.io/variplex/reference/vp_conflict_cover.md),
[`vp_explain_conflict()`](https://rheradio.github.io/variplex/reference/vp_explain_conflict.md),
[`vp_explain_requires()`](https://rheradio.github.io/variplex/reference/vp_explain_requires.md),
[`vp_largest_compatible_set()`](https://rheradio.github.io/variplex/reference/vp_largest_compatible_set.md),
[`vp_opposites()`](https://rheradio.github.io/variplex/reference/vp_opposites.md),
[`vp_primitive_atleastone()`](https://rheradio.github.io/variplex/reference/vp_primitive_atleastone.md),
[`vp_primitive_conflicts()`](https://rheradio.github.io/variplex/reference/vp_primitive_conflicts.md),
[`vp_requires_from_conflicts()`](https://rheradio.github.io/variplex/reference/vp_requires_from_conflicts.md),
[`vp_twins()`](https://rheradio.github.io/variplex/reference/vp_twins.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_candidate_groups(band)
#> # A tibble: 2 × 4
#>   parent group  size feature
#>   <chr>  <int> <int> <chr>  
#> 1 Screen     1     2 BLEv40 
#> 2 Screen     1     2 BLEv42 
```
