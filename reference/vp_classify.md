# Classify the variables of a formula without computing any graph

Decides, for every variable of the formula, whether it is a real option
(a node of the graphs), a helper variable of the translation, or a value
of a non-Boolean option, with the rule that decided it. Nothing is
solved, so it is fast even for the Linux kernel: use it to check the
options of
[`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
(`translator`, `tristate`, `nonbool`, ...) before a long run.

## Usage

``` r
vp_classify(input, output_dir = NULL, ...)
```

## Arguments

- input:

  The path of a `.uvl` file (a feature model in the Universal
  Variability Language), or of a `.dimacs` or `.cnf` file (a Boolean
  formula in DIMACS format, whose comments `c <number> <name>` name the
  variables).

- output_dir:

  The folder for the files of the run. By default (`NULL`) a new
  temporary folder, which R deletes at the end of the session; give a
  folder to keep the files.

- ...:

  Further arguments of
  [`vp_generate()`](https://rheradio.github.io/variplex/reference/vp_generate.md)
  that change the classification, such as `translator`, `tristate`,
  `nonbool` or `keep_pattern`.

## Value

A tibble with one row per variable of the formula: the contents of the
file `__variables.csv` (its columns are described in the vignette
[`vignette("graphs", package = "variplex")`](https://rheradio.github.io/variplex/articles/graphs.md)).

## See also

Other reading:
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
[`vp_representativeness()`](https://rheradio.github.io/variplex/reference/vp_representativeness.md),
[`vp_subset()`](https://rheradio.github.io/variplex/reference/vp_subset.md)

## Examples

``` r
vp_classify(vp_example("eleven_options.dimacs"), translator = "kmax")
#> # A tibble: 11 × 8
#>    dimacs_var name             output_name   node_id class status decision rule 
#>         <int> <chr>            <chr>         <lgl>   <chr> <lgl>  <chr>    <chr>
#>  1          1 ACPI             ACPI          NA      OPTI… NA     kept     K6   
#>  2          2 IA64             IA64          NA      OPTI… NA     kept     K6   
#>  3          3 ACPI_INTERPRETER ACPI_INTERPR… NA      OPTI… NA     kept     K6   
#>  4          4 ACPI_NUMA        ACPI_NUMA     NA      OPTI… NA     kept     K6   
#>  5          5 IA64_GENERIC     IA64_GENERIC  NA      OPTI… NA     kept     K6   
#>  6          6 NUMA             NUMA          NA      OPTI… NA     kept     K6   
#>  7          7 IA64_DIG         IA64_DIG      NA      OPTI… NA     kept     K6   
#>  8          8 IA64_HP_ZX1      IA64_HP_ZX1   NA      OPTI… NA     kept     K6   
#>  9          9 X86              X86           NA      OPTI… NA     kept     K6   
#> 10         10 X86_PC           X86_PC        NA      OPTI… NA     kept     K6   
#> 11         11 IA64_SGI_SN2     IA64_SGI_SN2  NA      OPTI… NA     kept     K6   
```
