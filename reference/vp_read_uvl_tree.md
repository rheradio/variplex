# The feature tree of a UVL model

The feature tree of a UVL model: each feature with its parent, how it
hangs from it, and whether it is abstract. Strong4VM's graphs have no
tree; the tree is needed to compare them with the model
(vp_false_optional(), vp_tree_agreement()). Reads the "features" section
of the file (indentation by tabs or by four spaces).

## Usage

``` r
vp_read_uvl_tree(path)
```

## Arguments

- path:

  The path of a `.uvl` file.

## Value

A tibble with `feature`, `parent` (NA for the root), `relation`
("mandatory", "optional", "alternative", "or", or a cardinality such as
"\[1..2\]") and `abstract`.

## See also

Other reading:
[`vp_classify()`](https://rheradio.github.io/variplex/reference/vp_classify.md),
[`vp_example()`](https://rheradio.github.io/variplex/reference/vp_example.md),
[`vp_expand()`](https://rheradio.github.io/variplex/reference/vp_expand.md),
[`vp_features()`](https://rheradio.github.io/variplex/reference/vp_features.md),
[`vp_functions()`](https://rheradio.github.io/variplex/reference/vp_functions.md),
[`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md),
[`vp_history()`](https://rheradio.github.io/variplex/reference/vp_history.md),
[`vp_igraph()`](https://rheradio.github.io/variplex/reference/vp_igraph.md),
[`vp_links()`](https://rheradio.github.io/variplex/reference/vp_links.md),
[`vp_minimal()`](https://rheradio.github.io/variplex/reference/vp_minimal.md),
[`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
[`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md),
[`vp_representativeness()`](https://rheradio.github.io/variplex/reference/vp_representativeness.md),
[`vp_subset()`](https://rheradio.github.io/variplex/reference/vp_subset.md)

## Examples

``` r
vp_read_uvl_tree(vp_example("miband3.uvl"))
#> # A tibble: 24 × 4
#>    feature         parent          relation  abstract
#>    <chr>           <chr>           <chr>     <lgl>   
#>  1 SmartWatch      NA              NA        TRUE    
#>  2 Screen          SmartWatch      optional  FALSE   
#>  3 TouchScreen     Screen          optional  FALSE   
#>  4 OLED            Screen          mandatory FALSE   
#>  5 CapacityButton  OLED            mandatory FALSE   
#>  6 Functionalities SmartWatch      mandatory TRUE    
#>  7 FitnessMonitor  Functionalities mandatory FALSE   
#>  8 SleepTracker    Functionalities mandatory FALSE   
#>  9 VibrateAlert    Functionalities mandatory FALSE   
#> 10 Call            VibrateAlert    mandatory FALSE   
#> # ℹ 14 more rows
```
