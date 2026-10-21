#include "vp_io.h"  // added by variplex (tools/sync_cpp.R)
/**
 * @file Dimacs2GraphsAPI.hh
 * @brief Public C++ API of dimacs2graphs: from a DIMACS formula to the graphs of strong relations
 */

/**
 * @defgroup ParallelGraphs Graph generation
 * @brief From a Boolean formula to the graphs of strong dependencies and conflicts
 *
 * ## Overview
 *
 * dimacs2graphs reads a formula in DIMACS format and finds every relation between two of
 * its options that holds in all the solutions of the formula:
 * - **requires**: `v → i` when every solution with `v` true has `i` true;
 * - **excludes**: `v — i` when no solution has both true;
 * - **at least one** (optional): `v — i` when no solution has both false;
 * - **core** and **dead** options: true in every solution, and in none.
 *
 * ## How a run proceeds
 *
 * 1. The formula and the names of its variables are read.
 * 2. Every variable is classified by the rules of the translator that produced the formula
 *    (dimacs2graphs::FilterOptions): options are kept, artificial variables are dropped or
 *    merged. The decision for each variable is in dimacs2graphs::GraphsResult::variables and
 *    in the file `__variables.csv`.
 * 3. The global backbone gives the status of every variable (core, dead or variable). An
 *    unsatisfiable formula ends the run with the exit code 3.
 * 4. Main loop: for each kept option `v` that is neither core nor dead, the backbone of the
 *    formula under the assumption `v = true` gives its dependencies (the options that become
 *    true) and its conflicts (those that become false). With
 *    dimacs2graphs::OutputOptions::or_graph, a second backbone under `v = false` gives the
 *    third graph.
 * 5. Atomic sets, the minimal form, the kernel and the consistency checks are computed from
 *    the graphs (dimacs2graphs::OutputOptions).
 *
 * ## Threads
 *
 * The main loop runs on dimacs2graphs::RunOptions::threads worker threads. Each worker has
 * its own solver (a bonedigger::BoneDiggerAPI object, which must not be shared between
 * threads), created in the main thread before the workers start and kept for all the calls
 * of the worker. An atomic counter hands the next option to the first free worker. The
 * results of the workers are merged and sorted once, so the output does not depend on the
 * number of threads. If more threads are requested than the machine has cores, a warning is
 * given and the number of cores is used.
 *
 * ## Use
 *
 * @code
 * dimacs2graphs::Dimacs2GraphsAPI api;
 * dimacs2graphs::GenerateOptions options;
 * options.run.threads = 8;
 * options.run.output_dir = "out";
 * options.output.or_graph = true;
 * dimacs2graphs::GraphsResult g = api.generate("formula.dimacs", options);
 * if (g.success)
 *     vp::out() << g.node_names.size() << " options, " << g.files.size() << " files written\n";
 * @endcode
 *
 * The call of version 1.x, dimacs2graphs::Dimacs2GraphsAPI::generate_graphs(), is kept and
 * runs the same pipeline with the default options. The free functions classify(), check(),
 * expand(), explain(), read_renames(), diff() and version() correspond to the sub-commands and
 * to `--version` of the command line, which calls them.
 *
 * ## Errors
 *
 * No exception leaves the library. Every call ends with an exit code of Section 13 of the
 * specification, the code the command line would return, and a message that says what went
 * wrong, where and what to do: 1 an invalid option (the values that the command line rejects,
 * see dimacs2graphs::validate_options()), 2 an input error (a file that does not exist, cannot
 * be examined or cannot be read to its end, a malformed formula, not enough memory), 3 a void
 * model, 4 an internal error of the solver, 5 an unknown name with `UnknownNames::Error`, 7 a
 * failed consistency check. A thread that the system refuses to start is a warning: the run
 * goes on with the threads that started. One limit remains when the memory runs out: a call
 * that cannot even create its result object (its JSON value allocates when it is created) lets
 * std::bad_alloc out.
 *
 * The identifiers in parentheses in this documentation (R-API-02, F8, Section 13, …) refer
 * to the specification of Strong4VM 2.0; `tests/requirements.tsv` has a statement of each.
 *
 * @see dimacs2graphs::Dimacs2GraphsAPI
 * @see bonedigger::BoneDiggerAPI The backbone engine
 */

