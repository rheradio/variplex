# Compute the strong dependency and conflict graphs of a variability model

Reads a variability model written in UVL, or the Boolean formula of a
model written in any other notation (a DIMACS file, such as those that
KMax, KConfigReader, KconfigSampler or TraVarT produce from Kconfig and
other languages), and computes every *strong* binary relationship
between its features, that is, every relationship that holds in all the
valid configurations:

## Usage

``` r
vp_generate(
  input,
  output_dir = NULL,
  threads = 1,
  or_graph = FALSE,
  kernel = FALSE,
  atomic = TRUE,
  minimal = TRUE,
  check = TRUE,
  fail_on_check = TRUE,
  mig = TRUE,
  keep_dimacs = FALSE,
  tseitin = FALSE,
  strict_uvl = FALSE,
  translator = c("auto", "kmax", "kconfigreader", "kconfigsampler", "travart", "uvl",
    "generic"),
  tristate = c("merge", "builtin", "both"),
  nonbool = c("merge", "drop", "keep"),
  visibility = c("drop", "keep"),
  abstract_groups = c("merge", "keep"),
  synthetic_root = c("drop", "keep"),
  abstract = c("drop", "keep", "merge"),
  fixed_nodes = c("drop", "keep"),
  unnamed = c("drop", "keep"),
  unknown_names = NULL,
  decls = NULL,
  decls_unconstrained = c("ignore", "add"),
  keep_type_prefix = FALSE,
  strip_config_prefix = FALSE,
  keep_pattern = character(0),
  drop_pattern = character(0),
  drop_names = NULL,
  filter_at = c("input", "output"),
  max_matrix_memory = 2,
  representativeness = FALSE,
  ganak = "ganak",
  legacy = FALSE,
  quiet = TRUE,
  read = TRUE
)
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

- threads:

  Number of threads for the solver. More than the number of cores is
  reduced to the cores.

- or_graph:

  Also compute the at-least-one graph. It roughly doubles the work of
  the solver, and it is needed for everything that concerns leaving
  features out.

- kernel:

  Also compute the kernel (see
  [`vp_kernel()`](https://rheradio.github.io/variplex/reference/vp_kernel.md)).

- atomic, minimal, check:

  Write the atomic sets, the minimal form, and run the consistency
  checks on the output.

- fail_on_check:

  If a consistency check fails, stop with an error (the default) or only
  warn.

- mig:

  Use a modal implication graph to skip solver calls (same graphs,
  usually faster).

- keep_dimacs:

  For UVL input: also keep the DIMACS translation in `output_dir`.

- tseitin:

  For UVL input: translate with the Tseitin encoding (auxiliary
  variables) instead of the straightforward one.

- strict_uvl:

  For UVL input: a constraint that cannot be translated (not Boolean, or
  naming a feature that the model does not declare) is an error instead
  of a warning.

- translator:

  The tool that made a DIMACS file, which decides which of its variables
  are real options: `"auto"` detects it from the comments of the file.

- tristate:

  Tristate options `X` / `X_MODULE` of Kconfig: one node "X built in or
  as a module" (`"merge"`), `X` only (`"builtin"`), or both.

- nonbool:

  Value variables of non-Boolean options: one node "P is set"
  (`"merge"`), none (`"drop"`) or one node per value (`"keep"`).

- visibility:

  KMax visibility variables: `"drop"` or `"keep"`.

- abstract_groups:

  TraVarT abstract group features (`_xor`, `_or`, `_alt`): `"merge"`
  into their parent, or `"keep"`.

- synthetic_root:

  The synthetic root `__Root__` added by some translations: `"drop"` or
  `"keep"`.

- abstract:

  UVL features marked `{abstract}` (the root included): `"drop"`,
  `"keep"`, or `"merge"` into an equivalent feature that is not
  abstract, if there is one.

- fixed_nodes:

  Core and dead options as nodes of the graphs (`"keep"`), or only in
  their lists (`"drop"`).

- unnamed:

  Variables without a name comment: `"drop"`, or `"keep"` (named
  `v<n>`).

- unknown_names:

  Names that match no rule of the translator profile: `"keep"`, `"drop"`
  or `"error"`. `NULL`: `"drop"` for KMax, KConfigReader and
  KconfigSampler, `"keep"` otherwise.

- decls:

  A file of declared option names, one per line: other variables are
  dropped.

- decls_unconstrained:

  Declared names absent from the formula: `"ignore"`, or `"add"` as
  isolated nodes.

- keep_type_prefix:

  Keep the prefixes `boolean_` and `tristate_` (KconfigSampler).

- strip_config_prefix:

  Strip the prefix `CONFIG_`.

- keep_pattern, drop_pattern:

  Regular expressions: names to keep whatever the other rules say, or to
  drop.

- drop_names:

  A file of names to drop, one per line.

- filter_at:

  `"input"`: dropped variables are never queried; `"output"`: query all,
  filter when writing (for testing).

- max_matrix_memory:

  Above this estimate, in GB, the minimal form and the checks use sparse
  algorithms.

- representativeness:

  Count, with the model counter GANAK, the valid configurations and
  those that the graphs allow (turns on `or_graph`). Needs GANAK; see
  [`vp_representativeness()`](https://rheradio.github.io/variplex/reference/vp_representativeness.md).

- ganak:

  The GANAK program: a path, or a name found on the `PATH`.

- legacy:

  Reproduce the output of Strong4VM 1.x.

- quiet:

  Print nothing but warnings and errors. `FALSE` prints the progress of
  the run.

- read:

  Read the results and return the model (`TRUE`), or only return the
  prefix of the files.

## Value

With `read = TRUE`, a model (an object of class `vp_model`, see
[`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md)).
With `read = FALSE`, the prefix of the files written (invisibly): the
path of the output files without their ending.

