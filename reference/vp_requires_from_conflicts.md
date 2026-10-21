# Requirements explained by a conflict and an at-least-one line

Requirements that follow from a conflict and an at-least-one line: if f
excludes g, and every product has g or h, then f requires h. The
skeleton keeps such an arrow when no chain of arrows explains it; with
the three graphs it is explained after all. Needs the at-least-one
graph.

## Usage

``` r
vp_requires_from_conflicts(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with one row per arrow between different atomic sets that has
such an explanation: `from`, `to`, `via` (one g) and `in_skeleton` (TRUE
when no chain of arrows explains it: only this route does).

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
[`vp_twins()`](https://rheradio.github.io/variplex/reference/vp_twins.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_requires_from_conflicts(band)
#> # A tibble: 5 × 4
#>   from               to     via   in_skeleton
#>   <chr>              <chr>  <chr> <lgl>      
#> 1 TouchScreen        Screen BT40  FALSE      
#> 2 ContactlessPayment Screen BT40  FALSE      
#> 3 MovementFilter     Screen BT40  FALSE      
#> 4 BLEv40             Screen BT40  TRUE       
#> 5 BLEv42             Screen BT40  TRUE       
```