#ifndef DIMACS2GRAPHS_API_HH
#define DIMACS2GRAPHS_API_HH

#include <map>
#include <string>
#include <vector>

#include "../filter/Options.hh"
#include "../io/Json.hh"

namespace dimacs2graphs {

/// @addtogroup ParallelGraphs
/// @{

/**
 * @brief Graph in compressed sparse row form (R-API-02). Nodes are 0-based:
 * node i is vertex i + 1 of the Pajek files; the neighbours of i are
 * target[offset[i] .. offset[i + 1]). Undirected graphs list each edge in
 * both rows.
 */
struct CsrGraph {
    int num_nodes = 0;
    std::vector<std::size_t> offset;
    std::vector<int> target;
};

/// Classification of one variable: the row of __variables.csv (R-OUT-05).
struct VariableInfo {
    int dimacs_var = 0;          ///< 0 for declared names absent from the formula
    std::string name;            ///< Original name
    std::string output_name;     ///< Name after normalisation ("" if dropped)
    int node_id = 0;             ///< Vertex id, or 0
    std::string var_class;       ///< Section 5 class, e.g. "TSEITIN"
    std::string status;          ///< variable, core, dead, unconstrained ("" without solving)
    std::string decision;        ///< kept, dropped or merged_into:NAME
    std::string rule;            ///< Rule identifier
};

/// Result of Dimacs2GraphsAPI::generate (R-API-02).
struct GraphsResult {
    bool success = false;
    int exit_code = 0;                       ///< Section 13
    std::string error_message;
    Json summary;                            ///< Everything in __summary.json
    std::string summary_json;                ///< The same, as text
    std::vector<std::string> node_names;     ///< node_names[i] is vertex i + 1
    CsrGraph requires_graph;                 ///< Directed
    CsrGraph excludes_graph;                 ///< Undirected
    CsrGraph atleastone_graph;               ///< Undirected (empty without or_graph)
    std::vector<std::string> core, dead;     ///< Core and dead options
    std::vector<VariableInfo> variables;     ///< Every variable of the formula
    std::vector<std::string> warnings;
    std::vector<std::string> files;          ///< Files written
};

/// Result of classify(): the classification without solving (R-API-03).
struct ClassificationResult {
    bool success = false;
    int exit_code = 0;                       ///< Section 13: 0, 1 (invalid option), 2 (input error) or 5 (unknown name)
    std::string error_message;
    std::string translator;                  ///< Detected or given profile
    std::string detected_by;                 ///< option, extension, header, file-name, content, default
    std::vector<VariableInfo> variables;
    std::vector<std::string> warnings;
};

/**
 * @name Functions of the sub-commands (R-API-03)
 *
 * One function for each sub-command of the command line, which calls them: each takes the arguments of its
 * sub-command and returns the report that `--json` prints, with the exit code that the command returns and a
 * message. No exception leaves them (but std::bad_alloc if not even their result object can be created): a failure
 * is an exit code of Section 13 (1 usage error, 2 input error, 4 internal error, 7 failed check) and a message that
 * says what to do. A *prefix* is the path of the files of
 * a run without their suffix, e.g. `out/model` for `out/model__requires.net`.
 */
///@{

/**
 * @brief Classifies every variable of a DIMACS file without solving (`strong4vm FILE --classify-only` writes the
 * same rows to `__variables.csv`; this function writes no file). The status of the variables is left empty.
 */
ClassificationResult classify(const std::string& dimacs_file, const FilterOptions& options = FilterOptions());

/**
 * @brief Consistency checks R-CHK-01..07 on the files of a run (F8): `strong4vm check`.
 * @param prefix               path of the files without their suffix (files of 1.x are accepted)
 * @param exit_code            0; 7 if a check failed and `fail_on_check`; 1 if the memory limit is not positive;
 *                             2 if the files cannot be read
 * @param error                message when `exit_code` is not 0
 * @param max_matrix_memory_gb `--max-matrix-memory`: above this estimate the checks use sparse algorithms
 * @param fail_on_check        false for `--no-fail-on-check`: a failed check leaves the exit code at 0
 * @return the report of `strong4vm check --json`: "prefix", "vertices", "arcs", "edges", ["atleastone_edges"],
 *         "passed", "method" and "results" (per check: "id", "description", and "passed", "violations",
 *         "examples", or "applicable": false); null if the files cannot be read
 */
Json check(const std::string& prefix, int& exit_code, std::string& error, double max_matrix_memory_gb = 2.0,
           bool fail_on_check = true);

/**
 * @brief Rebuilds the full graphs from the minimal form (R-MIN-05): `strong4vm expand`.
 *
 * Writes `__requires.net`, `__excludes.net` and, when the run has the third graph, `__atleastone.net`, identical to
 * those of a full run, from `__requires_skeleton.net`, `__excludes_primitive.net`, `__atleastone_primitive.net`,
 * `__atomic.txt` and `__variables.csv`.
 *
 * @param prefix     path of the files of the run without their suffix
 * @param output_dir `-o DIR`: directory of the rebuilt files ("" = the directory of the prefix)
 * @param exit_code  0, or 2 if the files of the minimal form cannot be read or the directory cannot be written
 * @param error      message when `exit_code` is not 0
 * @return "vertices", "arcs", "edges", ["atleastone_edges"] and "files" (the files written); null on error
 */
Json expand(const std::string& prefix, const std::string& output_dir, int& exit_code, std::string& error);

/// The same as expand() above, without the report: true on success, otherwise `error` says why.
bool expand(const std::string& prefix, const std::string& output_dir, std::string& error);

/**
 * @brief Explains a conflict or a dependency (F9, R-EXP-01..03): `strong4vm explain`.
 * @param prefix    path of the files of the run without their suffix
 * @param a         the first option (`A`)
 * @param b         the second option (`B`)
 * @param kind      "conflict" (`--conflict A B`) or "requires" (`--requires A B`); anything else is exit code 1
 * @param exit_code 0; 1 for an unknown kind; 2 if the files cannot be read or a name is not an option of the run
 * @param error     message when `exit_code` is not 0
 * @return the report of `strong4vm explain --json`. For a conflict: "kind", "a", "b", "holds", "primitive",
 *         "origins" (each with "conflict", "chain_a", "chain_b"). For a dependency: "kind", "a", "b", "holds",
 *         "same_atomic_set", "in_skeleton", "chain" and, with the third graph, "via_atleastone"
 */
Json explain(const std::string& prefix, const std::string& a, const std::string& b, const std::string& kind,
             int& exit_code, std::string& error);

/**
 * @brief Reads the file of `strong4vm diff --rename FILE`: one rename per line, the old name, a space and the new
 * name (`BLEv40Old BLEv40`), or the two names separated by one tab when a name has spaces; empty lines and lines
 * that start with `#` are skipped. A line that does not follow this format is an error: one name only, more than two
 * words without a tab, more than one tab, an old name that ends with a comma or a semicolon (`BLEv40Old, BLEv40`;
 * such a name can be given with a tab), an old name given twice, or two old names given the same new name.
 * @param path    the file
 * @param renames the pairs read are added to it, old name → new name
 * @param error   message on failure
 * @return true on success; otherwise `error` gives the file, the line and what to write (an input error, exit
 *         code 2 in the command line)
 */
bool read_renames(const std::string& path, std::map<std::string, std::string>& renames, std::string& error);

/**
 * @brief Compares two versions (F10, R-DIF-01..03): `strong4vm diff`.
 *
 * Writes `__diff_summary.json`, `__diff_requires.csv`, `__diff_excludes.csv`, `__diff_atleastone.csv` and
 * `__diff_states.csv` in `output_dir` ("" = the current directory), with the base name `OLD__to__NEW` made of the
 * last components of the two prefixes.
 *
 * @param old_prefix path of the files of the old version without their suffix
 * @param new_prefix path of the files of the new version without their suffix
 * @param renames    options renamed between the versions, old name → new name (see read_renames())
 * @param output_dir `-o DIR`: directory of the files of the comparison ("" = the current directory)
 * @param exit_code  0, or 2 if the files cannot be read or the directory cannot be written
 * @param error      message when `exit_code` is not 0
 * @return the content of `__diff_summary.json` plus "report", its path; null on error
 */
Json diff(const std::string& old_prefix, const std::string& new_prefix, const std::map<std::string, std::string>& renames,
          const std::string& output_dir, int& exit_code, std::string& error);

/// The version of Strong4VM ("2.0.0"): what `strong4vm --version` prints and `__summary.json` records.
std::string version();

///@}

/**
 * @class Dimacs2GraphsAPI
 * @brief Generates the graphs of strong relations of a DIMACS formula
 *
 * generate() takes every option of Strong4VM 2.0 and returns the results in memory, besides
 * writing the files. generate_graphs() and the getters are the interface of version 1.x.
 */
class Dimacs2GraphsAPI {
public:
    /**
     * @brief Constructor
     */
    Dimacs2GraphsAPI();

