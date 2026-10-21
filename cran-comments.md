## Submission

This is a new submission.

## Test environments

* local: Ubuntu 24.04 (WSL2), R 4.3.3, GCC 13
* TO DO before submitting: win-builder (`devtools::check_win_devel()`), the macOS builder
  (`devtools::check_mac_release()`), R-hub (`rhub::rhub_check()`, including the sanitizer builds), and the GitHub
  Actions workflow of the package (macOS, Windows, Linux with R devel, release and oldrel).

## R CMD check results

Local (`R CMD check --as-cran`, Ubuntu 24.04, R 4.3.3): 0 errors, 1 warning, 6 notes, all of them from the machine
or the state of the repository, not from the package:

* WARNING `qpdf` is needed: not installed on that machine.
* NOTE new submission; the URLs of the GitHub repository answer 404 until the repository is published.
* NOTE `rsvg` (suggested) not available on that machine; the tests that need it are skipped.
* NOTE unable to verify current time; HTML validation skipped (no `tidy`); `-mno-omit-leaf-frame-pointer` comes from
  the flags with which Ubuntu built R.
* NOTE installed size 65 Mb: `libs` (50 Mb, with debugging symbols) holds a SAT solver (Glucose 3.0), a backbone
  solver and the ANTLR 4 C++ runtime, which parses the Universal Variability Language; `doc` (11 Mb) holds the
  vignettes, with their figures embedded.

TO DO: the same on win-builder, the macOS builder, R-hub and GitHub Actions.

## Reverse dependencies

This is a new package, so there are no reverse dependencies.

## Notes for the reviewers

* The C++ code in `src/` comes from the Strong4VM project and the BoneDigger backbone solver (whose first
  author is the maintainer) and from third parties; their copyright holders are listed in `Authors@R` and in
  `inst/COPYRIGHTS`. It writes to the R console only through `Rprintf` and `REprintf`, and never calls `exit()` or
  `abort()`: errors become R errors.
* GANAK, an optional model counter, is only used when the user asks for it (`vp_generate(representativeness = TRUE)`)
  and has installed it; examples and tests skip it otherwise.
* Examples, tests and vignettes write only to `tempdir()`. The vignettes are precomputed (their sources run with
  data and tools that CRAN does not have), so building them needs no computation.
