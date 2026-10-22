# The models of the tests, computed once per test run: the examples of the
# package, a few written here, and random formulas, each with the valid
# configurations of its formula listed by the oracle (helper-1-oracle.R).
#
#   NOT_CRAN=true             all the random formulas (12; on CRAN, 4)
#   VARIPLEX_FUZZ=N           N random formulas
#   VARIPLEX_STRONG4VM=PATH   the program strong4vm: the tests then also compare
#                             with its sub-command diff
#   GANAK=PATH                the model counter GANAK (or ganak on the PATH):
#                             the tests of representativeness

program <- Sys.getenv("VARIPLEX_STRONG4VM")
if (nzchar(program) && !file.exists(program)) {
  program <- ""
}

work <- withr::local_tempdir("vptests", .local_envir = testthat::teardown_env())
examples <- system.file("extdata", package = "variplex")


fixtures <- list() # name -> list(prefix, formula, uvl (or NULL))
add <- function(name, model, ...) {
  prefix <- run_vp(model, file.path(work, name), ...)
  formula <- if (grepl("\\.uvl$", model)) paste0(prefix, ".dimacs") else model
  # nolint start: assignment_linter. A closure updates its parent.
  fixtures[[name]] <<- list(
    prefix = prefix,
    formula = formula,
    uvl = if (grepl("\\.uvl$", model)) model else NULL
  )
  # nolint end
}
gens <- c(
  "miband1",
  "miband1s",
  "miband2",
  "miband3",
  "miband4",
  "miband6",
  "miband8"
)
for (g in gens) {
  add(g, file.path(examples, paste0(g, "_realized.uvl")))
}
add("miband3_planned", file.path(examples, "miband3_planned.uvl"))
suppressWarnings(add("eleven", file.path(examples, "eleven_options.dimacs")))
add("uclibc", file.path(examples, "uClibc.uvl"))

# a band with a rule over three features (it changes no relationship between two
# features)
battery <- file.path(work, "miband3_battery.uvl")
writeLines(
  c(
    readLines(file.path(examples, "miband3_realized.uvl")),
    "\t!(NFC & HeartRateSensor & TouchScreen)"
  ),
  battery
)
add("battery", battery)
# three optional features and one rule over the three: no relationship at all
tiny <- file.path(work, "tiny_band.uvl")
writeLines(
  c(
    "features",
    "\tBand {abstract}",
    "\t\toptional",
    "\t\t\tGPS",
    "\t\t\tNFC",
    "\t\t\tAlwaysOnDisplay",
    "constraints",
    "\t!(GPS & NFC & AlwaysOnDisplay)"
  ),
  tiny
)
add("tiny", tiny)

# random formulas: requirements, conflicts, at-least-one clauses, rules over
# three features, units (core and dead features) and equivalences (atomic sets),
# on 5 to 12 variables; unsatisfiable ones are drawn again.
n_fuzz <- if (nzchar(Sys.getenv("VARIPLEX_FUZZ"))) {
  as.integer(Sys.getenv("VARIPLEX_FUZZ"))
} else if (identical(Sys.getenv("NOT_CRAN"), "true")) {
  12L
} else {
  4L
}
random_formula <- function(path) {
  repeat {
    nv <- sample(5:12, 1)
    cl <- list()
    for (k in seq_len(sample(round(nv * 0.6):round(nv * 1.6), 1))) {
      v <- sample(nv, 3)
      cl[[length(cl) + 1]] <- switch(
        sample(
          c("req", "exc", "or", "three", "unit", "eq"),
          1,
          prob = c(0.35, 0.22, 0.1, 0.18, 0.05, 0.1)
        ),
        req = c(-v[1], v[2]),
        exc = c(-v[1], -v[2]),
        or = c(v[1], v[2]),
        three = v * sample(c(-1, 1), 3, replace = TRUE),
        unit = v[1] * sample(c(-1, 1), 1),
        eq = list(c(-v[1], v[2]), c(-v[2], v[1]))
      )
    }
    cl <- lapply(
      unlist(
        lapply(cl, function(x) if (is.list(x)) x else list(x)),
        recursive = FALSE
      ),
      as.integer
    )
    f <- list(n = nv, names = paste0("f", seq_len(nv)), clauses = cl)
    x_mat <- enumerate(f)
    if (!is.null(x_mat) && nrow(x_mat) > 0) break
  }
  writeLines(
    c(
      paste0("c ", seq_len(nv), " f", seq_len(nv)),
      sprintf("p cnf %d %d", nv, length(cl)),
      vapply(cl, function(c) paste(c(c, 0), collapse = " "), "")
    ),
    path
  )
  path
}
withr::with_seed(
  20261014,
  for (k in seq_len(n_fuzz)) {
    suppressWarnings(add(
      sprintf("fuzz%02d", k),
      random_formula(file.path(work, sprintf("fuzz%02d.dimacs", k)))
    ))
  }
)

