/**
 * @file Analyses.hh
 * @brief Analyses of existing output files: check, expand, explain, diff (R-API-03)
 *
 * These functions implement the sub-commands `strong4vm check`, `expand`,
 * `explain` and `diff`. They are called through the free functions of the
 * API (api/Dimacs2GraphsAPI.hh), which add the exit codes of Section 13 and
 * let no exception out; the command line calls those functions too and only
 * parses arguments and prints the returned JSON reports. A prefix is the path
 * of the output files without their suffix (e.g. out/model for
 * out/model__requires.net).
 */

#ifndef DIMACS2GRAPHS_ANALYSES_HH
#define DIMACS2GRAPHS_ANALYSES_HH

#include "../io/Json.hh"
#include "Status.hh"

#include <map>
#include <string>

namespace dimacs2graphs {

/// Outcome of an analysis: exit code (Section 13) and error message.
struct AnalysisStatus {
    ExitCode code = ExitCode::Success;
    std::string error;
    bool ok() const { return code == ExitCode::Success; }
};

/**
 * @brief Consistency checks R-CHK-01..07 on existing files (F8).
 * @return {"prefix", "vertices", "arcs", "edges", ["atleastone_edges"], "passed", "method", "results": [...]}.
 * Format issues found while reading (e.g. 1.x ids outside 1..N) count as R-CHK-07 violations.
 * A failed check is not an error here: read "passed".
 */
Json check_outputs(const std::string& prefix, double max_matrix_memory_gb, AnalysisStatus& status);

/**
 * @brief Rebuilds __requires.net, __excludes.net and __atleastone.net from the minimal form (R-MIN-05).
 * @param prefix     path of the files of the run, without their suffix
 * @param output_dir directory of the rebuilt files ("" = the prefix's directory)
 * @param status     exit code and message of the call
 * @return {"vertices", "arcs", "edges", ["atleastone_edges"], "files": [...]}
 */
Json expand_outputs(const std::string& prefix, const std::string& output_dir, AnalysisStatus& status);

enum class ExplainKind { Conflict, Requires };

/**
 * @brief Explains a conflict (R-EXP-01) or a dependency (R-EXP-02).
 * Conflict: {"kind", "a", "b", "holds", "primitive", "origins": [{"conflict": [x, y], "chain_a": [...], "chain_b": [...]}]}.
 * Requires: {"kind", "a", "b", "holds", "same_atomic_set", "in_skeleton", "chain": [...], ["via_atleastone": [...]]}.
 * Unknown option names give ExitCode::Input with a message that says whether the option is core or dead.
 */
Json explain_relation(const std::string& prefix, ExplainKind kind, const std::string& a, const std::string& b,
                      AnalysisStatus& status);

/**
 * @brief Compares two versions (F10, R-DIF-01..03) and writes the diff files in output_dir
 * ("" = current directory) with base name OLD__to__NEW, from the names of the two prefixes.
 * @return the content of __diff_summary.json plus "report" (its path).
 */
Json diff_outputs(const std::string& old_prefix, const std::string& new_prefix,
                  const std::map<std::string, std::string>& renames, const std::string& output_dir,
                  AnalysisStatus& status);

} // namespace dimacs2graphs

#endif
