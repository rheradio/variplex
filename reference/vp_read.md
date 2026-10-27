# Read the files of one run of Strong4VM

Read the results of one run of Strong4VM.

## Usage

``` r
vp_read(
  prefix,
  name = NULL,
  artificial = c("keep", "drop"),
  translator = c("kmax", "kconfigreader"),
  form = c("complete", "minimal")
)
```

## Arguments

- prefix:

  The path of the files without their ending, e.g.
  "out/miband3_realized" (the part before "\_\_").

- name:

  A short name for the model, used in tables; by default the last part
  of the prefix.

- artificial:

  What to do with nodes whose names look like helper variables of a
  translation (`"k!12"`, `"__VISIBILITY__X"`, `"<unsupported>"`): "keep"
  (default) or "drop". Strong4VM 2.0 already drops them; "drop" is for
  the graphs of version 1, such as those of the Zenodo dataset.

- translator:

  With artificial = "drop": "kmax" (default) or "kconfigreader", whose
  formulas have two more kinds of helper variable: CHOICE_n (one per
  choice group) and X_MODULE ("X is built as a module", dropped only
  when X exists).

- form:

  "complete" (default) reads the complete graphs; "minimal" reads the
  minimal form that Strong4VM writes beside them
  (\_\_requires_skeleton.net, \_\_excludes_primitive.net,
  \_\_atleastone_primitive.net): see vp_minimal().

## Value

A model: a list with the tibbles `features`, `requires`, `excludes`,
`atleastone` (NULL when the run had no or_graph = TRUE) and `atomic`,
plus `variables` and `summary` when the run wrote them.

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
[`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md),
[`vp_read_uvl_tree()`](https://rheradio.github.io/variplex/reference/vp_read_uvl_tree.md),
[`vp_representativeness()`](https://rheradio.github.io/variplex/reference/vp_representativeness.md),
[`vp_subset()`](https://rheradio.github.io/variplex/reference/vp_subset.md)

## Examples

``` r
prefix <- vp_generate(vp_example("miband3.uvl"), read = FALSE)
band <- vp_read(prefix)
band
#> variplex model "miband3"
#>   features: 11 variable (the nodes of the graphs), 8 core, 0 dead
#>   requires: 36 arrows   excludes: 18 lines
#>   at least one: not computed (use vp_generate(or_graph = TRUE))
#>   atomic sets: 2 (of two or more features)
vp_read(prefix, form = "minimal")
#> variplex model "miband3"
#>   features: 8 variable (the nodes of the graphs), 8 core, 0 dead
#>   requires: 6 arrows   excludes: 3 lines
#>   at least one: not computed (use vp_generate(or_graph = TRUE))
#>   minimal form: skeleton, primitive conflicts;
#>   each atomic set is one node (2 sets)
```
