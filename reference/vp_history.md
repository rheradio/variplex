# Compute the graphs of every version of a model

Runs
[`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
on each version of a model and gathers the results into a history, the
object that the functions of evolution take (as
[`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md)
does for runs made earlier).

## Usage

``` r
vp_history(inputs, versions = NULL, ...)
```

## Arguments

- inputs:

  The model files of the versions (UVL or DIMACS), oldest first.

- versions:

  Names for the versions; by default the names of the files without
  their ending.

- ...:

  Further arguments of
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md),
  the same for every version (such as `or_graph = TRUE`).

## Value

A tibble with one row per version: `version` (a factor that keeps the
order) and `model` (a list column of models).

## See also

Other reading:
[`vp_classify()`](https://rheradio.github.io/variplex/reference/vp_classify.md),
[`vp_example()`](https://rheradio.github.io/variplex/reference/vp_example.md),
[`vp_expand()`](https://rheradio.github.io/variplex/reference/vp_expand.md),
[`vp_features()`](https://rheradio.github.io/variplex/reference/vp_features.md),
[`vp_functions()`](https://rheradio.github.io/variplex/reference/vp_functions.md),
[`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md),
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
gens <- c("miband1", "miband2", "miband3")
history <- vp_history(
  vp_example(paste0(gens, "_realized.uvl")),
  versions = gens
)
history
#> # A tibble: 3 × 2
#>   version model     
#>   <fct>   <list>    
#> 1 miband1 <vp_model>
#> 2 miband2 <vp_model>
#> 3 miband3 <vp_model>
vp_history_sizes(history)
#> # A tibble: 3 × 12
#>   version features  core  dead requires excludes atleastone skeleton
#>   <fct>      <int> <int> <int>    <int>    <int>      <int>    <int>
#> 1 miband1        0     8     0        0        0         NA        0
#> 2 miband2        8     8     0        6        3         NA        0
#> 3 miband3       11     8     0       21       10         NA        6
#> # ℹ 4 more variables: primitive_conflicts <int>, depth <int>,
#> #   implicit_requires <dbl>, implicit_excludes <dbl>
```
