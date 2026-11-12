## Resubmission

This is a resubmission. In response to the comments of Leonore Hochhauser:

* DESCRIPTION: single quotes are now used only for software names ('KMax', 'KConfigReader', 'KconfigSampler',
  'TraVarT', 'Glucose'), not for languages or file formats (UVL, DIMACS, Pajek).
* DESCRIPTION: the reference to the companion data set now gives authors and year:
  Heradio et al. (2026) <doi:10.5281/zenodo.17277788>.
* Authors@R: we went through every copyright notice and `@author` tag in `src/` and added the ones that were
  missing: Sam Harwell (ctb, cph) and Terence Parr (now also cph), named in the headers of the ANTLR 4 C++
  runtime, and the contributors of the UVL grammar (cph), from which the parser in `src/s4/uvl2dimacs/parser` was
  generated. Every author, contributor and copyright holder of the code in `src/` is now in `Authors@R`, with the
  component they wrote, and `inst/COPYRIGHTS` gives each component's copyright notice and licence.
* License: changed from MIT to LGPL-3. While checking authorship we found that the generated UVL parser derives
  from the UVL grammar, which is under the LGPL-3.0; the package as a whole is therefore distributed under the
  LGPL-3. The other components (MIT and BSD 3-clause) keep their own licences, which are compatible with it, and
  `inst/COPYRIGHTS` lists them.

## Submission

This is a new submission.

## Test environments

* local: Ubuntu 24.04 (WSL2), R 4.3.3, GCC 13
* win-builder: R 4.6.1 (release), Windows
* GitHub Actions: Windows and macOS (R release); Ubuntu (R devel, release and oldrel-1)
* R-hub: Linux, Windows and macOS (R devel), clang ASan/UBSan and valgrind

## R CMD check results

0 errors | 0 warnings | notes as follows.

Local (`R CMD check --as-cran`, Ubuntu 24.04, R 4.3.3): 5 notes.

* New submission.
* Installed size 65 Mb: `libs` (50 Mb, with debugging symbols) holds a SAT solver (Glucose 3.0), a backbone solver
  and the ANTLR 4 C++ runtime, which parses the Universal Variability Language; `doc` (11 Mb) holds the vignettes,
  with their figures embedded.
* Unable to verify current time: a limitation of that machine.
* Non-portable flag `-mno-omit-leaf-frame-pointer`: it comes from the flags with which Ubuntu built R, not from the
  package's `Makevars`.
* HTML validation of the manual (`<unsupported>` in `vp_read.Rd`, `<tab>` in `vp_rename_candidates.Rd`): fixed
  after these checks; both are now code.

win-builder (R 4.6.1): 2 notes.

* New submission. "Possibly misspelled words in DESCRIPTION": combinatorial, satisfiability and tibbles are spelt
  correctly.
* HTML validation of the manual: the same as above, now fixed.

GitHub Actions and R-hub: all checks passed.

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
