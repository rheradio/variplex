# Sourced by every vignettes/*.Rmd.orig when it is precomputed
# (vignettes/precompute.R); not part of the package.
#
# vp_setup(name) loads the packages, sets the options of the output, and gives
# the document its facts: the numbers quoted in the text (`r facts$Name`). A
# fact is set with fact(name, value) in a chunk, possibly after the text that
# quotes it, so the first pass of precompute.R saves them and the second one
# quotes them. The facts of the two manuals of Strong4VM (their facts.tex) are
# the defaults, for the numbers that come from runs that the vignettes cannot
# repeat (timings, Linux, GANAK). vp_finish() saves the facts and writes the
# references that the document cites.

suppressPackageStartupMessages({
  library(variplex)
  library(dplyr)
  library(ggplot2)
})
options(
  cli.unicode = FALSE,
  width = 100,
  pillar.bold = FALSE,
  crayon.enabled = FALSE,
  warn = 1,
  pillar.min_title_chars = 12,
  digits = 4,
  tibble.print_min = 10
)
Sys.setenv(LANG = "en")
theme_set(theme_minimal(base_size = 11))

strong4_vm <- Sys.getenv("STRONG4VM_WORKSPACE", "/mnt/c/tools/strong4vm")
ganak <- Sys.getenv("GANAK", path.expand("~/s4vm_work/tools/ganak/ganak"))
if (file.exists(ganak)) {
  Sys.setenv(
    PATH = paste(dirname(ganak), Sys.getenv("PATH"), sep = .Platform$path.sep)
  )
}

.read_tex_facts <- function(path) {
  if (!file.exists(path)) {
    return(list())
  }
  l <- readLines(path, warn = FALSE, encoding = "UTF-8")
  m <- regmatches(
    l,
    regexec("^\\\\newcommand\\{\\\\F([A-Za-z0-9]+)\\}\\{(.*)\\}\\s*$", l)
  )
  m <- m[lengths(m) == 3]
  v <- vapply(m, `[`, "", 3)
  v <- gsub("\\\\_", "_", v)
  v <- gsub("\\\\%", "%", v)
  v <- gsub("~", " ", v, fixed = TRUE)
  v <- gsub("\\\\(emph|textit|textbf|texttt)\\{([^}]*)\\}", "\\2", v)
  v <- gsub("--", "–", v, fixed = TRUE)
  stats::setNames(as.list(v), vapply(m, `[`, "", 2))
}

vp_setup <- function(name) {
  g <- globalenv()
  assign(".facts_file", paste0("facts_", name, ".rds"), envir = g)
  defaults <- c(
    .read_tex_facts(file.path(strong4_vm, "user_manual", "facts.tex")),
    .read_tex_facts(file.path(strong4_vm, "r_analysis_manual", "facts.tex"))
  )
  saved <- if (file.exists(g$.facts_file)) readRDS(g$.facts_file) else list()
  assign("facts", utils::modifyList(defaults, saved), envir = g)
  assign(
    ".doc",
    paste(
      readLines(paste0(name, ".Rmd.orig"), warn = FALSE, encoding = "UTF-8"),
      collapse = "\n"
    ),
    envir = g
  )
  invisible()
}

fact <- function(name, value, digits = 2) {
  if (
    is.numeric(value) &&
      length(value) == 1 &&
      !is.na(value) &&
      value != round(value)
  ) {
    value <- formatC(value, format = "f", digits = digits)
  } else if (is.numeric(value)) {
    value <- format(value, big.mark = ",", scientific = FALSE, trim = TRUE)
  }
  f <- get("facts", envir = globalenv())
  f[[name]] <- paste(value, collapse = ", ")
  assign("facts", f, envir = globalenv())
  invisible()
}
pct <- function(x, digits = 0) formatC(100 * x, format = "f", digits = digits)

vp_finish <- function() {
  saveRDS(
    get("facts", envir = globalenv()),
    get(".facts_file", envir = globalenv())
  )
  invisible()
}

# The list of references that the document cites, for a chunk with results =
# "asis" at its end.
vp_references <- function() {
  refs <- utils::read.delim(
    "refs.tsv",
    header = FALSE,
    quote = "",
    col.names = c("key", "text"),
    encoding = "UTF-8"
  )
  keys <- unique(regmatches(
    .doc,
    gregexpr("(?<=\\(#ref-)[^)]+", .doc, perl = TRUE)
  )[[1]])
  missing <- setdiff(keys, refs$key)
  if (length(missing)) {
    stop(
      "references without an entry in refs.tsv: ",
      paste(missing, collapse = ", ")
    )
  }
  if (!length(keys)) {
    return(invisible())
  }
  r <- refs[match(keys, refs$key), ]
  r <- r[order(sub("^[^,]*?([^ ,.]+),.*$", "\\1", r$text), r$text), ]
  cat(
    "# References\n\n",
    paste0('<span id="ref-', r$key, '"></span>', r$text, "\n\n"),
    sep = ""
  )
}

