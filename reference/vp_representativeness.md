# The share of the configurations the graphs allow that are valid (GANAK)

How much of the model the graphs leave out, as Strong4VM measured it
with the model counter GANAK (run with vp_generate(representativeness =
TRUE)). The graphs allow some configurations of the features that are
not valid, because they hold no rule over three or more features:
`vm_configurations` is the number of valid configurations of the
variability model, `graph_configurations` the number of configurations
of the same features that break no link of the graphs, and `share` =
vm_configurations / graph_configurations (1: the graphs say everything
that the model says about its features).

## Usage

``` r
vp_representativeness(model)
```

## Arguments

- model:

  A model, from
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  or
  [`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md),
  in its complete or its minimal form.

## Value

One row: `vm_configurations`, `graph_configurations` (numbers; very
large ones are approximate, since R keeps about 15 digits; the exact
values are in \_\_summary.json), `share`, `left_out` (1 - share) and
`note` (empty, or why the values are NA).

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
[`vp_subset()`](https://rheradio.github.io/variplex/reference/vp_subset.md)

## Examples

``` r
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
vp_representativeness(band) # NA: the run did not count with GANAK
#> # A tibble: 1 × 5
#>   vm_configurations graph_configurations share left_out note                    
#>               <dbl>                <dbl> <dbl>    <dbl> <chr>                   
#> 1                NA                   NA    NA       NA not measured: run vp_ge…
# \donttest{
if (nzchar(Sys.which("ganak"))) {
  counted <- vp_generate(
    vp_example("miband3.uvl"),
    representativeness = TRUE
  )
  vp_representativeness(counted)
}
# }
```
