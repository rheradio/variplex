/**
 * @file Checks.hh
 * @brief Consistency checks of the graphs (F8, R-CHK-01..07)
 *
 * | Id       | Check                                                          |
 * |----------|----------------------------------------------------------------|
 * | R-CHK-01 | requires is transitive: D·D ⊆ D ∪ I                            |
 * | R-CHK-02 | conflicts are inherited: D·C ⊆ C                               |
 * | R-CHK-03 | excludes is symmetric (an *Edges section) and has no loops      |
 * | R-CHK-04 | no vertex is core or dead (with --fixed-nodes drop)             |
 * | R-CHK-05 | with "at least one": C·A ⊆ D, A·D ⊆ A, cross-check of R-OR-02    |
 * | R-CHK-06 | no option requires two options that exclude each other         |
 * | R-CHK-07 | vertex ids in 1..N, unique names                               |
 */

#ifndef DIMACS2GRAPHS_CHECKS_HH
#define DIMACS2GRAPHS_CHECKS_HH

#include "../io/Json.hh"
#include "../io/OutputFiles.hh"

#include <string>
#include <vector>

namespace dimacs2graphs {

struct CheckInput {
    std::vector<std::string> names;          ///< Vertex names (vertex i + 1)
    std::vector<Link> requires_arcs;         ///< 1-based
    std::vector<Link> excludes_edges;        ///< 1-based
    bool excludes_directed = false;          ///< The excludes file used *Arcs (R-CHK-03 violation)
    bool has_atleastone = false;
    std::vector<Link> atleastone_edges;      ///< 1-based
    bool has_crosscheck = false;
    std::vector<Link> or_implied_arcs;       ///< Arcs implied under v = false (R-OR-02), 1-based
    bool fixed_nodes_dropped = false;        ///< R-CHK-04 applies
    std::vector<ListedNode> core, dead;
    double max_matrix_memory_gb = 2.0;
};

/**
 * @brief Runs every applicable check.
 * @return JSON object {"passed": bool, "results": [{"id", "description", "passed", "violations", "examples"}]}
 */
Json run_checks(const CheckInput& in);

} // namespace dimacs2graphs

#endif
