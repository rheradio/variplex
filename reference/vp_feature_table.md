# Every measure of every feature, one row each

A table of measures, one row per variable feature.

## Usage

``` r
vp_feature_table(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with the columns:

- `feature`: the name

- `required_by`: how many features require it (its sensitivity: the size
  of its impact set)

- `requires`: how many features it requires

- `excludes`: how many features it excludes (its conflict degree)

- `atleastone`: how many features it is joined to in the at-least-one
  graph (NA without or_graph = TRUE)

- `decision_power`: the share of the other features that selecting it
  decides: (requires + excludes) / (n - 1)

- `decision_power_off`: the same for leaving it out: (required_by +
  atleastone) / (n - 1) (NA without or_graph = TRUE)

- `level`: its level in the hierarchy (0: it needs nothing)

- `direct_required_by`, `direct_requires`: the same counts in the
  skeleton (written arrows, roughly)

- `betweenness`: on the skeleton: how many chains of requirements pass
  through it (gateways)

- `closeness_out`: on the skeleton: 1 / average number of steps to what
  it requires (NA if it requires nothing)

- `closeness_in`: on the skeleton: 1 / average number of steps from what
  requires it (NA if nothing does)

- `harmonic`: on the skeleton: the sum of 1 / steps to each feature it
  requires (0 if none); unlike closeness, it also grows with how many
  features it requires

- `atomic_set`: the representative of its atomic set, or NA

- `isolated`: TRUE when it is in no graph at all

## Details

The counts (required_by, requires, excludes, atleastone, isolated) read
the graphs of the model as they are: on the minimal form (vp_minimal())
they count direct links only. Decision power and the positions in the
hierarchy are inferences and always use the complete graphs.

## See also

Other features:
[`vp_atleastone_of()`](https://rheradio.github.io/variplex/reference/vp_atleastone_of.md),
[`vp_conflicts_of()`](https://rheradio.github.io/variplex/reference/vp_conflicts_of.md),
[`vp_genuine_hubs()`](https://rheradio.github.io/variplex/reference/vp_genuine_hubs.md),
[`vp_required_by()`](https://rheradio.github.io/variplex/reference/vp_required_by.md),
[`vp_requirements()`](https://rheradio.github.io/variplex/reference/vp_requirements.md),
[`vp_warning_zone()`](https://rheradio.github.io/variplex/reference/vp_warning_zone.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_feature_table(band)
#> # A tibble: 11 × 16
#>    feature            required_by requires excludes atleastone decision_power
#>    <chr>                    <int>    <int>    <int>      <int>          <dbl>
#>  1 Screen                       8        2        1          1            0.3
#>  2 TouchScreen                  2        5        3          0            0.8
#>  3 OLED                         8        2        1          1            0.3
#>  4 CapacityButton               8        2        1          1            0.3
#>  5 ContactlessPayment           1        7        3          0            1  
#>  6 MovementFilter               0        4        6          0            1  
#>  7 HeartRateSensor              4        0        1          0            0.1
#>  8 BLEv40                       1        3        5          0            0.8
#>  9 BLEv42                       3        4        3          0            0.7
#> 10 BT40                         0        0        9          3            0.9
#> 11 NFC                          1        7        3          0            1  
#> # ℹ 10 more variables: decision_power_off <dbl>, level <int>,
#> #   direct_required_by <int>, direct_requires <int>, betweenness <dbl>,
#> #   closeness_out <dbl>, closeness_in <dbl>, harmonic <dbl>, atomic_set <chr>,
#> #   isolated <lgl>
```
