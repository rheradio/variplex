# The links of one graph, as a tibble

The links of one graph as a tibble with the columns `from` and `to`.

## Usage

``` r
vp_links(model, graph = c("requires", "excludes", "atleastone"))
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- graph:

  "requires" (from needs to), "excludes" (from and to never go together)
  or "atleastone" (every product has from or to). For the last two the
  order of the columns means nothing.

## Value

A tibble with the columns `from` and `to`.

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
[`vp_minimal()`](https://rheradio.github.io/variplex/reference/vp_minimal.md),
[`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
[`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md),
[`vp_read_uvl_tree()`](https://rheradio.github.io/variplex/reference/vp_read_uvl_tree.md),
[`vp_representativeness()`](https://rheradio.github.io/variplex/reference/vp_representativeness.md),
[`vp_subset()`](https://rheradio.github.io/variplex/reference/vp_subset.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_links(band, "requires")
#> # A tibble: 36 × 2
#>    from           to             
#>    <chr>          <chr>          
#>  1 Screen         OLED           
#>  2 Screen         CapacityButton 
#>  3 TouchScreen    Screen         
#>  4 TouchScreen    OLED           
#>  5 TouchScreen    CapacityButton 
#>  6 TouchScreen    HeartRateSensor
#>  7 TouchScreen    BLEv42         
#>  8 OLED           Screen         
#>  9 OLED           CapacityButton 
#> 10 CapacityButton Screen         
#> # ℹ 26 more rows
vp_links(band, "excludes")
#> # A tibble: 18 × 2
#>    from               to             
#>    <chr>              <chr>          
#>  1 Screen             BT40           
#>  2 TouchScreen        MovementFilter 
#>  3 TouchScreen        BLEv40         
#>  4 TouchScreen        BT40           
#>  5 OLED               BT40           
#>  6 CapacityButton     BT40           
#>  7 ContactlessPayment MovementFilter 
#>  8 ContactlessPayment BLEv40         
#>  9 ContactlessPayment BT40           
#> 10 MovementFilter     HeartRateSensor
#> 11 MovementFilter     BLEv42         
#> 12 MovementFilter     BT40           
#> 13 MovementFilter     NFC            
#> 14 BLEv40             BLEv42         
#> 15 BLEv40             BT40           
#> 16 BLEv40             NFC            
#> 17 BLEv42             BT40           
#> 18 BT40               NFC            
```
