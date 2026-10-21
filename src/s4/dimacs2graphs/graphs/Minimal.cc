/**
 * @file Minimal.cc
 * @brief Minimal form and expansion (see Minimal.hh)
 */

#include "Minimal.hh"

#include <algorithm>

namespace dimacs2graphs {

namespace {

/// Links between components induced by node links (1-based), without loops.
std::vector<Link> to_components(const AtomicSets& a, const std::vector<Link>& links, bool symmetric) {
    std::vector<Link> out;
    out.reserve(links.size());
    for (const auto& l : links) {
        int c = a.comp[l.first - 1] + 1, d = a.comp[l.second - 1] + 1;
        if (c == d) continue;
        if (symmetric && c > d) std::swap(c, d);
        out.push_back({c, d});
    }
    std::sort(out.begin(), out.end());
    out.erase(std::unique(out.begin(), out.end()), out.end());
    return out;
}

/// Edges {c, d} of an undirected relation R that are derived through the
/// directed relation G: d ∈ ⋃_{x ∈ G(c)} R(x), or the same with c and d
/// swapped. `R` symmetric CSR, `G` directed CSR, `through_R_first` selects
/// the composition order (true: G then R, as for conflicts; false: R then G).
std::vector<Link> primitive_edges(const std::vector<Link>& edges, const Csr& R, const Csr& G, bool conflicts) {
    const int k = R.n;
    std::vector<int> stamp(k, -1);
    std::vector<Link> derived;
    for (int c = 0; c < k; ++c) {
        if (R.degree(c) == 0) continue;
        if (conflicts) {
            // c → x, {x, d} ∈ R
            for (const int* x = G.begin(c); x != G.end(c); ++x)
                for (const int* d = R.begin(*x); d != R.end(*x); ++d) stamp[*d] = c;
        } else {
            // {c, x} ∈ R, x → d
            for (const int* x = R.begin(c); x != R.end(c); ++x)
                for (const int* d = G.begin(*x); d != G.end(*x); ++d) stamp[*d] = c;
        }
        for (const int* d = R.begin(c); d != R.end(c); ++d)
            if (stamp[*d] == c) derived.push_back({std::min(c, *d) + 1, std::max(c, *d) + 1});
    }
    std::sort(derived.begin(), derived.end());
    derived.erase(std::unique(derived.begin(), derived.end()), derived.end());
    std::vector<Link> primitive;
    std::set_difference(edges.begin(), edges.end(), derived.begin(), derived.end(), std::back_inserter(primitive));
    return primitive;
}

/// Reachability sets of a DAG (excluding the node itself), as sorted vectors.
std::vector<std::vector<int>> closure(const Csr& dag) {
    const int k = dag.n;
    // Kahn topological order
    std::vector<int> indeg(k, 0), order;
    order.reserve(k);
    for (int u = 0; u < k; ++u)
        for (const int* v = dag.begin(u); v != dag.end(u); ++v) ++indeg[*v];
    for (int u = 0; u < k; ++u)
        if (!indeg[u]) order.push_back(u);
    for (size_t i = 0; i < order.size(); ++i)
        for (const int* v = dag.begin(order[i]); v != dag.end(order[i]); ++v)
            if (--indeg[*v] == 0) order.push_back(*v);
    std::vector<std::vector<int>> reach(k);
    std::vector<int> stamp(k, -1);
    for (size_t i = order.size(); i-- > 0;) {
        int u = order[i];
        std::vector<int>& r = reach[u];
        for (const int* v = dag.begin(u); v != dag.end(u); ++v) {
            if (stamp[*v] != u) { stamp[*v] = u; r.push_back(*v); }
            for (int w : reach[*v])
                if (stamp[w] != u) { stamp[w] = u; r.push_back(w); }
        }
        std::sort(r.begin(), r.end());
    }
    return reach;
}

}  // namespace

MinimalForm compute_minimal(int n, const AtomicSets& a, const std::vector<Link>& D, const std::vector<Link>& C,
                            const std::vector<Link>* A, double max_matrix_memory_gb) {
    (void)n;
    MinimalForm m;
    const int k = a.count();
    const std::vector<Link> Dc = to_components(a, D, false);
    const Csr gd = Csr::from_links(k, Dc, false);

    // R-MIN-01: arc c → d is redundant iff d ∈ ⋃_{x ∈ out(c)} out(x)
    m.sparse = k > 50000 || BitMatrix::bytes(k) * 2 > max_matrix_memory_gb * 1e9;
    if (!m.sparse) {
        BitMatrix out = BitMatrix::from_csr(gd);
        std::vector<uint64_t> red(out.words());
        for (int c = 0; c < k; ++c) {
            std::fill(red.begin(), red.end(), 0);
            for (const int* x = gd.begin(c); x != gd.end(c); ++x) {
                const uint64_t* r = out.row(*x);
                for (size_t w = 0; w < red.size(); ++w) red[w] |= r[w];
            }
            for (const int* d = gd.begin(c); d != gd.end(c); ++d)
                if (!((red[*d >> 6] >> (*d & 63)) & 1)) m.skeleton.push_back({c + 1, *d + 1});
        }
    } else {
        std::vector<int> stamp(k, -1);
        for (int c = 0; c < k; ++c) {
            for (const int* x = gd.begin(c); x != gd.end(c); ++x)
                for (const int* d = gd.begin(*x); d != gd.end(*x); ++d) stamp[*d] = c;
            for (const int* d = gd.begin(c); d != gd.end(c); ++d)
                if (stamp[*d] != c) m.skeleton.push_back({c + 1, *d + 1});
        }
    }

    // R-MIN-02
    const std::vector<Link> Cc = to_components(a, C, true);
    m.excludes_primitive = primitive_edges(Cc, Csr::from_links(k, Cc, true), gd, true);

    // R-MIN-03
    if (A) {
        const std::vector<Link> Ac = to_components(a, *A, true);
        m.atleastone_primitive = primitive_edges(Ac, Csr::from_links(k, Ac, true), gd, false);
    }
    return m;
}

ExpandedGraphs expand_minimal(int n, const AtomicSets& a, const std::vector<Link>& skeleton,
                              const std::vector<Link>& PC, const std::vector<Link>* PA) {
    ExpandedGraphs e;
    const int k = a.count();
    const Csr sk = Csr::from_links(k, skeleton, false);
    const std::vector<std::vector<int>> down_reach = closure(sk);              // what c requires (≠ c)
    const std::vector<std::vector<int>> up_reach = closure(sk.transposed());  // what requires c (≠ c)

    auto member_pairs = [&](int c, int d, std::vector<Link>& out, bool undirected) {
        for (int u : a.members[c])
            for (int w : a.members[d]) {
                if (u == w) continue;
                if (undirected && u > w) continue;
                out.push_back({u + 1, w + 1});
            }
    };

    // 1. requires: closure of the skeleton, atomic sets expanded (members require each other)
    for (int c = 0; c < k; ++c) {
        member_pairs(c, c, e.requires_arcs, false);
        for (int d : down_reach[c]) member_pairs(c, d, e.requires_arcs, false);
    }

    // Generic propagation: result(x) = ⋃_{y ∈ S(x)} F(y), F(y) = ⋃_{b ∈ P(y)} T(b) (T includes b)
    auto propagate = [&](const std::vector<Link>& prim, const std::vector<std::vector<int>>& S,
                         const std::vector<std::vector<int>>& T, std::vector<Link>& out) {
        const Csr P = Csr::from_links(k, prim, true);
        std::vector<std::vector<int>> F(k);
        std::vector<int> stamp(k, -1);
        for (int y = 0; y < k; ++y) {
            for (const int* b = P.begin(y); b != P.end(y); ++b) {
                if (stamp[*b] != y) { stamp[*b] = y; F[y].push_back(*b); }
                for (int t : T[*b])
                    if (stamp[t] != y) { stamp[t] = y; F[y].push_back(t); }
            }
        }
        std::fill(stamp.begin(), stamp.end(), -1);
        for (int x = 0; x < k; ++x) {
            auto visit = [&](int y) {
                for (int d : F[y])
                    if (stamp[d] != x) {
                        stamp[d] = x;
                        if (x < d) member_pairs(x, d, out, false);
                        else if (x == d) member_pairs(x, x, out, true);
                    }
            };
            visit(x);
            for (int y : S[x]) visit(y);
        }
    };
    // 2. excludes: primitive conflicts propagated downwards: x # d iff x requires a, d requires b, {a, b} primitive
    propagate(PC, down_reach, up_reach, e.excludes_edges);
    // 3. "at least one": primitive edges propagated upwards: {x, d} iff a requires x, b requires d, {a, b} primitive
    if (PA) propagate(*PA, up_reach, down_reach, e.atleastone_edges);

    for (auto* v : {&e.requires_arcs, &e.excludes_edges, &e.atleastone_edges}) {
        for (auto& l : *v)
            if (v != &e.requires_arcs && l.first > l.second) std::swap(l.first, l.second);
        std::sort(v->begin(), v->end());
        v->erase(std::unique(v->begin(), v->end()), v->end());
    }
    (void)n;
    return e;
}

} // namespace dimacs2graphs
