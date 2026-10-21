test_that(
  paste0(
    "The R functions against the files that Strong4VM writes: minimal form, ",
    "atomic sets and kernel."
  ),
  {
    # ==========================================================================
    # The R functions against the files that Strong4VM writes: minimal form,
    # atomic sets and kernel.
    # ==========================================================================
    section("files: the R functions reproduce what Strong4VM wrote")
    for (n in pick(names(models))) {
      m <- models[[n]]
      pre <- fixtures[[n]]$prefix
      label <- function(what) paste0(n, ": ", what)
      check(
        label("vp_skeleton = __requires_skeleton.net"),
        setequal(
          keys(vp_skeleton(m)),
          read_net_keys(paste0(pre, "__requires_skeleton.net"), FALSE)
        )
      )
      check(
        label("vp_primitive_conflicts = __excludes_primitive.net"),
        setequal(
          keys(vp_primitive_conflicts(m), TRUE),
          read_net_keys(paste0(pre, "__excludes_primitive.net"), TRUE)
        )
      )
      check(
        label("vp_primitive_atleastone = __atleastone_primitive.net"),
        setequal(
          keys(vp_primitive_atleastone(m), TRUE),
          read_net_keys(paste0(pre, "__atleastone_primitive.net"), TRUE)
        )
      )
      kc <- readLines(paste0(pre, "__kernel_classes.txt"))
      kc <- kc[nzchar(kc)]
      k <- vp_kernel(m)
      mine <- vapply(
        split(k$feature, k$class),
        function(x) paste(sort(x), collapse = ","),
        ""
      )
      theirs <- vapply(
        strsplit(kc, "\t"),
        function(x) paste(sort(x), collapse = ","),
        ""
      )
      check(
        label("vp_kernel classes = __kernel_classes.txt"),
        setequal(mine, theirs) && length(mine) == length(theirs)
      )
      first <- vapply(strsplit(kc, "\t"), `[`, "", 1)
      check(
        label("each class is labelled with its first feature, as in the file"),
        setequal(unique(k$label), first)
      )
      kl <- vp_kernel_links(m)
      check(
        label(
          "vp_kernel_links = __kernel_requires.net and __kernel_excludes.net"
        ),
        setequal(
          keys(kl[kl$link == "requires", ]),
          read_net_keys(paste0(pre, "__kernel_requires.net"), FALSE)
        ) &&
          setequal(
            keys(kl[kl$link == "excludes", ], TRUE),
            read_net_keys(paste0(pre, "__kernel_excludes.net"), TRUE)
          )
      )
      v <- utils::read.csv(
        paste0(pre, "__variables.csv"),
        stringsAsFactors = FALSE,
        na.strings = ""
      )
      check(
        label("the features and their status = __variables.csv (kept ones)"),
        setequal(
          paste(m$features$feature, m$features$status),
          paste(
            v$output_name[v$decision == "kept"],
            v$status[v$decision == "kept"]
          )
        )
      )
      sj <- jsonlite::fromJSON(paste0(pre, "__summary.json"))
      s <- vp_summary(m)
      check(
        label("vp_summary agrees with the counts of __summary.json"),
        s$features == sj$counts$nodes &&
          s$requires == sj$counts$arcs &&
          s$excludes == sj$counts$edges &&
          s$skeleton == sj$counts$skeleton_arcs &&
          s$primitive_conflicts == sj$counts$primitive_conflicts &&
          s$core == sj$counts$core &&
          s$dead == sj$counts$dead &&
          s$atleastone == sj$counts$atleastone_edges
      )
    }
  }
)
