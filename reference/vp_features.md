# The features and their status (variable, core, dead)

The features of a model and their status: "variable" (a real choice),
"core" (in every product) or "dead" (in none). Only the variable
features are nodes of the graphs.

## Usage

``` r
vp_features(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

A tibble with the columns `feature` and `status`.

## See also

Other reading:
[`vp_classify()`](https://rheradio.github.io/variplex/reference/vp_classify.md),
[`vp_example()`](https://rheradio.github.io/variplex/reference/vp_example.md),
[`vp_expand()`](https://rheradio.github.io/variplex/reference/vp_expand.md),
[`vp_functions()`](https://rheradio.github.io/variplex/reference/vp_functions.md),
[`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md),
[`vp_history()`](https://rheradio.github.io/variplex/reference/vp_history.md),
[`vp_igraph()`](https://rheradio.github.io/variplex/reference/vp_igraph.md),
[`vp_links()`](https://rheradio.github.io/variplex/reference/vp_links.md),
[`vp_minimal()`](https://rheradio.github.io/variplex/reference/vp_minimal.md),
[`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
[`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md),
[`vp_read_uvl_tree()`](https://rheradio.github.io/variplex/reference/vp_read_uvl_tree.md),
[`vp_representativeness()`](https://rheradio.github.io/variplex/reference/vp_representativeness.md),
[`vp_subset()`](https://rheradio.github.io/variplex/reference/vp_subset.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_features(band)
#> # A tibble: 19 × 2
#>    feature            status  
#>    <chr>              <chr>   
#>  1 Screen             variable
#>  2 TouchScreen        variable
#>  3 OLED               variable
#>  4 CapacityButton     variable
#>  5 ContactlessPayment variable
#>  6 MovementFilter     variable
#>  7 HeartRateSensor    variable
#>  8 BLEv40             variable
#>  9 BLEv42             variable
#> 10 BT40               variable
#> 11 NFC                variable
#> 12 FitnessMonitor     core    
#> 13 SleepTracker       core    
#> 14 VibrateAlert       core    
#> 15 Call               core    
#> 16 Notification       core    
#> 17 Pedometer          core    
#> 18 Accelerometer      core    
#> 19 Bluetooth          core    
```
