# ==============================================================================
# Copies the C++ engine of Strong4VM into src/ and adapts it to R.
#
#     Rscript tools/sync_cpp.R [path/to/strong4vm]
#
# (default: ../strong4vm/strong4vm; run it from the root of variplex)
#
# Strong4VM stays the source of truth: never edit src/s4/ or src/antlr4/ by
# hand; change Strong4VM, then run this script again. It
#   1. copies the sources that the engine needs (no main(), no build products)
#   into src/s4/ (the same folders as in
#      Strong4VM, so that relative #includes still work) and the ANTLR 4 C++
#      runtime into src/antlr4/;
#   2. rewrites what R does not allow in compiled code: output to std::cout,
#   std::cerr, stdout and stderr (it goes to
#      the R console through src/vp_io.h), and exit() or abort() (they throw an
#      exception, which becomes an R error);
#   3. applies a few patches by hand (each one checks that the code it replaces
#   is still there, and stops if not); 4. writes src/Makevars and
#   src/Makevars.win from tools/Makevars.in and tools/Makevars.win.in, with the
#   list of
#      objects to compile.
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)
from <- normalizePath(
  if (length(args)) args[1] else "../strong4vm/strong4vm",
  mustWork = TRUE
)
pkg <- normalizePath(".", mustWork = TRUE)
if (
  !file.exists(file.path(pkg, "DESCRIPTION")) ||
    !grepl("^Package: variplex", readLines(file.path(pkg, "DESCRIPTION"), 1))
) {
  stop("Run this script from the root folder of variplex.")
}
src <- file.path(pkg, "src")

# ---------------------------------------------------------------------- 1. copy
bd <- "uvl2dimacs/backbone_solver/src"
gl <- file.path(bd, "sat_solvers/glucose_3_0")
sets <- list(
  # folder of Strong4VM, file pattern, files to leave out
  list("api/include/strong4vm", "\\.hh$"),
  list("api/src", "\\.cc$"),
  list("cli", "^Args\\.(cc|hh)$"),
  list("dimacs2graphs/api", "\\.(cc|hh)$", "api_example.cc"),
  list("dimacs2graphs/core", "\\.(cc|hh)$"),
  list("dimacs2graphs/filter", "\\.(cc|hh)$"),
  list("dimacs2graphs/graphs", "\\.(cc|hh)$"),
  list("dimacs2graphs/io", "\\.(cc|hh)$"),
  list("uvl2dimacs/api/include/uvl2dimacs", "\\.hh$"),
  list("uvl2dimacs/api/src", "\\.cc$"),
  list("uvl2dimacs/generator/include", "\\.hh$"),
  list("uvl2dimacs/generator/src", "\\.cc$"),
  list("uvl2dimacs/parser/include", "\\.h$"),
  list("uvl2dimacs/parser/src", "\\.cpp$"),
  list(file.path(bd, "api"), "\\.(cc|hh)$", "api_example.cc"),
  list(file.path(bd, "io"), "\\.(cc|hh)$"),
  list(file.path(bd, "detectors"), "\\.(cc|hh)$"),
  list(file.path(bd, "data_structures"), "\\.(cc|hh)$"),
  list(file.path(bd, "sat_interface"), "\\.(cc|hh)$"),
  list(gl, "^(LICENSE|README\\.md)$"),
  list(file.path(gl, "core"), "\\.(cc|h)$"),
  list(file.path(gl, "utils"), "\\.(cc|h)$"),
  list(file.path(gl, "mtl"), "\\.h$"),
  list(file.path(bd, "sat_solvers/minisat_2_2_0"), "^LICENSE$")
)
# headers only: the type vocabulary of BoneDigger
minisat <- file.path(bd, "sat_solvers/minisat_2_2_0/minisat")
antlr <- "uvl2dimacs/third_party/runtime/src"