# The runs and data that the manual of the R functions of Strong4VM used, in the
# same folders, so that the code of the vignettes can be that of the manual.
# Every run is made by vp_generate(); the BusyBox history comes with the
# package; Linux 3.13 is a run that takes about ten minutes, read from the
# workspace of Strong4VM when it is there.
vp_manual_data <- function() {
  ex <- function(f) vp_example(f)
  rep <- nzchar(Sys.which("ganak"))
  vp_generate(
    ex("miband3_realized.uvl"),
    output_dir = "out",
    or_graph = TRUE,
    kernel = TRUE,
    keep_dimacs = TRUE,
    representativeness = rep,
    read = FALSE
  )
  vp_generate(
    ex("miband3_planned.uvl"),
    output_dir = "planned",
    or_graph = TRUE,
    read = FALSE
  )
  vp_generate(ex("miband3_realized.uvl"), output_dir = "plain", read = FALSE)
  vp_generate(
    ex("miband3_battery.uvl"),
    output_dir = "battery",
    or_graph = TRUE,
    kernel = TRUE,
    keep_dimacs = TRUE,
    representativeness = rep,
    read = FALSE
  )
  vp_generate(
    ex("uClibc.uvl"),
    output_dir = "uclibc",
    or_graph = TRUE,
    read = FALSE
  )
  dir.create("data", showWarnings = FALSE)
  dir.create("models", showWarnings = FALSE)
  file.copy(
    ex(c(
      "miband3_realized.uvl",
      "miband8_realized.uvl",
      "uClibc.uvl",
      "miband3_products.csv",
      "miband3_battery_products.csv",
      "sample.csv"
    )),
    "data",
    overwrite = TRUE
  )
  file.copy(ex("busybox"), "data", recursive = TRUE, overwrite = TRUE)
  file.copy(ex("miband8_refactored.uvl"), "models", overwrite = TRUE)
  linux <- file.path(strong4_vm, "r_analysis_manual", "data", "linux")
  if (dir.exists(linux)) {
    file.copy(linux, "data", recursive = TRUE, overwrite = TRUE)
  }
  invisible()
}
vp_clean_manual_data <- function() {
  unlink(
    c(
      "out",
      "planned",
      "plain",
      "battery",
      "uclibc",
      "data",
      "models",
      "evolution",
      "refactor"
    ),
    recursive = TRUE
  )
}

# The charts of the manual were saved as PDF files for LaTeX; in a vignette they
# are shown.
save_chart <- function(p, name, width = 6.3, height = 3) print(p)

# The objects that the sections of the manual shared, for the vignettes that
# hold only some of those sections.
vp_manual_models <- function() {
  g <- globalenv()
  # the internal helpers some hidden chunks use
  ns <- asNamespace("variplex")
  for (f in ls(ns, all.names = TRUE, pattern = "^\\.vp_")) {
    assign(f, get(f, envir = ns), envir = g)
  }
  band <- vp_read("out/miband3_realized")
  gens <- c(
    "miband1",
    "miband1s",
    "miband2",
    "miband3",
    "miband4",
    "miband6",
    "miband8"
  )
  history <- vp_history(
    vp_example(paste0(gens, "_realized.uvl")),
    versions = gens,
    or_graph = TRUE
  )
  files <- list.files("data/busybox", "__requires.net$", full.names = TRUE)
  prefixes <- sub("__requires.net$", "", files)
  busybox <- vp_read_history(
    prefixes,
    versions = sub(".*busybox_", "", prefixes)
  )
  objs <- list(
    band = band,
    band_min = vp_minimal(band),
    band_plain = vp_read("plain/miband3_realized"),
    gens = gens,
    history = history,
    busybox = busybox,
    bb = busybox$model[[nrow(busybox)]],
    products = read.csv("data/miband3_products.csv"),
    sample = read.csv("data/sample.csv"),
    planned = vp_read("planned/miband3_planned"),
    battery = vp_read("battery/miband3_battery"),
    uclibc = vp_read("uclibc/uClibc"),
    tree_u = vp_read_uvl_tree("data/uClibc.uvl"),
    tree3 = vp_read_uvl_tree("data/miband3_realized.uvl"),
    band8 = history$model[[7]],
    tree8 = vp_read_uvl_tree("data/miband8_realized.uvl"),
    teams = tibble::tibble(
      feature = c(
        "Screen",
        "TouchScreen",
        "OLED",
        "CapacityButton",
        "ContactlessPayment",
        "NFC",
        "MovementFilter",
        "HeartRateSensor",
        "BLEv40",
        "BLEv42",
        "BT40"
      ),
      team = c(
        "display",
        "display",
        "display",
        "display",
        "payment",
        "payment",
        "sensors",
        "sensors",
        "bluetooth",
        "bluetooth",
        "bluetooth"
      )
    )
  )
  if (file.exists("data/linux/linux_3.13__requires.net")) {
    objs$linux <- vp_read("data/linux/linux_3.13", name = "linux-3.13")
  }
  for (n in names(objs)) {
    assign(n, objs[[n]], envir = g)
  }
  invisible()
}
