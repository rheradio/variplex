/**
 * @file OutputSet.hh
 * @brief Reads the output files of a run, given their common prefix
 *
 * Used by `strong4vm check`, `expand`, `explain` and `diff`. Works on files
 * written by Strong4VM 2.x and on the published 1.x files (non-consecutive
 * ids and multi-word names are tolerated and reported as format issues).
 */

#ifndef DIMACS2GRAPHS_OUTPUT_SET_HH
#define DIMACS2GRAPHS_OUTPUT_SET_HH

#include "Json.hh"
#include "OutputFiles.hh"

#include <string>
#include <vector>

namespace dimacs2graphs {

struct OutputSet {
    std::string prefix;
    std::vector<std::string> names;          ///< Vertex names, compact ids 1..N (from __requires.net)
    std::vector<Link> requires_arcs;
    std::vector<Link> excludes_edges;
    bool excludes_directed = false;
    bool has_atleastone = false;
    std::vector<Link> atleastone_edges;
    std::vector<ListedNode> core, dead;      ///< ids remapped to compact ids (0 = not a vertex)
    bool has_summary = false;
    Json summary;
    std::vector<std::string> issues;         ///< Format issues (R-CHK-07)

    /// Compact id of a name (0 if absent).
    int id_of(const std::string& name) const;
};

/// Path of an output file: prefix + "__" + suffix.
inline std::string output_path(const std::string& prefix, const std::string& suffix) { return prefix + "__" + suffix; }

/// Reads a CSV file (RFC 4180: quoted fields, "" escapes, embedded commas/newlines).
bool read_csv(const std::string& path, std::vector<std::vector<std::string>>& rows, std::string& error);

/**
 * @brief Vertex list of a run from `<prefix>__variables.csv`: names[i] is node i + 1.
 */
bool read_node_names(const std::string& prefix, std::vector<std::string>& names, std::string& error);

/**
 * @brief Atomic sets from `<prefix>__atomic.txt`: each line's unmarked members
 * (markers `[abstract-group]`, `[abstract]`, `[tristate]` denote merged variables, not vertices).
 */
bool read_atomic_lines(const std::string& prefix, std::vector<std::vector<std::string>>& sets, std::string& error);

/**
 * @brief Reads `<prefix>__requires.net`, `__excludes.net` (required) and
 * `__atleastone.net`, `__core.txt`, `__dead.txt`, `__summary.json` (if present).
 */
bool read_output_set(const std::string& prefix, OutputSet& out, std::string& error);

} // namespace dimacs2graphs

#endif
