# ==============================================================================
# Precomputes the vignettes: knits each vignettes/<name>.Rmd.orig into
# vignettes/<name>.Rmd, with the output of every chunk written into the
# document, so that R CMD build and CRAN only have to convert Markdown. Some
# vignettes need what CRAN does not have: the model counter GANAK, the time to
# analyse Linux, the BusyBox and Linux graphs of the dataset of Strong4VM on
# Zenodo.
#
#     Rscript vignettes/precompute.R [names...]
#
# (from the root of the package; the package must be installed)
#
# Environment: GANAK (the model counter), VARIPLEX_LINUX (the prefix of a run of
# Linux 3.13 with or_graph = TRUE). Each vignette is knitted twice: its facts
# (numbers quoted in the text, set with fact()) are computed in the first pass
# and quoted in the second, as LaTeX does with its references.
# ==============================================================================
args <- commandArgs(trailingOnly = TRUE)
old <- setwd("vignettes")
on.exit(setwd(old))
origs <- list.files(".", "\\.Rmd\\.orig$")
if (length(args)) {
  origs <- origs[sub("\\.Rmd\\.orig$", "", origs) %in% args]
}
for (o in origs) {
  name <- sub("\\.Rmd\\.orig$", "", o)
  message("== ", name)
  for (pass in 1:2) {
    knitr::opts_chunk$set(
      fig.path = file.path("figures", paste0(name, "-")),
      comment = "#>",
      collapse = TRUE,
      dev = "svg",
      error = FALSE,
      fig.width = 7,
      fig.height = 3.5
    )
    knitr::knit(
      o,
      paste0(name, ".Rmd"),
      quiet = TRUE,
      envir = new.env(parent = globalenv())
    )
  }
  # no paths of this machine in the output: the folder of the examples, and the
  # folder the vignette ran in
  rmd <- readLines(paste0(name, ".Rmd"), encoding = "UTF-8")
  ext <- normalizePath(
    system.file("extdata", package = "variplex"),
    winslash = "/"
  )
  rmd <- gsub(paste0(ext, "/"), "", rmd, fixed = TRUE)
  rmd <- gsub(
    paste0(normalizePath(".", winslash = "/"), "/"),
    "",
    rmd,
    fixed = TRUE
  )
  rmd <- gsub("/tmp/Rtmp[A-Za-z0-9]+/variplex_[0-9a-f]+/", "", rmd)
  writeLines(rmd, paste0(name, ".Rmd"), useBytes = TRUE)
}
unlink(list.files(".", "^facts_.*\\.rds$"))
