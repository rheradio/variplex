# Renames local variables of R/ to snake_case (the tidyverse style guide), with
# the parser of R: only symbols are renamed, never what follows `$`, `@` or
# `::`, nor the text of strings and comments. A rename is refused when the new
# name is already a symbol of the same file.
#
#     Rscript tools/rename_symbols.R

map <- c(
  D = "dep_m",
  C = "conf_m",
  A = "alo_m",
  P = "prim",
  S = "skel",
  G = "grid",
  K = "kern_m",
  Ki = "kern_ij",
  J = "jac",
  M = "mtx",
  Dc = "dep_c",
  Cc = "conf_c",
  Sg = "skel_g",
  DD = "dep_2",
  E = "arcs",
  B = "bip",
  inZL = "in_zl",
  inZR = "in_zr",
  V = "vars",
  AA = "adj_2",
  R = "imm",
  L = "chg",
  AD = "alo_dep",
  CA = "conf_alo",
  Cg = "conf_g",
  Sa = "skel_a",
  Sb = "skel_b",
  P2 = "dep_sym",
  gS = "g_skel",
  gP = "g_prim",
  Q = "g_rew",
  U = "g_und",
  Jc = "jac_c",
  Ds = "dep_s",
  Cs = "conf_s",
  As = "alo_s",
  Is = "id_s",
  Zs = "incomp_s",
  Z = "incomp",
  X = "x_mat",
  Y = "y_mat",
  W = "w_mat",
  N = "n_mat",
  H = "h_mat",
  F = "f_mat",
  T = "truth_t",
  I = "i_mat",
  O = "o_mat"
)

args <- commandArgs(trailingOnly = TRUE)
files <- if (length(args)) args else list.files("R", "\\.R$", full.names = TRUE)
# names that lintr flags and the map does not know: in snake_case, and with "_m"
# when that name is taken
for (path in files) {
  pd0 <- utils::getParseData(parse(path, keep.source = TRUE))
  syms <- unique(pd0$text[pd0$token %in% c("SYMBOL", "SYMBOL_FORMALS")])
  odd <- setdiff(
    syms[grepl("[A-Z]", syms) & !startsWith(syms, ".")],
    names(map)
  )
  for (o in odd) {
    new <- tolower(gsub("([a-z0-9])([A-Z])", "\\1_\\2", o))
    while (new %in% c(syms, map)) {
      new <- paste0(new, "_m")
    }
    map[[o]] <- new
  }
}
for (path in files) {
  if (basename(path) == "RcppExports.R") {
    next
  }
  lines <- readLines(path, encoding = "UTF-8")
  pd <- utils::getParseData(parse(path, keep.source = TRUE), includeText = TRUE)
  pd <- pd[pd$terminal, ]
  pd <- pd[order(pd$line1, pd$col1), ]
  prev <- c("", pd$token[-nrow(pd)])
  # a call is renamed only when the file defines that name itself (a local
  # helper), never a function of a package
  nxt <- c(pd$token[-1], "")
  defined <- unique(pd$text[
    pd$token == "SYMBOL" & nxt %in% c("LEFT_ASSIGN", "EQ_ASSIGN")
  ])
  hit <- (pd$token %in% c("SYMBOL", "SYMBOL_FORMALS") |
    (pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% defined)) &
    pd$text %in% names(map) &
    !prev %in% c("'$'", "'@'", "NS_GET", "NS_GET_INT")
  # a named argument in a call to one of our functions whose formal was renamed
  sub <- pd$token == "SYMBOL_SUB" & pd$text %in% names(map)
  if (any(sub)) {
    message(
      path,
      ": named arguments to check by hand: ",
      paste(unique(pd$text[sub]), collapse = ", ")
    )
  }
  if (!any(hit)) {
    next
  }
  used <- unique(pd$text[
    pd$token %in% c("SYMBOL", "SYMBOL_FORMALS", "SYMBOL_FUNCTION_CALL")
  ])
  clash <- intersect(map[unique(pd$text[hit])], used)
  if (length(clash)) {
    stop(
      path,
      ": the new names are already used: ",
      paste(clash, collapse = ", ")
    )
  }
  h <- pd[hit, ]
  # from the end, so that columns stay right
  for (k in rev(seq_len(nrow(h)))) {
    l <- lines[h$line1[k]]
    lines[h$line1[k]] <- paste0(
      substr(l, 1, h$col1[k] - 1),
      map[[h$text[k]]],
      substr(l, h$col2[k] + 1, nchar(l))
    )
  }
  writeLines(lines, path, useBytes = TRUE)
  message(path, ": ", nrow(h), " symbols renamed")
}
