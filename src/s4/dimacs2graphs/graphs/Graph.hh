/**
 * @file Graph.hh
 * @brief Graph containers: compressed sparse rows and bit-set matrices (R-PERF-05, R-IMP-04)
 *
 * Nodes are 0-based here; the Pajek files and the pipeline use 1-based ids
 * (convert with Link{a + 1, b + 1}).
 */

#ifndef DIMACS2GRAPHS_GRAPH_HH
#define DIMACS2GRAPHS_GRAPH_HH

#include "../io/OutputFiles.hh"

#include <cstddef>
#include <cstdint>
#include <vector>

namespace dimacs2graphs {

/// Adjacency in compressed sparse row form.
struct Csr {
    int n = 0;
    std::vector<std::size_t> offset;  ///< size n + 1
    std::vector<int> target;          ///< neighbours of u: target[offset[u] .. offset[u+1])

    /**
     * @brief Builds the adjacency of n nodes from 1-based links.
     * Neighbour lists are sorted and without duplicates.
     * @param n         number of nodes
     * @param links     links between nodes 1..n
     * @param symmetric add both directions (undirected graph)
     */
    static Csr from_links(int n, const std::vector<Link>& links, bool symmetric);

    std::size_t degree(int u) const { return offset[u + 1] - offset[u]; }
    const int* begin(int u) const { return target.data() + offset[u]; }
    const int* end(int u) const { return target.data() + offset[u + 1]; }
    bool has(int u, int v) const;   ///< Binary search in the row of u
    /// Transposed graph (in-neighbours become out-neighbours).
    Csr transposed() const;
};

/// Square bit matrix with one std::vector<uint64_t> row per node.
class BitMatrix {
public:
    BitMatrix() = default;
    explicit BitMatrix(int n);

    int size() const { return n_; }
    std::size_t words() const { return words_; }
    void set(int i, int j) { bits_[i * words_ + (j >> 6)] |= (uint64_t(1) << (j & 63)); }
    bool test(int i, int j) const { return (bits_[i * words_ + (j >> 6)] >> (j & 63)) & 1; }
    uint64_t* row(int i) { return bits_.data() + i * words_; }
    const uint64_t* row(int i) const { return bits_.data() + i * words_; }
    /// row(dst) |= row(src) of another (or the same) matrix of the same size
    void or_row(int dst, const BitMatrix& m, int src);

    static BitMatrix from_csr(const Csr& g);
    /// Estimated memory of an n × n matrix in bytes.
    static double bytes(int n) { return double(n) * double((n + 63) / 64) * 8.0; }

private:
    int n_ = 0;
    std::size_t words_ = 0;
    std::vector<uint64_t> bits_;
};

/// Calls fn(j) for every set bit j of a row of `words` 64-bit words.
template <class F>
inline void for_each_bit(const uint64_t* row, std::size_t words, F fn) {
    for (std::size_t w = 0; w < words; ++w) {
        uint64_t x = row[w];
        while (x) {
            int b = __builtin_ctzll(x);
            fn(static_cast<int>(w * 64 + b));
            x &= x - 1;
        }
    }
}

} // namespace dimacs2graphs

#endif