unlink(file.path(src, c("s4", "antlr4")), recursive = TRUE)
copy <- function(rel_from, rel_to = rel_from, root_to = file.path(src, "s4")) {
  to <- file.path(root_to, rel_to)
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  stopifnot(file.copy(file.path(from, rel_from), to, overwrite = TRUE))
  to
}
copied <- character(0)
for (s in sets) {
  files <- list.files(file.path(from, s[[1]]), pattern = s[[2]])
  if (length(s) > 2) {
    files <- setdiff(files, s[[3]])
  }
  if (!length(files)) {
    stop("Nothing to copy in ", s[[1]])
  }
  copied <- c(copied, vapply(file.path(s[[1]], files), copy, ""))
}
for (f in list.files(
  file.path(from, minisat),
  pattern = "\\.h$",
  recursive = TRUE
)) {
  copied <- c(copied, copy(file.path(minisat, f)))
}
for (f in list.files(
  file.path(from, antlr),
  pattern = "\\.(cpp|h)$",
  recursive = TRUE
)) {
  copied <- c(copied, copy(file.path(antlr, f), f, file.path(src, "antlr4")))
}
invisible(c(
  copy(
    "uvl2dimacs/third_party/LICENSE.txt",
    "LICENSE.txt",
    file.path(src, "antlr4")
  ),
  copy("uvl2dimacs/LICENSE"),
  copy("LICENSE")
))

# ----------------------------------------------------------- 3. patches by hand
read <- function(f) {
  paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}
write <- function(x, f) writeLines(enc2utf8(x), f, useBytes = TRUE)
patch <- function(rel, old, new, fixed = TRUE, root = "s4") {
  f <- file.path(src, root, rel)
  x <- read(f)
  hit <- if (fixed) grepl(old, x, fixed = TRUE) else grepl(old, x, perl = TRUE)
  if (!hit) {
    stop(
      "The patch for ",
      rel,
      " no longer applies: Strong4VM changed there. Update tools/sync_cpp.R.\n",
      old
    )
  }
  write(
    if (fixed) {
      sub(old, new, x, fixed = TRUE)
    } else {
      sub(old, new, x, perl = TRUE)
    },
    f
  )
}

# The simplification of uvl2dimacs ran BoneDigger as a separate program through
# popen(); in the package it calls the library directly (same detector: rush and
# pray, attention weight 1, Glucose 3.0). Strong4VM itself does not use the
# simplification; the function stays so that the library links.
patch(
  "uvl2dimacs/generator/src/BackboneSimplifier.cc",
  "(?s)bool BackboneSimplifier::compute_backbone\\(.*?\\n}\\n",
  paste0(
    'bool BackboneSimplifier::compute_backbone(const std::string& dimacs_path,
    const std::string& /* backbone_solver_path: unused in variplex */,
                                          int num_vars) {
    // variplex: BoneDigger is called as a library, not run as a program
    backbone_.clear();
    backbone_.resize(num_vars + 1, BackboneState::NONE);
    bonedigger::BoneDiggerAPI api;
    if (!api.set_solver("glucose-3.0") || !api.read_dimacs(dimacs_path) ||
        !api.create_backbone_detector("rush"))
        return false;
    api.set_attention_weight(1);
    for (int literal : api.compute_backbone()) {
        int var_id = std::abs(literal);
        if (var_id > 0 && var_id <= num_vars) {
            backbone_[var_id] =
                literal > 0 ? BackboneState::TRUE : BackboneState::FALSE;
            backbone_size_++;
        }
    }
    return true;
}
'
  ),
  fixed = FALSE
)
patch(
  "uvl2dimacs/generator/src/BackboneSimplifier.cc",
  "#include \"BackboneSimplifier.hh\"",
  paste0(
    "#include \"BackboneSimplifier.hh\"\n#include ",
    "\"api/BoneDiggerAPI.hh\"\n#include <cstdlib>"
  )
)

# Looking for the program backbone_solver next to the executable (readlink,
# access) is not needed, and not portable.
patch(
  "uvl2dimacs/api/src/UVL2Dimacs.cc",
  paste0(
    "(?s)            // Find backbone_solver executable\\n.*?            // ",
    "Create temporary file for simplified output\\n"
  ),
  paste0(
    "            std::string backbone_solver_path;   // variplex: BoneDigger ",
    "is linked in\n\n            // Create temporary file for simplified ",
    "output\n"
  ),
  fixed = FALSE
)
patch(
  "uvl2dimacs/api/src/UVL2Dimacs.cc",
  paste0(
    "(?s)#include <unistd.h>\\n#include <cstdio>\\n#ifdef ",
    "__APPLE__\\n.*?#endif\\n"
  ),
  "#include <cstdio>\n",
  fixed = FALSE
)

