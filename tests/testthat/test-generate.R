# vp_generate(): the engine of Strong4VM as an R function. The files it writes
# must be those of the command line (tests/expected holds the outputs that the
# minimal test suite of Strong4VM checks), and its arguments, errors and
# warnings must behave as documented.

same_file <- function(a, b) {
  identical(readLines(a, warn = FALSE), readLines(b, warn = FALSE))
}
expected <- function(f) testthat::test_path("expected", f)

test_that("a DIMACS formula gives the files that the command line gives", {
  out <- withr::local_tempdir()
  prefix <- suppressWarnings(vp_generate(
    vp_example("eleven_options.dimacs"),
    output_dir = out,
    or_graph = TRUE,
    kernel = TRUE,
    read = FALSE
  ))
  expect_equal(
    prefix,
    file.path(normalizePath(out, winslash = "/"), "eleven_options")
  )
  for (f in c(
    "requires.net",
    "excludes.net",
    "atleastone.net",
    "core.txt",
    "dead.txt",
    "atomic.txt",
    "kernel_classes.txt"
  )) {
    expect_true(
      same_file(
        paste0(prefix, "__", f),
        expected(paste0("eleven_options__", f))
      ),
      info = f
    )
  }
  for (f in c(
    "variables.csv",
    "summary.json",
    "requires_skeleton.net",
    "excludes_primitive.net",
    "atleastone_primitive.net",
    "kernel_requires.net",
    "kernel_excludes.net"
  )) {
    expect_gt(file.size(paste0(prefix, "__", f)), 0)
  }
})

test_that(
  paste0(
    "a UVL model gives the files that the command line gives, and keep_dimacs ",
    "keeps the formula"
  ),
  {
    out <- withr::local_tempdir()
    prefix <- vp_generate(
      vp_example("miband3_realized.uvl"),
      output_dir = out,
      keep_dimacs = TRUE,
      read = FALSE
    )
    for (f in c(
      "requires.net",
      "excludes.net",
      "core.txt",
      "dead.txt",
      "atomic.txt"
    )) {
      expect_true(
        same_file(
          paste0(prefix, "__", f),
          expected(paste0("miband3_realized__", f))
        ),
        info = f
      )
    }
    expect_true(any(grepl("^p cnf ", readLines(paste0(prefix, ".dimacs")))))
    expect_false(file.exists(paste0(prefix, "__atleastone.net")))
  }
)

test_that(
  paste0(
    "the graphs do not depend on the number of threads, nor on the extension ",
    ".cnf"
  ),
  {
    one <- suppressWarnings(vp_generate(
      vp_example("eleven_options.dimacs"),
      or_graph = TRUE,
      threads = 1
    ))
    cnf <- file.path(withr::local_tempdir(), "eleven.cnf")
    file.copy(vp_example("eleven_options.dimacs"), cnf)
    expect_identical(suppressWarnings(vp_generate(cnf))$requires, one$requires)
    # glibc keeps the stacks of finished threads for reuse, which valgrind
    # reports as possibly lost memory
    skip_if(on_valgrind(), "threads under valgrind")
    two <- suppressWarnings(vp_generate(
      vp_example("eleven_options.dimacs"),
      or_graph = TRUE,
      threads = 2
    ))
    expect_identical(one$requires, two$requires)
    expect_identical(one$excludes, two$excludes)
    expect_identical(one$atleastone, two$atleastone)
  }
)

test_that("the model is complete, and each run has a folder of its own", {
  band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE, kernel = TRUE)
  expect_s3_class(band, "vp_model")
  expect_false(is.null(band$atleastone))
  expect_false(is.null(band$summary))
  expect_true(all(vp_check(band)$holds))
  plain <- vp_generate(vp_example("miband3.uvl"))
  expect_null(plain$atleastone) # no file of the first run was read
  expect_false(identical(dirname(band$prefix), dirname(plain$prefix)))
  expect_output(print(band), "variplex model \"miband3\"")
})

test_that("options reach the engine", {
  m <- vp_generate(
    vp_example("miband3.uvl"),
    fixed_nodes = "keep",
    abstract = "keep",
    read = FALSE
  )
  net <- readLines(paste0(m, "__requires.net"))
  expect_true(any(grepl('"SmartWatch"', net))) # the abstract root is a node now
  expect_true(any(grepl('"Pedometer"', net))) # and so is a core feature
  s <- jsonlite::fromJSON(paste0(m, "__summary.json"))
  expect_match(s$command_line, "--fixed-nodes keep", fixed = TRUE)
  kept <- suppressWarnings(vp_generate(
    vp_example("eleven_options.dimacs"),
    drop_pattern = "^IA64"
  ))
  expect_false(any(grepl("^IA64", vp_features(kept)$feature)))
  expect_no_error(vp_generate(
    vp_example("miband3.uvl"),
    tseitin = TRUE,
    mig = FALSE,
    minimal = FALSE,
    atomic = FALSE,
    check = FALSE,
    read = FALSE
  ))
})

