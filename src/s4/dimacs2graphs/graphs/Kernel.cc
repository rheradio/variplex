/**
 * @file Kernel.cc
 * @brief Kernel (see Kernel.hh)
 */

#include "Kernel.hh"

#include <algorithm>
#include <map>

namespace dimacs2graphs {

const char* const KERNEL_LIMIT =
    "The kernel preserves what two-option rules say about compatibility, not rules over three or more options.";

Kernel compute_kernel(const AtomicSets& a, const std::vector<Link>& D, const std::vector<Link>& PC) {
    Kernel k;
    const int nc = a.count();
    std::vector<Link> Dc;
    for (const auto& l : D) {
        int c = a.comp[l.first - 1], d = a.comp[l.second - 1];
        if (c != d) Dc.push_back({c + 1, d + 1});
    }
    const Csr gd = Csr::from_links(nc, Dc, false);  // transitively closed
    // "A node with a conflict" (R-KER-01) is a node that excludes some other node, whether the conflict is
    // primitive or inherited: with this reading, and only with it, Linux x86 3.13 gives the reference values
    // of R-TST-21 (1,205 nodes, 3,393 arcs, 578 conflicts). A conflict is inherited by every node that
    // requires one of its ends (P2), so a node has a conflict exactly when it is an end of a primitive
    // conflict or requires one.
    std::vector<char> primitive_end(nc, 0), conflicting(nc, 0);
    for (const auto& l : PC) primitive_end[l.first - 1] = primitive_end[l.second - 1] = 1;
    for (int c = 0; c < nc; ++c) {
        conflicting[c] = primitive_end[c];
        for (const int* d = gd.begin(c); d != gd.end(c) && !conflicting[c]; ++d) conflicting[c] = primitive_end[*d];
    }

    // Steps 2–3: S(c) = {d : c → d, d conflicting} ∪ ({c} if conflicting)
    std::map<std::vector<int>, int> by_set;
    k.class_of.assign(nc, -1);
    std::vector<std::vector<int>> sets(nc);
    for (int c = 0; c < nc; ++c) {
        std::vector<int>& s = sets[c];
        for (const int* d = gd.begin(c); d != gd.end(c); ++d)
            if (conflicting[*d]) s.push_back(*d);
        if (conflicting[c]) s.push_back(c);
        std::sort(s.begin(), s.end());
    }
    // Step 3: classes in the order of their smallest component
    for (int c = 0; c < nc; ++c) {
        auto it = by_set.find(sets[c]);
        if (it == by_set.end()) {
            it = by_set.emplace(sets[c], static_cast<int>(k.classes.size())).first;
            k.classes.emplace_back();
            if (sets[c].empty()) k.always_class = it->second;
        }
        k.class_of[c] = it->second;
        k.classes[it->second].push_back(c);
    }
    for (int c = 0; c < nc; ++c)
        for (const int* d = gd.begin(c); d != gd.end(c); ++d)
            if (conflicting[*d] && k.class_of[c] != k.class_of[*d])
                k.requires_arcs.push_back({k.class_of[c] + 1, k.class_of[*d] + 1});
    for (const auto& l : PC) {
        int x = k.class_of[l.first - 1], y = k.class_of[l.second - 1];
        if (x == y) continue;
        k.excludes_edges.push_back({std::min(x, y) + 1, std::max(x, y) + 1});
    }
    for (auto* v : {&k.requires_arcs, &k.excludes_edges}) {
        std::sort(v->begin(), v->end());
        v->erase(std::unique(v->begin(), v->end()), v->end());
    }
    return k;
}

} // namespace dimacs2graphs
