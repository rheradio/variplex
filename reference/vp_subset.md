# Focus on part of a model (exact: no solver needed)

Focus on part of a model: keep only some features, with the links among
them. Whether two features are related does not depend on the other
features, so the result is exactly the graphs of the model restricted to
that part (property P3 of the future-work report): no solver has to run
again.

## Usage

``` r
vp_subset(model, features, name = paste0(model$name, " (part)"))
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

- features:

  The variable features to keep (for example those of one subsystem,
  chosen by name with grepl()).

- name:

  A name for the part.

## Value

A model, like that of vp_read(), with only those features (core and dead
features are kept in its list).

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
[`vp_read_uvl_tree()`](https://rheradio.github.io/variplex/reference/vp_read_uvl_tree.md),
[`vp_representativeness()`](https://rheradio.github.io/variplex/reference/vp_representativeness.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
part <- vp_subset(band, c("Screen", "TouchScreen", "BT40", "BLEv40"))
vp_links(part, "excludes")
#> # A tibble: 4 × 2
#>   from        to    
#>   <chr>       <chr> 
#> 1 Screen      BT40  
#> 2 TouchScreen BLEv40
#> 3 TouchScreen BT40  
#> 4 BLEv40      BT40  
```
