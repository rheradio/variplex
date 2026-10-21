/**
 * @file Kernel.hh
 * @brief Kernel of the graphs (F7, R-KER-01..03)
 *
 * Algorithm (R-KER-01), on the contracted requires graph (one node per atomic
 * set) and the primitive conflicts:
 *  1. delete every arc that points to a node with no conflict;
 *  2. give each node the set of nodes it still requires, itself included if it
 *     has a conflict;
 *  3. merge nodes with identical sets into one class; the nodes with an empty
 *     set form the class "can always be added".
 * A node "has a conflict" when it excludes some node, by a primitive or by an
 * inherited conflict (the reading that reproduces the reference values of
 * R-TST-21). A node inherits the conflicts of what it requires, so two nodes
 * with a conflict never share a set: the kernel has one node per atomic set
 * with a conflict, and one node for all the options without any.
 * Kernel graphs: an arc between the classes of x and y for every remaining arc
 * x → y, and a conflict between the classes of a and b for every primitive
 * conflict {a, b}.
 *
 * Limit (R-KER-03): the kernel preserves what two-option rules say about
 * compatibility, not rules over three or more options.
 */

#ifndef DIMACS2GRAPHS_KERNEL_HH
#define DIMACS2GRAPHS_KERNEL_HH

#include "Atomic.hh"
#include "Graph.hh"

#include <vector>

namespace dimacs2graphs {

/// Text of R-KER-03, used in --help and in the summary.
extern const char* const KERNEL_LIMIT;

struct Kernel {
    std::vector<int> class_of;                ///< Kernel class of each component
    std::vector<std::vector<int>> classes;    ///< Components of each class (sorted); ordered by smallest component
    int always_class = -1;                    ///< Class "can always be added" (-1 if none)
    std::vector<Link> requires_arcs;          ///< 1-based classes
    std::vector<Link> excludes_edges;         ///< 1-based classes, first < second
};

/**
 * @param a        Atomic sets (components)
 * @param D        Requires arcs between nodes (1-based)
 * @param primitive_conflicts Primitive conflicts between components (1-based)
 */
Kernel compute_kernel(const AtomicSets& a, const std::vector<Link>& D, const std::vector<Link>& primitive_conflicts);

} // namespace dimacs2graphs

#endif
