/**
 * @file Options.hh
 * @brief Options of graph generation (Section 8 and R-API-01 of the 2.0 requirements)
 *
 * The same structures are used by the command line, Dimacs2GraphsAPI and
 * Strong4VMAPI, so every option is available everywhere.
 */

#ifndef DIMACS2GRAPHS_OPTIONS_HH
#define DIMACS2GRAPHS_OPTIONS_HH

#include <optional>
#include <string>
#include <vector>

namespace dimacs2graphs {

/// @addtogroup ParallelGraphs
/// @{

/// Translator profile (R-FLT-01).
enum class Translator { Auto, KMax, KConfigReader, KconfigSampler, TraVarT, Uvl, Generic };
/// Meaning of a tristate option in KConfigReader formulas (R-FLT-11).
enum class TristateMode { Merge, Builtin, Both };
/// Treatment of value variables of non-Boolean options (R-FLT-10).
enum class NonBoolMode { Merge, Drop, Keep };
/// Treatment of TraVarT abstract group features (T2).
enum class AbstractGroupMode { Merge, Keep };
/// Treatment of UVL features marked {abstract} (U4, R-UVL-05), the root included when it is abstract: kept as nodes,
/// dropped (the default since 12 Oct 2026: an abstract feature is a heading of the model, not a part of a product), or
/// merged into the atomic set of an equivalent feature that is not abstract (kept when there is none: the abstract
/// feature then stands for a choice).
enum class AbstractMode { Keep, Drop, Merge };
/// Policy for names that no rule of the profile matches (R-OPT-14).
enum class UnknownNames { ProfileDefault, Keep, Drop, Error };
/// Where the filter acts (R-PIPE-03).
enum class FilterAt { Input, Output };
/// Progress output on the terminal (R-PERF-06).
enum class Progress { Auto, On, Off };

/// Classification and filtering options (Sections 5–7).
struct FilterOptions {
    Translator translator = Translator::Auto;            ///< --translator
    TristateMode tristate = TristateMode::Merge;         ///< --tristate
    NonBoolMode nonbool = NonBoolMode::Merge;            ///< --nonbool
    bool drop_visibility = true;                         ///< --visibility drop|keep
    AbstractGroupMode abstract_groups = AbstractGroupMode::Merge;  ///< --abstract-groups
    bool drop_synthetic_root = true;                     ///< --synthetic-root drop|keep
    AbstractMode abstract_features = AbstractMode::Drop;  ///< --abstract keep|drop|merge (default drop)
    bool drop_fixed_nodes = true;                        ///< --fixed-nodes drop|keep
    bool drop_unnamed = true;                            ///< --unnamed drop|keep
    UnknownNames unknown_names = UnknownNames::ProfileDefault;  ///< --unknown-names
    std::optional<std::string> decls_file;               ///< --decls FILE
    bool add_unconstrained = false;                      ///< --decls-unconstrained ignore|add
    bool keep_type_prefix = false;                       ///< --keep-type-prefix
    bool strip_config_prefix = false;                    ///< --strip-config-prefix
    std::vector<std::string> keep_patterns;              ///< --keep-pattern RE (repeatable)
    std::vector<std::string> drop_patterns;              ///< --drop-pattern RE (repeatable)
    std::optional<std::string> drop_names_file;          ///< --drop-names FILE
    FilterAt filter_at = FilterAt::Input;                ///< --filter-at
};

/// Products written besides the two graphs (F2, F5–F8).
struct OutputOptions {
    bool or_graph = false;       ///< --or-graph
    bool atomic = true;          ///< --atomic on|off
    bool minimal = true;         ///< --minimal on|off (Section 8: default on)
    bool kernel = false;         ///< --kernel
    bool check = true;           ///< --check on|off
    bool fail_on_check = true;   ///< --no-fail-on-check sets false
    bool representativeness = false;  ///< --representativeness: count with GANAK the share of the choices that the graphs let pass
                                      ///< that are products (needs or_graph)
};

/// Execution options.
struct RunOptions {
    int threads = 1;                          ///< -t, --threads
    std::string output_dir;                   ///< -o, --output ("" = next to the input)
    std::string detector = "one";             ///< Backbone detector
    bool mig = true;                          ///< --mig on|off: modal implication graph in the main loop (detector "one")
    Progress progress = Progress::Auto;       ///< --progress
    bool quiet = false;                       ///< -q, --quiet
    bool verbose = false;                     ///< -v, --verbose
    double max_matrix_memory_gb = 2.0;        ///< --max-matrix-memory (GB)
    bool strict_uvl = false;                  ///< --strict-uvl
    bool legacy = false;                      ///< --legacy (informational; see apply_legacy)
    bool classify_only = false;               ///< --classify-only: classification reports only, no solving
    std::string ganak = "ganak";              ///< --ganak PATH: the model counter of --representativeness
};

/// Every option of `strong4vm generate`.
struct GenerateOptions {
    FilterOptions filter;
    OutputOptions output;
    RunOptions run;
};

/// Sets every option to its 1.x behaviour (R-PRI-06, `--legacy` column of Section 8).
void apply_legacy(GenerateOptions& o);
/// The same, on the three groups of options separately.
void apply_legacy(FilterOptions& filter, OutputOptions& output, RunOptions& run);

/**
 * @brief Checks the values that the command line rejects (R-CLI-03), for the callers of the API.
 *
 * `threads` at least 1, `max_matrix_memory_gb` greater than 0, `detector` one of "one" and "rush" ("flatland" is
 * still accepted, as an alias of "rush"),
 * and no empty file name in `decls_file` or `drop_names_file`. The regular expressions of `keep_patterns` and
 * `drop_patterns` are checked when the variables are classified.
 *
 * @return "" if the options are valid; otherwise what is wrong and what to give (a usage error, exit code 1).
 *         The generation calls of the API return this message with exit code 1.
 */
std::string validate_options(const GenerateOptions& o);

// Names of enum values as written on the command line and in the summary.
const char* to_string(Translator t);
const char* to_string(TristateMode m);
const char* to_string(NonBoolMode m);
const char* to_string(AbstractGroupMode m);
const char* to_string(AbstractMode m);
const char* to_string(UnknownNames u);
const char* to_string(FilterAt f);
const char* to_string(Progress p);

bool parse_translator(const std::string& s, Translator& t);

/// @}

} // namespace dimacs2graphs

#endif
