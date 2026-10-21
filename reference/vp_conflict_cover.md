# The fewest 'at most one of' groups that state every conflict

The primitive conflicts written as few "at most one of these" groups: a
greedy cover of the primitive conflicts by groups of features that all
exclude one another. Each group could be one declaration of the model
("at most one of"), and together they state every primitive conflict, so
every conflict of the model follows from them and the requirements. The
number of groups says how many such declarations a modeller would need.

## Usage

``` r
vp_conflict_cover(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with `group`, `size`, `feature` and `primitive_conflicts` (how
many of them the group states).

## See also

Other conflicts:
[`vp_alternative_groups()`](https://rheradio.github.io/variplex/reference/vp_alternative_groups.md),
[`vp_candidate_groups()`](https://rheradio.github.io/variplex/reference/vp_candidate_groups.md),
[`vp_colouring()`](https://rheradio.github.io/variplex/reference/vp_colouring.md),
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
vp_conflict_cover(band)
#> # A tibble: 6 × 4
#>   group  size feature         primitive_conflicts
#>   <int> <int> <chr>                         <int>
#> 1     1     2 BT40                              1
#> 2     1     2 Screen                            1
#> 3     2     2 HeartRateSensor                   1
#> 4     2     2 MovementFilter                    1
#> 5     3     2 BLEv40                            1
#> 6     3     2 BLEv42                            1
```
