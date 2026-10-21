/**
 * @file Minimal.hh
 * @brief Minimal form of the graphs and its expansion (F6, R-MIN-01..05)
 *
 * The minimal form is computed on the contracted graphs: one node per atomic
 * set (equivalent options have identical relations), numbered as in
 * AtomicSets (by smallest member):
 *   - skeleton: transitive reduction of the contracted requires DAG (R-MIN-01);
 *   - primitive conflicts: {c, d} is derived if c → x and {x, d} is a conflict,
 *     or d → x and {x, c} is a conflict (R-MIN-02);
 *   - primitive "at least one": {c, d} is derived if {c, x} is an edge and x → d,
 *     or {d, x} is an edge and x → c (R-MIN-03).
 * expand_minimal() rebuilds the full graphs exactly (R-MIN-05).
 */

#ifndef DIMACS2GRAPHS_MINIMAL_HH
#define DIMACS2GRAPHS_MINIMAL_HH

#include "Atomic.hh"
#include "Graph.hh"

#include <vector>

namespace dimacs2graphs {

struct MinimalForm {
    std::vector<Link> skeleton;               ///< Arcs between components (1-based component ids)
    std::vector<Link> excludes_primitive;     ///< Edges between components, first < second
    std::vector<Link> atleastone_primitive;   ///< Edges between components, first < second
    bool sparse = false;                      ///< Sparse skeleton algorithm used
};

/**
 * @param n   Number of nodes
 * @param a   Atomic sets of the requires graph
 * @param D   Requires arcs (1-based nodes)
 * @param C   Excludes edges (1-based nodes)
 * @param A   "At least one" edges (1-based nodes), or nullptr
 * @param max_matrix_memory_gb Above this estimate the sparse algorithms are used
 */
MinimalForm compute_minimal(int n, const AtomicSets& a, const std::vector<Link>& D, const std::vector<Link>& C,
                            const std::vector<Link>* A, double max_matrix_memory_gb);

struct ExpandedGraphs {
    std::vector<Link> requires_arcs, excludes_edges, atleastone_edges;  ///< 1-based nodes, sorted
};

/**
 * @brief Rebuilds the full graphs from the minimal form (R-MIN-05).
 * @param n        Number of nodes
 * @param a        Atomic sets
 * @param skeleton Arcs of the skeleton (1-based component ids)
 * @param PC       Primitive conflicts (1-based component ids)
 * @param PA       Primitive "at least one" edges (1-based component ids), or nullptr
 */
ExpandedGraphs expand_minimal(int n, const AtomicSets& a, const std::vector<Link>& skeleton,
                              const std::vector<Link>& PC, const std::vector<Link>* PA);

} // namespace dimacs2graphs

#endif
