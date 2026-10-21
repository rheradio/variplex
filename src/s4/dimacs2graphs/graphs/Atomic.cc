/**
 * @file Atomic.cc
 * @brief Iterative Tarjan and contraction (see Atomic.hh)
 */

#include "Atomic.hh"

#include <algorithm>
#include <unordered_map>

namespace dimacs2graphs {

AtomicSets strongly_connected_components(const Csr& g) {
    const int n = g.n;
    std::vector<int> index(n, -1), low(n, 0), raw(n, -1);
    std::vector<char> on_stack(n, 0);
    std::vector<int> stack;
    struct Frame { int u; std::size_t next; };
    std::vector<Frame> call;
    int counter = 0, ncomp = 0;

    for (int s = 0; s < n; ++s) {
        if (index[s] >= 0) continue;
        call.push_back({s, g.offset[s]});
        index[s] = low[s] = counter++;
        stack.push_back(s);
        on_stack[s] = 1;
        while (!call.empty()) {
            Frame& f = call.back();
            const int u = f.u;
            if (f.next < g.offset[u + 1]) {
                const int w = g.target[f.next++];
                if (index[w] < 0) {
                    index[w] = low[w] = counter++;
                    stack.push_back(w);
                    on_stack[w] = 1;
                    call.push_back({w, g.offset[w]});
                } else if (on_stack[w]) {
                    low[u] = std::min(low[u], index[w]);
                }
                continue;
            }
            if (low[u] == index[u]) {
                int w;
                do {
                    w = stack.back();
                    stack.pop_back();
                    on_stack[w] = 0;
                    raw[w] = ncomp;
                } while (w != u);
                ++ncomp;
            }
            call.pop_back();
            if (!call.empty()) {
                int p = call.back().u;
                low[p] = std::min(low[p], low[u]);
            }
        }
    }

    // Renumber components by their smallest member (deterministic order)
    std::vector<int> renum(ncomp, -1);
    AtomicSets a;
    a.comp.assign(n, -1);
    for (int u = 0; u < n; ++u) {
        int r = raw[u];
        if (renum[r] < 0) {
            renum[r] = static_cast<int>(a.members.size());
            a.members.emplace_back();
        }
        a.comp[u] = renum[r];
        a.members[renum[r]].push_back(u);  // u increasing: members sorted
    }
    return a;
}

Csr contract(const Csr& g, const AtomicSets& a) {
    std::vector<Link> links;
    for (int u = 0; u < g.n; ++u)
        for (const int* p = g.begin(u); p != g.end(u); ++p)
            if (a.comp[u] != a.comp[*p]) links.push_back({a.comp[u] + 1, a.comp[*p] + 1});
    return Csr::from_links(a.count(), links, false);
}

bool atomic_sets_from_lists(const std::vector<std::string>& names, const std::vector<std::vector<std::string>>& lists,
                            AtomicSets& a, std::string& error) {
    const int n = static_cast<int>(names.size());
    std::unordered_map<std::string, int> id;
    for (int i = 0; i < n; ++i) id[names[i]] = i;
    std::vector<int> group(n, -1);
    for (size_t g = 0; g < lists.size(); ++g)
        for (const auto& m : lists[g]) {
            auto it = id.find(m);
            if (it == id.end()) {
                error = "atomic set member '" + m + "' is not a vertex of the graphs. The files of this prefix do not "
                        "belong to the same run: regenerate them.";
                return false;
            }
            group[it->second] = static_cast<int>(g);
        }
    a = AtomicSets();
    a.comp.assign(n, -1);
    std::vector<int> group_comp(lists.size(), -1);
    for (int u = 0; u < n; ++u) {
        int g = group[u];
        if (g >= 0 && group_comp[g] >= 0) {
            a.comp[u] = group_comp[g];
            a.members[group_comp[g]].push_back(u);
            continue;
        }
        a.comp[u] = static_cast<int>(a.members.size());
        a.members.push_back({u});
        if (g >= 0) group_comp[g] = a.comp[u];
    }
    return true;
}

} // namespace dimacs2graphs
