# The most required features, and whether that is their own merit

Genuine hubs: the features that many others require in their own right,
not only because they sit below another feature that gathers their
dependants. A feature p dominates a feature q (Abate et al.'s strong
dominance) when p requires q and nearly all the other features that
require q also require p: then almost every dependant of q reaches q
through p, and the importance of q is borrowed from p. A hub that no
feature dominates is genuine.

## Usage

``` r
vp_genuine_hubs(model, top = 10, share = 0.9)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- top:

  How many of the most required features to look at.

- share:

  What "nearly all" means: the share of the other dependants of q that
  must also require p (0.9 by default).

## Value

A tibble with `feature`, `required_by`, `dominated_by` (NA for a genuine
hub), `share_through` (the share of the other dependants of the feature
that also require its dominator; NA for a genuine hub) and `genuine`.

## See also

Other features:
[`vp_atleastone_of()`](https://rheradio.github.io/variplex/reference/vp_atleastone_of.md),
[`vp_conflicts_of()`](https://rheradio.github.io/variplex/reference/vp_conflicts_of.md),
[`vp_feature_table()`](https://rheradio.github.io/variplex/reference/vp_feature_table.md),
[`vp_required_by()`](https://rheradio.github.io/variplex/reference/vp_required_by.md),
[`vp_requirements()`](https://rheradio.github.io/variplex/reference/vp_requirements.md),
[`vp_warning_zone()`](https://rheradio.github.io/variplex/reference/vp_warning_zone.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_genuine_hubs(band, top = 5)
#> # A tibble: 5 × 5
#>   feature         required_by dominated_by       share_through genuine
#>   <chr>                 <int> <chr>                      <dbl> <lgl>  
#> 1 Screen                    5 NA                            NA TRUE   
#> 2 HeartRateSensor           3 BLEv42                         1 FALSE  
#> 3 BLEv42                    2 TouchScreen                    1 FALSE  
#> 4 TouchScreen               1 ContactlessPayment             1 FALSE  
#> 5 BLEv40                    1 MovementFilter                 1 FALSE  
```
