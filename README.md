
<!-- README.md is generated from README.Rmd. Please edit that file -->

# <img src="man/figures/variplex-wordmark.svg" alt="variplex" height="48"/> <img src="man/figures/logo.svg" align="right" height="139" alt="variplex logo"/>

<!-- badges: start -->

[![R-CMD-check](https://github.com/rheradio/variplex/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/rheradio/variplex/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

variplex does two things for engineers who work with variability models:

1.  **It builds the graphs.** For a variability model, variplex computes
    every relationship between two features that holds in all its valid
    configurations:

    - **requires**: every valid configuration with A also has B;
    - **excludes**: no valid configuration has both A and B;
    - **at least one**: no valid configuration lacks both.

    The model can be a feature model in
    [UVL](https://universal-variability-language.github.io/), or the
    Boolean formula (DIMACS) of a model written in any other notation,
    such as the Kconfig files of the Linux kernel translated by KMax,
    KConfigReader or KconfigSampler. The graphs are synthesized once
    using a SAT solver and an auxiliary graph called Modal Implication
    Graph (MIG).

2.  **It analyses the graphs.** More than a hundred functions answer
    questions about them without calling a solver again, and return
    tibbles: what each feature weighs, how the model is layered, where
    its conflicts come from, which features can go together, how much of
    the model a test sample covers, which patterns recur, and how the
    model changes from version to version.

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
models is at <https://doi.org/10.5281/zenodo.17277788>.
