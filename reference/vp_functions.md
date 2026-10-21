# Every function of the package, by topic

A table of the functions of variplex: the topic, the name, the
parameters as one would type them (a parameter with a default shows it)
and the question each function answers. The topics follow the vignettes.

## Usage

``` r
vp_functions(topic = NULL)
```

## Arguments

- topic:

  A part of the name of a topic, such as `"conflicts"` or `"evol"`;
  `NULL` lists every function.

## Value

A tibble with the columns `topic` (a factor, in the order of the
vignettes), `name`, `parameters` and `answers`.

## See also

Other reading:
[`vp_classify()`](https://rheradio.github.io/variplex/reference/vp_classify.md),
[`vp_example()`](https://rheradio.github.io/variplex/reference/vp_example.md),
[`vp_expand()`](https://rheradio.github.io/variplex/reference/vp_expand.md),
[`vp_features()`](https://rheradio.github.io/variplex/reference/vp_features.md),
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
vp_functions()
#> # A tibble: 126 × 4
#>    topic     name            parameters                                  answers
#>    <fct>     <chr>           <chr>                                       <chr>  
#>  1 1 reading vp_generate     "input, output_dir = NULL, threads = 1, or… comput…
#>  2 1 reading vp_classify     "input, output_dir = NULL, ..."             classi…
#>  3 1 reading vp_example      "file = NULL"                               the ex…
#>  4 1 reading vp_functions    "topic = NULL"                              every …
#>  5 1 reading vp_read         "prefix, name = NULL, artificial = \"keep\… read t…
#>  6 1 reading vp_read_history "prefixes, versions = NULL, ..."            read s…
#>  7 1 reading vp_history      "inputs, versions = NULL, ..."              comput…
#>  8 1 reading vp_features     "model"                                     the fe…
#>  9 1 reading vp_links        "model, graph = \"requires\""               the li…
#> 10 1 reading vp_igraph       "model, graph = \"requires\""               the ig…
#> # ℹ 116 more rows
vp_functions("conflicts")
#> # A tibble: 12 × 4
#>    topic       name                       parameters                  answers   
#>    <fct>       <chr>                      <chr>                       <chr>     
#>  1 5 conflicts vp_primitive_conflicts     model                       the confl…
#>  2 5 conflicts vp_explain_conflict        model, a, b                 why two f…
#>  3 5 conflicts vp_explain_requires        model, a, b, max_routes = 3 why one f…
#>  4 5 conflicts vp_alternative_groups      model, min_size = 3         groups of…
#>  5 5 conflicts vp_largest_compatible_set  model, exact_limit = 60     the most …
#>  6 5 conflicts vp_colouring               model                       the featu…
#>  7 5 conflicts vp_twins                   model                       features …
#>  8 5 conflicts vp_candidate_groups        model, min_size = 2         mutually …
#>  9 5 conflicts vp_conflict_cover          model                       the fewes…
#> 10 5 conflicts vp_primitive_atleastone    model                       the at-le…
#> 11 5 conflicts vp_opposites               model                       pairs of …
#> 12 5 conflicts vp_requires_from_conflicts model                       requireme…
```
