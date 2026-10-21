/**
 * @file Graph.cc
 * @brief CSR and bit-set matrices (see Graph.hh)
 */

#include "Graph.hh"

#include <algorithm>

namespace dimacs2graphs {

Csr Csr::from_links(int n, const std::vector<Link>& links, bool symmetric) {
    Csr g;
    g.n = n;
    g.offset.assign(n + 1, 0);
    for (const auto& l : links) {
        ++g.offset[l.first];  // shifted by one: offset[u + 1] counts row u
        if (symmetric) ++g.offset[l.second];
    }
    for (int u = 0; u < n; ++u) g.offset[u + 1] += g.offset[u];
    g.target.resize(g.offset[n]);
    std::vector<std::size_t> pos(g.offset.begin(), g.offset.end() - 1);
    for (const auto& l : links) {
        g.target[pos[l.first - 1]++] = l.second - 1;
        if (symmetric) g.target[pos[l.second - 1]++] = l.first - 1;
    }
    // Sort and deduplicate every row, then compact
    std::vector<std::size_t> new_offset(n + 1, 0);
    std::size_t w = 0;
    for (int u = 0; u < n; ++u) {
        auto b = g.target.begin() + g.offset[u], e = g.target.begin() + g.offset[u + 1];
        std::sort(b, e);
        auto last = std::unique(b, e);
        new_offset[u] = w;
        for (auto it = b; it != last; ++it) g.target[w++] = *it;
    }
    new_offset[n] = w;
    g.target.resize(w);
    g.offset.swap(new_offset);
    return g;
}

bool Csr::has(int u, int v) const {
    return std::binary_search(begin(u), end(u), v);
}

Csr Csr::transposed() const {
    std::vector<Link> links;
    links.reserve(target.size());
    for (int u = 0; u < n; ++u)
        for (const int* p = begin(u); p != end(u); ++p) links.push_back({*p + 1, u + 1});
    return from_links(n, links, false);
}

BitMatrix::BitMatrix(int n) : n_(n), words_((n + 63) / 64), bits_(std::size_t(n) * ((n + 63) / 64), 0) {}

void BitMatrix::or_row(int dst, const BitMatrix& m, int src) {
    uint64_t* d = row(dst);
    const uint64_t* s = m.row(src);
    for (std::size_t w = 0; w < words_; ++w) d[w] |= s[w];
}

BitMatrix BitMatrix::from_csr(const Csr& g) {
    BitMatrix m(g.n);
    for (int u = 0; u < g.n; ++u)
        for (const int* p = g.begin(u); p != g.end(u); ++p) m.set(u, *p);
    return m;
}

} // namespace dimacs2graphs
