
<!-- README.md is generated from README.Rmd. Please edit that file -->

# variplex

<!-- badges: start -->

[![CRAN
status](https://www.r-pkg.org/badges/version/variplex)](https://CRAN.R-project.org/package=variplex)
[![R-CMD-check](https://github.com/rheradio/variplex/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/rheradio/variplex/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

variplex computes, for a variability model, every relationship between
two features that holds in all its valid configurations, and analyses
the resulting graphs from R:

- **requires**: every valid configuration with A also has B;
- **excludes**: no valid configuration has both A and B;
- **at least one**: no valid configuration lacks both.

The model can be a feature model in
[UVL](https://universal-variability-language.github.io/), or the Boolean
formula (DIMACS) of a model written in any other notation, such as the
Kconfig files of the Linux kernel translated by KMax, KConfigReader or
KconfigSampler. A SAT solver finds the relationships once; then more
than a hundred functions answer questions about them without a solver,
and return tibbles: what each feature weighs, how the model is layered,
where its conflicts come from, which features can go together, how much
of the model a test sample covers, which patterns recur, and how the
model changes from version to version.

variplex brings together the engine of
[Strong4VM](https://github.com/rheradio/strong4vm) (C++, compiled into
the package with the SAT solver Glucose) and its R functions, which were
named `sg_*` and are now `vp_*`.

## Installation

``` r
install.packages("variplex")
```

Nothing has to be installed outside R. To draw the graphs, install also
the suggested packages DiagrammeR (and DiagrammeRsvg and rsvg to save
drawings as SVG, PDF or PNG). The development version is on GitHub:

``` r
# install.packages("pak")
pak::pak("rheradio/variplex")
```

## Example

``` r
library(variplex)

band <- vp_generate(vp_example("miband3_realized.uvl"), or_graph = TRUE)
band
#> variplex model "miband3_realized"
#>   features: 11 variable (the nodes of the graphs), 8 core, 0 dead
#>   requires: 21 arrows   excludes: 10 lines
#>   at least one: 3 lines
#>   atomic sets: 1 (of two or more features)

vp_requirements(band, "TouchScreen") # what the touch screen brings along
#> # A tibble: 3 x 1
#>   feature       
#>   <chr>         
#> 1 Screen        
#> 2 OLED          
#> 3 CapacityButton
# why two features never go together
vp_explain_conflict(band, "MovementFilter", "BT40")
#> # A tibble: 3 x 5
#>   origin  step from           link     to    
#>    <int> <int> <chr>          <chr>    <chr> 
#> 1      1     1 MovementFilter requires BLEv40
#> 2      1     2 BLEv40         requires Screen
#> 3      1     3 Screen         excludes BT40
vp_can_go_together(
  band,
  list(c("TouchScreen", "HeartRateSensor"), c("TouchScreen", "BT40"))
)
#> # A tibble: 2 x 3
#>   wish                         possible reasons                                          
#>   <chr>                        <lgl>    <chr>                                            
#> 1 TouchScreen, HeartRateSensor TRUE     ""                                               
#> 2 TouchScreen, BT40            FALSE    "TouchScreen (which brings Screen) excludes BT40"
```

``` r
vp_plot(vp_minimal(band))                          # with DiagrammeR
```

## From the command line of Strong4VM to R

| `strong4vm`                                      | variplex                                                                         |
|:-------------------------------------------------|:---------------------------------------------------------------------------------|
| `strong4vm model.uvl -o out --or-graph --kernel` | `vp_generate("model.uvl", output_dir = "out", or_graph = TRUE, kernel = TRUE)`   |
| `strong4vm formula.dimacs --classify-only`       | `vp_classify("formula.dimacs")`                                                  |
| `strong4vm check out/model`                      | `vp_check(vp_read("out/model"))`                                                 |
| `strong4vm expand out/model`                     | `vp_expand(vp_read("out/model", form = "minimal"))`                              |
| `strong4vm explain out/model --conflict A B`     | `vp_explain_conflict(model, "A", "B")`                                           |
| `strong4vm explain out/model --requires A B`     | `vp_explain_requires(model, "A", "B")`                                           |
| `strong4vm diff old new`                         | `vp_compare(old, new)`, `vp_changed_links(old, new)`, `vp_state_moves(old, new)` |
| `strong4vm diff --rename FILE old new`           | `vp_compare(vp_rename(old, FILE), new)`                                          |

Every option of `strong4vm generate` is an argument of `vp_generate()`;
`?vp_generate` lists them.

## Documentation

Start with `vignette("variplex")`. The other vignettes go through the
results (`vignette("graphs")`) and every question the graphs answer,
topic by topic; `vp_functions()` lists the functions by topic.

## What the graphs cannot see

The graphs hold relationships between **two** features. A rule that ties
three or more features at once (“A requires B or C”) is in no graph,
unless it implies a relationship between two of them. Everything the
graphs say is true; a “yes” to a long wish list can still be wrong.
`vignette("limits-theory")` explains it, measures it and proves it.

## Citation

`citation("variplex")`. The dataset of graphs of 5,709 variability
models made with Strong4VM is at
<https://doi.org/10.5281/zenodo.17277788>.
