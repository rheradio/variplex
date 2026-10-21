/**
 * @file Atomic.hh
 * @brief Atomic sets: strongly connected components of the requires graph (F5, R-ATM-01)
 */

#ifndef DIMACS2GRAPHS_ATOMIC_HH
#define DIMACS2GRAPHS_ATOMIC_HH

#include "Graph.hh"

#include <string>
#include <vector>

namespace dimacs2graphs {

/**
 * @brief Partition of the nodes into strongly connected components.
 *
 * Components are numbered in the order of their smallest member, and the
 * members of each component are sorted, so the representative of a
 * component (its smallest member) is members[c][0].
 */
struct AtomicSets {
    std::vector<int> comp;                   ///< Component of each node (0-based)
    std::vector<std::vector<int>> members;   ///< Sorted members of each component

    int count() const { return static_cast<int>(members.size()); }
    int representative(int c) const { return members[c][0]; }
};

/// Strongly connected components with an iterative Tarjan algorithm (no recursion).
AtomicSets strongly_connected_components(const Csr& g);

/// Contracted graph: one node per component, arc (c, d) for each arc u → w with c ≠ d.
Csr contract(const Csr& g, const AtomicSets& a);

/**
 * @brief Rebuilds atomic sets from vertex names and the member lists of __atomic.txt.
 * Nodes not listed are alone; components are numbered by their smallest member,
 * as strongly_connected_components() does.
 * @return false (with message) if a listed member is not a vertex
 */
bool atomic_sets_from_lists(const std::vector<std::string>& names, const std::vector<std::vector<std::string>>& lists,
                            AtomicSets& a, std::string& error);

} // namespace dimacs2graphs

#endif
