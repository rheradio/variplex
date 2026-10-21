# Package-level state and small helpers used across files.

# Results computed once per model (matrices, merged graphs, expansions); see
# .vp_key() in read.R.
.vp_cache <- new.env(parent = emptyenv())

# Seeds the random numbers for the rest of the calling function, and puts back
# the random state of the session when that function ends, so that a function of
# the package never changes the user's own random draws.
.vp_local_seed <- function(seed, envir = parent.frame()) {
  old <- get0(".Random.seed", envir = globalenv(), inherits = FALSE)
  restore <- function() {
    if (is.null(old)) {
      if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
        rm(".Random.seed", envir = globalenv())
      }
    } else {
      assign(".Random.seed", old, envir = globalenv()) # nolint
    }
  }
  do.call(on.exit, list(bquote(.(restore)()), add = TRUE), envir = envir)
  set.seed(seed)
}

# Column names used in dplyr verbs (non-standard evaluation).
utils::globalVariables(c(
  "feature",
  "other_team",
  "model",
  "step",
  "from",
  "to",
  "written_gained",
  "written_lost",
  "gained",
  "lost"
))

.onUnload <- function(libpath) library.dynam.unload("variplex", libpath)

# Sorting that does not depend on the locale of the user (radix sorting compares
# bytes), and that accepts NULL.
.vp_sort <- function(x, decreasing = FALSE) {
  if (is.null(x)) x else sort(x, decreasing = decreasing, method = "radix")
}