## Details

- **requires**: selecting `A` always selects `B` (an arrow `A -> B`);

- **excludes**: `A` and `B` are never selected together;

- **at least one** (with `or_graph = TRUE`): every valid configuration
  has `A` or `B`.

It also finds the core features (in every product), the dead features
(in none), the atomic sets (features that are always selected together),
the minimal form of the graphs
([`vp_minimal()`](https://rheradio.github.io/variplex/reference/vp_minimal.md)),
and, with `kernel = TRUE`, the kernel
([`vp_kernel()`](https://rheradio.github.io/variplex/reference/vp_kernel.md)).
The results are written as files (Pajek graphs, lists, a CSV report and
a JSON summary) into `output_dir`, and read back as a model, the object
that every other function of the package takes.

This is the command `strong4vm generate` of the Strong4VM program; every
option of the command line is an argument. Its other sub-commands are
functions of the package: `check` is
[`vp_check()`](https://rheradio.github.io/variplex/reference/vp_check.md),
`expand` is
[`vp_expand()`](https://rheradio.github.io/variplex/reference/vp_expand.md),
`explain` is
[`vp_explain_conflict()`](https://rheradio.github.io/variplex/reference/vp_explain_conflict.md)
and
[`vp_explain_requires()`](https://rheradio.github.io/variplex/reference/vp_explain_requires.md),
and `diff` is
[`vp_compare()`](https://rheradio.github.io/variplex/reference/vp_compare.md)
and
[`vp_changed_links()`](https://rheradio.github.io/variplex/reference/vp_changed_links.md).

## What the graphs cannot show

The graphs hold relationships between **two** features. A rule that
involves three or more features at once (such as "A requires B or C", or
"A, B and C cannot all be selected") is not in any graph, unless it
implies a relationship between two features. Everything the graphs say
is true; what they do not say may still be ruled out by such a rule.
`representativeness = TRUE` measures how much of the model the graphs
leave out (see
[`vp_representativeness()`](https://rheradio.github.io/variplex/reference/vp_representativeness.md)).

## See also

[`vp_read()`](https://rheradio.github.io/variplex/reference/vp_read.md)
to read the files of an earlier run;
[`vp_example()`](https://rheradio.github.io/variplex/reference/vp_example.md)
for the models that come with the package.

Other reading:
[`vp_classify()`](https://rheradio.github.io/variplex/reference/vp_classify.md),
[`vp_example()`](https://rheradio.github.io/variplex/reference/vp_example.md),
[`vp_expand()`](https://rheradio.github.io/variplex/reference/vp_expand.md),
[`vp_features()`](https://rheradio.github.io/variplex/reference/vp_features.md),
[`vp_functions()`](https://rheradio.github.io/variplex/reference/vp_functions.md),
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
band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
band
#> variplex model "miband3"
#>   features: 11 variable (the nodes of the graphs), 8 core, 0 dead
#>   requires: 36 arrows   excludes: 18 lines
#>   at least one: 3 lines
#>   atomic sets: 2 (of two or more features)
vp_features(band)
#> # A tibble: 19 × 2
#>    feature            status  
#>    <chr>              <chr>   
#>  1 Screen             variable
#>  2 TouchScreen        variable
#>  3 OLED               variable
#>  4 CapacityButton     variable
#>  5 ContactlessPayment variable
#>  6 MovementFilter     variable
#>  7 HeartRateSensor    variable
#>  8 BLEv40             variable
#>  9 BLEv42             variable
#> 10 BT40               variable
#> 11 NFC                variable
#> 12 FitnessMonitor     core    
#> 13 SleepTracker       core    
#> 14 VibrateAlert       core    
#> 15 Call               core    
#> 16 Notification       core    
#> 17 Pedometer          core    
#> 18 Accelerometer      core    
#> 19 Bluetooth          core    
vp_links(band, "excludes")
#> # A tibble: 18 × 2
#>    from               to             
#>    <chr>              <chr>          
#>  1 Screen             BT40           
#>  2 TouchScreen        MovementFilter 
#>  3 TouchScreen        BLEv40         
#>  4 TouchScreen        BT40           
#>  5 OLED               BT40           
#>  6 CapacityButton     BT40           
#>  7 ContactlessPayment MovementFilter 
#>  8 ContactlessPayment BLEv40         
#>  9 ContactlessPayment BT40           
#> 10 MovementFilter     HeartRateSensor
#> 11 MovementFilter     BLEv42         
#> 12 MovementFilter     BT40           
#> 13 MovementFilter     NFC            
#> 14 BLEv40             BLEv42         
#> 15 BLEv40             BT40           
#> 16 BLEv40             NFC            
#> 17 BLEv42             BT40           
#> 18 BT40               NFC            

# A Boolean formula in DIMACS format
f <- vp_generate(vp_example("eleven_options.dimacs"), translator = "kmax")
vp_links(f, "requires")
#> # A tibble: 8 × 2
#>   from             to              
#>   <chr>            <chr>           
#> 1 ACPI_INTERPRETER ACPI            
#> 2 ACPI_INTERPRETER NUMA            
#> 3 ACPI_NUMA        ACPI            
#> 4 ACPI_NUMA        ACPI_INTERPRETER
#> 5 ACPI_NUMA        NUMA            
#> 6 IA64_DIG         IA64            
#> 7 IA64_HP_ZX1      IA64            
#> 8 X86_PC           X86             
```