# The progress line needs a terminal; in R there is none (and isatty is POSIX
# only).
patch(
  "dimacs2graphs/core/GraphBuilder.cc",
  "(opts.progress == ProgressMode::Auto && isatty(STDOUT_FILENO))",
  "false"
)
patch("dimacs2graphs/core/GraphBuilder.cc", "#include <unistd.h>\n", "")

# GANAK is run through the shell: on Windows, cmd.exe quotes with double quotes.
patch(
  "dimacs2graphs/core/Counting.cc",
  "std::string shell_quote(const std::string& s) {\n",
  paste0(
    "std::string shell_quote(const std::string& s) {\n#ifdef _WIN32\n    ",
    "return \"\\\"\" + s + \"\\\"\";\n#endif\n"
  )
)
patch(
  "dimacs2graphs/core/Counting.cc",
  "FILE* p = popen(command.c_str(), \"r\");",
  paste0(
    "#ifdef _WIN32\n    FILE* p = _popen(command.c_str(), \"r\");\n#else\n   ",
    " FILE* p = popen(command.c_str(), \"r\");\n#endif"
  )
)
patch(
  "dimacs2graphs/core/Counting.cc",
  "const int status = pclose(p);",
  paste0(
    "#ifdef _WIN32\n    const int status = _pclose(p);\n#else\n    const int ",
    "status = pclose(p);\n#endif"
  )
)

# Two warnings of the compilers that R CMD check reports. Token::EOF is the
# largest size_t, given where an int is expected (the generated lexer); the
# conversion is made explicit, with the same value. And the definition of a
# member that ANTLR marks deprecated warns in its own file: the mark goes
# (nothing in the package uses that member).
patch(
  "uvl2dimacs/parser/include/UVLCppLexer.h",
  "emitToken(commonToken(antlr4::Token::EOF, \"<EOF>\"));",
  "emitToken(commonToken(static_cast<int>(antlr4::Token::EOF), \"<EOF>\"));"
)
patch(
  "Vocabulary.h",
  paste0(
    "[[deprecated(\"Use the default constructor of Vocabulary instead.\")]] ",
    "static const Vocabulary EMPTY_VOCABULARY;"
  ),
  "static const Vocabulary EMPTY_VOCABULARY;",
  root = "antlr4"
)

