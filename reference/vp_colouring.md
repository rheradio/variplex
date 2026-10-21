# The features split into groups without conflicts

The features split into groups (colours) so that no two features of a
group exclude each other. Each product fits in one colour, so testing
every feature at least once needs at least as many products as colours.
The colouring is quick, not always the smallest possible.

## Usage

``` r
vp_colouring(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with `feature` and `colour` (a number).

## See also

Other conflicts:
[`vp_alternative_groups()`](https://rheradio.github.io/variplex/reference/vp_alternative_groups.md),
[`vp_candidate_groups()`](https://rheradio.github.io/variplex/reference/vp_candidate_groups.md),
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
vp_colouring(band)
#> # A tibble: 11 × 2
#>    feature            colour
#>    <chr>               <int>
#>  1 Screen                  2
#>  2 TouchScreen             2
#>  3 OLED                    2
#>  4 CapacityButton          2
#>  5 ContactlessPayment      2
#>  6 MovementFilter          3
#>  7 HeartRateSensor         1
#>  8 BLEv40                  3
#>  9 BLEv42                  2
#> 10 BT40                    1
#> 11 NFC                     2
```
