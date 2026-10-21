test_that(
  paste0(
    "Representativeness (Strong4VM with --representativeness, counted by ",
    "GANAK) against the oracle."
  ),
  {
    # ==========================================================================
    # Representativeness (Strong4VM with --representativeness, counted by GANAK)
    # against the oracle.
    # ==========================================================================
    section("representativeness")
    if (length(rep_models) == 0) {
      skip_note("representativeness", "GANAK not found: give --ganak PATH")
    } else {
      for (n in names(rep_models)) {
        m <- rep_models[[n]]
        r <- vp_representativeness(m)
        label <- function(what) paste0(n, ": ", what)
        check(
          label("read from __summary.json"),
          nzchar(r$note) == FALSE && !is.na(r$share)
        )
        x_mat <- oracle[[n]]$T$X
        check(
          label(
            paste0(
              paste0(
                "vm_configurations = the valid configurations on the ",
                "features of "
              ),
              "the graphs (oracle)"
            )
          ),
          r$vm_configurations == nrow(unique(x_mat))
        )
        vars <- colnames(x_mat)
        if (length(vars) <= 20) {
          check(
            label(
              paste0(
                "graph_configurations = the configurations that break no link ",
                "(vp_count_graph_products)"
              )
            ),
            r$graph_configurations == vp_count_graph_products(m)$and_atleastone
          )
        }
        check(
          label(
            paste0(
              "share = vm_configurations / graph_configurations, left out = 1 ",
              "- share"
            )
          ),
          abs(r$share - r$vm_configurations / r$graph_configurations) < 1e-5 &&
            abs(r$left_out - (1 - r$share)) < 1e-9
        )
        check(
          label("vp_summary reports the same share"),
          isTRUE(all.equal(vp_summary(m)$representativeness, r$share))
        )
        check(
          label("a part does not inherit the share of the whole model"),
          grepl(
            "whole model",
            vp_representativeness(vp_subset(m, head(vars, 2)))$note
          )
        )
      }
    }
    check(
      paste0(
        "a run without --representativeness: NA, with a note that says how to ",
        "get it"
      ),
      is.na(vp_representativeness(models$miband3)$share) &&
        grepl(
          "representativeness = TRUE",
          vp_representativeness(models$miband3)$note
        )
    )
  }
)