# What R CMD check, and the compilers of CRAN with -Wall -pedantic, report in
# the solvers. The pragmas that silenced the warnings of Glucose are not allowed
# by CRAN, so the warnings are fixed in the code instead, without changing what
# it does: parentheses that make the order of evaluation explicit, braces where
# indentation misled, casts in comparisons of signed and unsigned numbers,
# snprintf instead of sprintf, and a clause whose literals follow it in memory
# declared with one element instead of zero (ISO C++ has no arrays of size
# zero), with its size computed as before.
gl <- "uvl2dimacs/backbone_solver/src/sat_solvers/glucose_3_0/"
ms <- "uvl2dimacs/backbone_solver/src/sat_solvers/minisat_2_2_0/minisat/"
patch(
  "uvl2dimacs/backbone_solver/src/sat_interface/GlucoseBackend_3_0.cc",
  paste0(
    "(?s)#pragma GCC diagnostic push\\n.*?#include ",
    "\"sat_interface/GlucoseExt_3_0.hh\"\\n#pragma GCC diagnostic pop\\n"
  ),
  "#include \"sat_interface/GlucoseExt_3_0.hh\"\n",
  fixed = FALSE
)
patch(
  "uvl2dimacs/backbone_solver/src/sat_interface/GlucoseBackend_3_0.cc",
  paste0(
    "// Glucose headers are third-party code with known benign issues that ",
    "do not\n// affect correctness; silence the warnings they generate under ",
    "our flags.\n"
  ),
  ""
)
patch(
  paste0(ms, "core/SolverTypes.h"),
  paste0(
    "#pragma GCC diagnostic push\n#pragma GCC diagnostic ignored ",
    "\"-Wpedantic\"\n"
  ),
  ""
)
patch(
  paste0(ms, "core/SolverTypes.h"),
  "CRef rel; } data[0];\n#pragma GCC diagnostic pop\n",
  "CRef rel; } data[0];\n"
)
for (st in c(
  paste0(gl, "core/SolverTypes.h"),
  paste0(ms, "core/SolverTypes.h")
)) {
  patch(
    st,
    "union { Lit lit; float act; uint32_t abs; CRef rel; } data[0];",
    "union { Lit lit; float act; uint32_t abs; CRef rel; } data[1];"
  )
  patch(
    st,
    paste0(
      "return (sizeof(Clause) + (sizeof(Lit) * (size + (int)has_extra))) / ",
      "sizeof(uint32_t); }"
    ),
    paste0(
      "return (sizeof(Clause) - sizeof(Clause::data) + (sizeof(Lit) * (size ",
      "+ (int)has_extra))) / sizeof(uint32_t); }"
    )
  )
}
patch(
  paste0(gl, "mtl/Vec.h"),
  paste0(
    "if (add > INT_MAX - cap || ((data = (T*)::realloc(data, (cap += add) * ",
    "sizeof(T))) == NULL) && errno == ENOMEM)"
  ),
  paste0(
    "if (add > INT_MAX - cap || (((data = (T*)::realloc((void*)data, (cap += ",
    "add) * sizeof(T))) == NULL) && errno == ENOMEM))"
  )
)
patch(
  paste0(gl, "utils/Options.h"),
  "return test1 < 0 || test1 == 0 && strcmp(x->type_name, y->type_name) < 0;",
  "return test1 < 0 || (test1 == 0 && strcmp(x->type_name, y->type_name) < 0);"
)
patch(
  paste0(gl, "utils/ParseUtils.h"),
  paste0(
    "    while (*in >= '0' && *in <= '9')\n        accu = accu + ",
    "currentExponent * ((double)(*in - '0')),\n\t\tcurrentExponent /= 10,\n  ",
    "      ++in;"
  ),
  paste0(
    "    while (*in >= '0' && *in <= '9') {\n        accu = accu + ",
    "currentExponent * ((double)(*in - '0'));\n        currentExponent /= ",
    "10;\n        ++in;\n    }"
  )
)
patch(
  paste0(gl, "utils/Options.cc"),
  paste0(
    "            if (!parsed_ok)\n                if (strict && ",
    "match(argv[i], \"-\"))"
  ),
  paste0(
    "            if (!parsed_ok) {\n                if (strict && ",
    "match(argv[i], \"-\"))"
  )
)
patch(
  paste0(gl, "utils/Options.cc"),
  "                else\n                    argv[j++] = argv[i];\n",
  paste0(
    "                else\n                    argv[j++] = argv[i];\n        ",
    "    }\n"
  )
)
patch(
  paste0(gl, "utils/Options.cc"),
  "    if (usage != NULL)\n        fprintf(stderr, usage, argv[0]);\n",
  "    if (usage != NULL) {\n        fprintf(stderr, usage, argv[0]);\n    }\n"
)
patch(
  paste0(gl, "core/Solver.cc"),
  "if(nbDone>=end) break;",
  "if((long long)nbDone>=(long long)end) break;"
)
patch(
  paste0(gl, "core/Solver.cc"),
  "if(nbDone>=c.sizeWithoutSelectors()) break;",
  "if((long long)nbDone>=(long long)c.sizeWithoutSelectors()) break;"
)
patch(
  paste0(gl, "core/Solver.cc"),
  "if(conflicts>=curRestart* nbclausesbeforereduce)",
  "if((long long)conflicts>=(long long)curRestart* nbclausesbeforereduce)"
)
for (n in 1:2) {
  patch(
    paste0(gl, "utils/System.cc"),
    "sprintf(name, ",
    "snprintf(name, sizeof name, "
  )
}