    /**
     * @brief Destructor
     */
    ~Dimacs2GraphsAPI();

    /**
     * @brief Generates the graphs of a DIMACS formula with the default options (the call of 1.x)
     *
     * Runs the pipeline of Strong4VM 2.0 with its default options. generate() gives access
     * to every option and returns the results in memory.
     *
     * @param dimacs_file Path of the formula (a .dimacs or .cnf file)
     * @param output_folder Output folder ("" = the folder of the input)
     * @param detector Backbone detector: "one" (default: one Glucose 3.0 solver per thread, reused) or "rush"
     *                 (BoneDigger's rush-and-pray, a new solver per call; "flatland" is an alias of it)
     * @param num_of_threads Number of worker threads (default: 1). If it exceeds the number
     *                       of cores, a warning is printed and the number of cores is used
     * @return true if successful; otherwise get_error_message() and get_exit_code() say why
     *
     * Files written, with the name of the input as prefix:
     * - `__requires.net` and `__excludes.net`: the graphs, in Pajek format;
     * - `__core.txt` and `__dead.txt`: the options that are always, and never, selected;
     * - `__atomic.txt`, `__requires_skeleton.net` and `__excludes_primitive.net`: atomic sets
     *   and minimal form;
     * - `__variables.csv` and `__summary.json`: the classification of every variable and the
     *   summary of the run.
     */
    bool generate_graphs(
        const std::string& dimacs_file,
        const std::string& output_folder = "",
        const std::string& detector = "one",
        int num_of_threads = 1
    );

