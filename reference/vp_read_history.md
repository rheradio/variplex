# Read several runs: the versions of a model

Read a whole history: one run of Strong4VM per version of a model.

## Usage

``` r
vp_read_history(prefixes, versions = NULL, ...)
```

## Arguments

- prefixes:

  The prefixes of the runs, oldest first.

- versions:

  Names for the versions (by default, the names of the runs). Keep them
  in order: the functions of evolution.R compare each version with the
  one before it.

- ...:

  Passed to vp_read(), e.g. artificial = "drop".

## Value

A tibble with one row per version: `version` (a factor that keeps the
order) and `model` (a list column).

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
[`vp_read_uvl_tree()`](https://rheradio.github.io/variplex/reference/vp_read_uvl_tree.md),
[`vp_representativeness()`](https://rheradio.github.io/variplex/reference/vp_representativeness.md),
[`vp_subset()`](https://rheradio.github.io/variplex/reference/vp_subset.md)

## Examples

``` r
gens <- c("miband1", "miband2", "miband3")
prefixes <- vapply(
  vp_example(paste0(gens, "_realized.uvl")),
  vp_generate,
  "",
  read = FALSE
)
vp_read_history(prefixes, versions = gens)
#> # A tibble: 3 × 2
#>   version model       
#>   <fct>   <named list>
#> 1 miband1 <vp_model>  
#> 2 miband2 <vp_model>  
#> 3 miband3 <vp_model>  
```