# ANTLR: RuleContext::operator== hides the virtual one of ParseTree
# (-Woverloaded-virtual, part of -Wall in GCC 13); a using-declaration keeps
# both visible, as they were meant to be. And the initialisers of ASTNode in the
# order of its members (-Wreorder).
patch(
  "RuleContext.h",
  paste0(
    "    bool operator == (const RuleContext &other) { return this == ",
    "&other; } // Simple address comparison."
  ),
  paste0(
    "    using ParseTree::operator==;\n    bool operator == (const ",
    "RuleContext &other) { return this == &other; } // Simple address ",
    "comparison."
  ),
  root = "antlr4"
)
patch(
  "uvl2dimacs/generator/src/ASTNode.cc",
  ": type(Type::FLOAT), float_value(value), int_value(0) {",
  ": type(Type::FLOAT), int_value(0), float_value(value) {"
)

# ------------------------------------- 2. output and termination, in every file
rules <- list(
  c("using\\s+std::(cout|cerr|clog)\\s*;[ \\t]*", ""),
  c("(?<![\\w:.>\"])cout\\b", "vp::out()"),
  c("(?<![\\w:.>\"])(cerr|clog)\\b", "vp::err()"),
  c("std::cout\\b", "vp::out()"),
  c("std::cerr\\b", "vp::err()"),
  c("std::clog\\b", "vp::err()"),
  c("\\bfprintf\\s*\\(\\s*stderr\\s*,", "vp_eprintf("),
  c("\\bfprintf\\s*\\(\\s*stdout\\s*,", "vp_printf("),
  c("\\bfflush\\s*\\(\\s*std(out|err)\\s*\\)", "((void)0)"),
  c("(?<![\\w.>:])(std::)?printf\\s*\\(", "vp_printf("),
  c("(?<![\\w.>:])(std::)?puts\\s*\\(", "vp_puts("),
  c("(?<![\\w.>:])(std::)?abort\\s*\\(\\s*\\)", "vp_exit(134)"),
  c("(?<![\\w.>:])(std::)?exit\\s*\\(", "vp_exit(")
)
changed <- 0
for (f in copied[grepl("\\.(cc|cpp|h|hh)$", copied)]) {
  x <- read(f)
  y <- x
  for (r in rules) {
    y <- gsub(r[1], r[2], y, perl = TRUE)
  }
  if (!identical(x, y)) {
    write(
      paste0(
        "#include \"vp_io.h\"  // added by variplex (tools/sync_cpp.R)\n",
        y
      ),
      f
    )
    changed <- changed + 1
  }
}

# What R CMD check would still object to: report it, so that a new rule can be
# added above.
left <- character(0)
for (f in copied[grepl("\\.(cc|cpp|h|hh)$", copied)]) {
  x <- readLines(f, warn = FALSE)
  hit <- grep(
    paste0(
      "\\b(stdout|stderr|std::cout|std::cerr|popen)\\b|(?<![\\w.>:])(exit|abo",
      "rt|printf)\\s*\\("
    ),
    x,
    perl = TRUE
  )
  hit <- hit[!grepl("^\\s*(//|\\*)", x[hit])]
  if (length(hit)) {
    left <- c(
      left,
      paste0(
        sub(paste0(src, "/"), "", f, fixed = TRUE),
        ":",
        hit,
        ": ",
        trimws(x[hit])
      )
    )
  }
}

# ----------------------------------------------------------- 4. list of objects
sources <- sub(
  paste0(src, "/"),
  "",
  copied[grepl("\\.(cc|cpp)$", copied)],
  fixed = TRUE
)
objects <- sort(sub("\\.(cc|cpp)$", ".o", sources))
engine <- paste("ENGINE_OBJECTS =", paste(objects, collapse = " \\\n  "))
for (mk in c("Makevars", "Makevars.win")) {
  template <- readLines(file.path(pkg, "tools", paste0(mk, ".in")))
  writeLines(
    c(
      paste0(
        "# Written by tools/sync_cpp.R from tools/",
        mk,
        ".in. Edit the template, not this file."
      ),
      sub("@ENGINE_OBJECTS@", engine, template, fixed = TRUE)
    ),
    file.path(src, mk)
  )
}

cat("Copied", length(copied), "files from", from, "\n")
cat("Rewrote output or termination in", changed, "files\n")
cat("Objects:", length(objects), "(src/Makevars, src/Makevars.win)\n")
if (length(left)) {
  cat("\nStill to look at (patterns R CMD check may report):\n")
  cat(left, sep = "\n")
}