    /**
     * @brief Get the number of variables in the last processed formula
     * @return Number of variables, or 0 if no formula has been processed
     */
    int get_num_variables() const;

    /**
     * @brief Get the number of clauses in the last processed formula
     * @return Number of clauses, or 0 if no formula has been processed
     */
    int get_num_clauses() const;

    /**
     * @brief Get the global backbone computed for the last processed formula
     * @return Vector of backbone literals (empty if no formula has been processed)
     */
    std::vector<int> get_global_backbone() const;

    /**
     * @brief Get the last error message
     * @return Error message string (empty if no error)
     */
    std::string get_error_message() const;

    /**
     * @brief Kept for compatibility (R-API-04): true selects the translator
     * profile "uvl" (`--translator uvl`), false the automatic detection.
     *
     * generate_graphs() runs the 2.0 pipeline with the default options of
     * Section 8; auxiliary variables are always classified and dropped.
     *
     * @param filter If true, use the uvl profile (default: false, auto)
     */
    void set_filter_auxiliary(bool filter);

    /**
     * @brief Exit code of the last call to generate_graphs() or generate() (Section 13 of the 2.0 requirements):
     * 0 success, 1 invalid option, 2 input error, 3 void model (unsatisfiable formula), 4 solver error,
     * 5 unknown name (with `UnknownNames::Error`), 7 failed consistency check.
     */
    int get_exit_code() const;

    /**
     * @brief Generates every product of Strong4VM 2.0 from a DIMACS file with the given options (R-API-01) and
     * returns them in memory (R-API-02): `strong4vm generate` for a formula.
     *
     * Output files go to options.run.output_dir ("" = next to the input). The options are checked first as the
     * command line checks them (validate_options()): an invalid value ends the call with exit code 1.
     *
     * @param dimacs_file Path of the formula (any extension; "model" stands for "model.dimacs" when only the
     *                    latter exists, as in 1.x)
     * @param options     Every option of `strong4vm generate` (see GenerateOptions)
     * @return The products in memory, the files written, the warnings, the exit code and the message
     */
    GraphsResult generate(const std::string& dimacs_file, const GenerateOptions& options);

private:
    class Impl;
    Impl* pimpl;
};

/// @}

} // namespace dimacs2graphs

#endif // DIMACS2GRAPHS_API_HH
