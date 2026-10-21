# Print a model

A short description of a model: its features, links and atomic sets.

## Usage

``` r
# S3 method for class 'vp_model'
print(x, ...)
```

## Arguments

- x:

  A model.

- ...:

  Not used.

## Value

`x`, invisibly.

## Examples

``` r
vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
#> variplex model "miband3"
#>   features: 11 variable (the nodes of the graphs), 8 core, 0 dead
#>   requires: 36 arrows   excludes: 18 lines
#>   at least one: 3 lines
#>   atomic sets: 2 (of two or more features)
```
