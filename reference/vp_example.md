# The example models that come with the package

The package includes the variability models and data used in the
examples and vignettes:

## Usage

``` r
vp_example(file = NULL)
```

## Arguments

- file:

  The names of one or more example files. `NULL` lists them all.

## Value

The full paths of the files, or, with `file = NULL`, the names of all
the example files.

## Details

- the Mi Band smart band, in seven generations, as planned and as
  realised (`miband*_planned.uvl`, `miband*_realized.uvl`; `miband3.uvl`
  is the Mi Band 3), and variants of the Mi Band 3 that the vignettes
  use to show special cases (`miband3_battery.uvl`, `miband3_dead.uvl`,
  `miband3_void.uvl`, `miband3_no_ble.uvl`, `miband3_planned_old.uvl`,
  `miband3_wish.uvl`, `miband3_battery_wish.uvl`,
  `miband8_refactored.uvl`), with the valid configurations of two of
  them (`miband3_products.csv`, `miband3_battery_products.csv`), a
  sample of five (`sample.csv`) and a file of renames
  (`miband3_renames.txt`);

- small models with numbers, imports and other constructs of UVL
  (`tiny_band.uvl`, `numbers_band.uvl`, `power_band.uvl`,
  `power_band_boolean.uvl`, `void_numbers.uvl`, `imports_band.uvl`,
  `uvl_tour.uvl`);

- the feature models of axTLS, uClibc and fifteen versions of BusyBox in
  UVL (`axTLS.uvl`, `uClibc.uvl`, `busybox_01.uvl` to `busybox_15.uvl`),
  and a Boolean formula with eleven options of the Linux kernel in
  DIMACS format (`eleven_options.dimacs`);

- the folder `busybox`: the graphs of 37 monthly versions of BusyBox
  from the dataset of Strong4VM (<doi:10.5281/zenodo.17277788>), made by
  version 1 of Strong4VM, to read with
  [`vp_read_history()`](https://rheradio.github.io/variplex/reference/vp_read_history.md).

## See also

Other reading:
[`vp_classify()`](https://rheradio.github.io/variplex/reference/vp_classify.md),
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
vp_example()
#>  [1] "axTLS.uvl"                    "busybox"                     
#>  [3] "busybox_01.uvl"               "busybox_02.uvl"              
#>  [5] "busybox_03.uvl"               "busybox_04.uvl"              
#>  [7] "busybox_05.uvl"               "busybox_06.uvl"              
#>  [9] "busybox_07.uvl"               "busybox_08.uvl"              
#> [11] "busybox_09.uvl"               "busybox_10.uvl"              
#> [13] "busybox_11.uvl"               "busybox_12.uvl"              
#> [15] "busybox_13.uvl"               "busybox_14.uvl"              
#> [17] "busybox_15.uvl"               "eleven_options.dimacs"       
#> [19] "imports_band.uvl"             "miband1_planned.uvl"         
#> [21] "miband1_realized.uvl"         "miband1s.uvl"                
#> [23] "miband1s_planned.uvl"         "miband1s_realized.uvl"       
#> [25] "miband2.uvl"                  "miband2_planned.uvl"         
#> [27] "miband2_realized.uvl"         "miband3.uvl"                 
#> [29] "miband3_battery.uvl"          "miband3_battery_products.csv"
#> [31] "miband3_battery_wish.uvl"     "miband3_dead.uvl"            
#> [33] "miband3_no_ble.uvl"           "miband3_planned.uvl"         
#> [35] "miband3_planned_old.uvl"      "miband3_products.csv"        
#> [37] "miband3_realized.uvl"         "miband3_renames.txt"         
#> [39] "miband3_void.uvl"             "miband3_wish.uvl"            
#> [41] "miband4.uvl"                  "miband4_realized.uvl"        
#> [43] "miband5.uvl"                  "miband6.uvl"                 
#> [45] "miband6_realized.uvl"         "miband8_planned.uvl"         
#> [47] "miband8_realized.uvl"         "miband8_refactored.uvl"      
#> [49] "numbers_band.uvl"             "power_band.uvl"              
#> [51] "power_band_boolean.uvl"       "sample.csv"                  
#> [53] "tiny_band.uvl"                "uClibc.uvl"                  
#> [55] "uClibc_wish.uvl"              "uvl_tour.uvl"                
#> [57] "void_numbers.uvl"            
vp_example("miband3.uvl")
#> [1] "/home/runner/work/_temp/Library/variplex/extdata/miband3.uvl"
```