test_that("vp_classify() classifies without solving", {
  v <- vp_classify(vp_example("eleven_options.dimacs"), translator = "kmax")
  expect_s3_class(v, "tbl_df")
  expect_equal(nrow(v), 11)
  expect_error(
    vp_classify(vp_example("eleven_options.dimacs"), nonsense = 1),
    "Unknown argument"
  )
})

test_that("wrong input gets a clear error, with a class", {
  expect_error(vp_generate("no/such/file.uvl"), "does not exist")
  bad <- file.path(withr::local_tempdir(), "model.txt")
  writeLines("x", bad)
  expect_error(vp_generate(bad), "must be a .uvl, .dimacs or .cnf file")
  broken <- file.path(withr::local_tempdir(), "broken.dimacs")
  writeLines(c("p cnf 2 1", "1 x 0"), broken)
  expect_error(vp_generate(broken), class = "variplex_error")
  void <- file.path(withr::local_tempdir(), "void.dimacs")
  writeLines(c("c 1 A", "p cnf 1 2", "1 0", "-1 0"), void)
  err <- expect_error(
    suppressWarnings(vp_generate(void)),
    class = "variplex_void_model"
  )
  expect_equal(err$exit_code, 3L)
  expect_error(vp_generate(vp_example("miband3.uvl"), threads = 0), "threads")
  expect_error(
    vp_generate(vp_example("miband3.uvl"), tristate = "nope"),
    "should be one of"
  )
  expect_error(
    vp_generate(vp_example("miband3.uvl"), decls = "no/such/file"),
    "does not exist"
  )
  expect_error(
    vp_generate(
      vp_example("miband3.uvl"),
      representativeness = TRUE,
      ganak = "no-such-ganak-program"
    ),
    "GANAK"
  )
})

test_that(
  paste0(
    paste0(
      "a UVL constraint that cannot be translated is a warning, or an error ",
      "with "
    ),
    "strict_uvl"
  ),
  {
    uvl <- file.path(withr::local_tempdir(), "m.uvl")
    writeLines(
      c(
        "features",
        "\tRoot",
        "\t\toptional",
        "\t\t\tA",
        "\t\t\tB",
        "constraints",
        "\tA => Imported.C"
      ),
      uvl
    )
    expect_warning(vp_generate(uvl, read = FALSE), "Imported")
    expect_error(
      suppressWarnings(vp_generate(uvl, strict_uvl = TRUE)),
      class = "variplex_strict_uvl"
    )
  }
)

test_that("vp_history() and vp_example()", {
  h <- vp_history(
    vp_example(c("miband1_realized.uvl", "miband2_realized.uvl")),
    versions = c("one", "two")
  )
  expect_equal(levels(h$version), c("one", "two"))
  expect_equal(h$model[[2]]$name, "two")
  expect_error(
    vp_history(vp_example("miband1_realized.uvl"), versions = c("a", "b")),
    "one name"
  )
  expect_true("miband3.uvl" %in% vp_example())
  expect_error(vp_example("nope.uvl"), "no example file")
})

test_that("functions with a seed leave the random state as it was", {
  band <- vp_generate(vp_example("miband3.uvl"))
  withr::local_seed(42)
  before <- .Random.seed
  vp_communities(band, seed = 7)
  vp_baseline(band, runs = 3)
  expect_identical(.Random.seed, before)
  withr::with_seed(1, {
    a <- vp_communities(band, seed = 7)
  })
  expect_identical(a, vp_communities(band, seed = 7))
})

test_that("vp_plot() draws with DiagrammeR, or says what to install", {
  band <- vp_generate(vp_example("miband3.uvl"), or_graph = TRUE)
  skip_if_not_installed("DiagrammeR")
  w <- vp_plot(vp_minimal(band))
  expect_s3_class(w, "htmlwidget")
  # drawn with fdp
  expect_s3_class(vp_plot(vp_minimal(band), layout = "sfdp"), "htmlwidget")
  expect_s3_class(
    vp_plot_compare(vp_generate(vp_example("miband3_planned.uvl")), band),
    "htmlwidget"
  )
  expect_error(vp_plot(band, file = "x.jpg"), "must end in")
  skip_if_not_installed("DiagrammeRsvg")
  skip_if_v8_unusable()
  f <- vp_plot(
    vp_minimal(band),
    file = file.path(withr::local_tempdir(), "band.svg")
  )
  expect_match(paste(readLines(f, warn = FALSE), collapse = ""), "<svg")
  skip_if_not_installed("rsvg")
  f <- vp_plot(
    vp_minimal(band),
    file = file.path(withr::local_tempdir(), "band.pdf")
  )
  expect_identical(rawToChar(readBin(f, "raw", 5)), "%PDF-")
})