models <- lapply(fixtures, function(f) vp_read(f$prefix))

# GANAK, for representativeness
ganak <- Sys.getenv("GANAK", unset = Sys.which("ganak"))
rep_models <- list()
if (nzchar(ganak) && file.exists(ganak)) {
  for (n in c("miband3", "battery", "eleven", "miband2", "miband3_planned")) {
    src <- if (!is.null(fixtures[[n]]$uvl)) {
      fixtures[[n]]$uvl
    } else {
      fixtures[[n]]$formula
    }
    rep_models[[n]] <- vp_read(suppressWarnings(run_vp(
      src,
      file.path(work, paste0(n, "_rep")),
      representativeness = TRUE,
      ganak = ganak
    )))
  }
}

# the oracle: the valid configurations of each formula, on the variable features
# of the graphs
oracle <- list()
for (n in names(fixtures)) {
  f <- read_dimacs(fixtures[[n]]$formula)
  if (f$n > 40) {
    next
  }
  x_mat <- enumerate(f, max = 300000)
  if (is.null(x_mat)) {
    next
  }
  m <- models[[n]]
  vars <- m$features$feature[m$features$status == "variable"]
  oracle[[n]] <- list(
    all = x_mat,
    T = truth(x_mat[, vars, drop = FALSE]),
    V = vars
  )
}

# On CRAN the loops over every model run on a few representative ones (an
# example with every kind of link, a rule over three features, a formula, two
# random formulas), so that the tests take about a minute; with NOT_CRAN=true
# they run on all of them.
on_cran <- !identical(Sys.getenv("NOT_CRAN"), "true")
pick <- function(names) {
  if (on_cran) {
    intersect(
      names,
      c("miband3", "battery", "tiny", "eleven", "fuzz01", "fuzz02")
    )
  } else {
    names
  }
}

# Valgrind puts its own libraries in LD_PRELOAD of the program it runs.
on_valgrind <- function() {
  grepl("vgpreload", Sys.getenv("LD_PRELOAD"), fixed = TRUE)
}

# V8 (used by DiagrammeRsvg to write SVG files) aborts under AddressSanitizer,
# whose fake stacks break its stack-limit checks; under valgrind, V8, rsvg and
# the fonts they load report leaks of their own: those checks skip the tests
# that write drawings with them.
skip_if_v8_unusable <- function() {
  makeconf <- file.path(R.home("etc"), "Makeconf")
  sanitized <- file.exists(makeconf) &&
    any(grepl("-fsanitize", readLines(makeconf, warn = FALSE), fixed = TRUE))
  sanitized <- sanitized ||
    nzchar(Sys.getenv("ASAN_OPTIONS")) ||
    nzchar(Sys.getenv("UBSAN_OPTIONS"))
  testthat::skip_if(
    sanitized || on_valgrind(),
    "V8 and rsvg do not run cleanly under sanitizers or valgrind"
  )
}
