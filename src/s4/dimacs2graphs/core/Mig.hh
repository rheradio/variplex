/**
 * @file Mig.hh
 * @brief Modal implication graph (MIG) of a formula, used by the main loop to avoid solver calls
 *
 * The MIG has one node per literal. A clause with two literals gives strong edges (¬a ⇒ b, ¬b ⇒ a); a longer
 * clause gives weak edges (¬l_i ⇢ l_j for every pair). As in Krieter's "improvement 3", the long clauses are kept
 * as clauses and walked through occurrence lists, never expanded into k(k-1) edges.
 *
 * For a job "which query literals does the literal a force?" the MIG gives, without the solver:
 *   - the literals that unit propagation derives from a (strong reach, extended through long clauses whose
 *     other literals are already false): they are forced;
 *   - the literals reachable from a through strong and weak edges (the weak reach T(a)): only they can be
 *     forced. If F ∧ a is satisfiable, l ∉ T(a) and F ⊭ l, then F ∧ a ⊭ l (see mig_doc/mig_doc.pdf);
 * and a witness pool of solutions refutes more candidates. Only the literals that remain go to the solver.
 *
 * The graph is built once and read by every worker; each worker has its own MigScratch.
 */

#ifndef DIMACS2GRAPHS_MIG_HH
#define DIMACS2GRAPHS_MIG_HH

#include <cstdint>
#include <cstdlib>
#include <vector>

namespace dimacs2graphs {

/// Index of a DIMACS literal in the per-literal arrays: 2v for v, 2v+1 for ¬v.
inline int lit_index(int lit) { return lit > 0 ? 2 * lit : 2 * (-lit) + 1; }

class Mig {
public:
    /**
     * @brief Builds the MIG of a formula simplified with its global backbone.
     * @param num_vars Variables of the formula
     * @param clauses  Clauses as DIMACS literals
     * @param fixed    fixed[v] = +1 if v is true in every solution, -1 if false in every solution, 0 otherwise
     *
     * Clauses satisfied by the backbone and tautologies are dropped, false literals and repeated literals are
     * deleted. What remains has the same solutions as the formula once the backbone is fixed.
     */
    Mig(int num_vars, const std::vector<std::vector<int>>& clauses, const std::vector<int>& fixed);

    int num_vars() const { return n_; }
    int num_clauses() const { return static_cast<int>(start_.size()) - 1; }
    long long strong_edges() const { return strong_edges_; }   ///< 2 per two-literal clause
    long long weak_edges() const { return weak_edges_; }       ///< k(k-1) per clause of k > 2 literals (not stored)

    const int* clause_begin(int c) const { return lits_.data() + start_[c]; }
    const int* clause_end(int c) const { return lits_.data() + start_[c + 1]; }
    int clause_size(int c) const { return start_[c + 1] - start_[c]; }
    /// Clauses that contain the literal lit
    const int* occ_begin(int lit) const { return occ_.data() + occ_start_[lit_index(lit)]; }
    const int* occ_end(int lit) const { return occ_.data() + occ_start_[lit_index(lit) + 1]; }

private:
    int n_ = 0;
    std::vector<int> lits_, start_;      ///< Clause c is lits_[start_[c] .. start_[c+1])
    std::vector<int> occ_, occ_start_;   ///< Clauses of each literal, indexed by lit_index
    long long strong_edges_ = 0, weak_edges_ = 0;
};

/// Up to 64 * kWords solutions of the formula, stored bit-parallel: bit s of word w of variable v is the value of v in
/// solution 64w + s.
class WitnessPool {
public:
    static constexpr int kWords = 4;
    explicit WitnessPool(int num_vars) : bits_((num_vars + 1) * kWords, 0) {}
    /// Adds a solution (model[v] != 0: v true), replacing the oldest one when the pool is full
    void add(const std::vector<char>& model);
    /// True if a stored solution makes a true and l false: then a does not force l
    bool refutes(int a, int l) const {
        const std::uint64_t* pa = &bits_[static_cast<size_t>(std::abs(a)) * kWords];
        const std::uint64_t* pl = &bits_[static_cast<size_t>(std::abs(l)) * kWords];
        for (int w = 0; w < kWords; ++w) {
            const std::uint64_t with_a = valid_[w] & (a > 0 ? pa[w] : ~pa[w]);
            const std::uint64_t without_l = l > 0 ? ~pl[w] : pl[w];
            if (with_a & without_l) return true;
        }
        return false;
    }

private:
    std::vector<std::uint64_t> bits_;
    std::uint64_t valid_[kWords] = {};
    int next_ = 0;
};

/// What the MIG says about one literal a.
struct MigJob {
    bool conflict = false;            ///< Unit propagation from a failed (a is impossible): nothing is pruned
    std::vector<int> forced;          ///< Literals derived by unit propagation (a excluded)
    std::vector<int> reach;           ///< Literals of the weak reach T(a) (a included), forced ones included
};

/// Scratch arrays of one worker, reset in O(1) between jobs by epochs.
class MigScratch {
public:
    explicit MigScratch(const Mig& g);
    /// Unit propagation and weak reach from the literal a
    void run(int a, MigJob& job);
    /// Value of the variable v in the last propagation: +1, -1, or 0 if unassigned
    int value(int v) const { return val_epoch_[v] == epoch_ ? val_[v] : 0; }
    /// True if the literal l is in the weak reach of the last job
    bool in_reach(int l) const { return reach_epoch_[lit_index(l)] == epoch_; }
    long long work() const { return work_; }   ///< Clause visits since the scratch was created

private:
    bool propagate(int a, std::vector<int>& forced);
    void weak_reach(int a, std::vector<int>& reach);
    bool assign(int lit, std::vector<int>& trail);

    const Mig& g_;
    std::uint32_t epoch_ = 0;
    std::vector<std::uint32_t> val_epoch_;
    std::vector<signed char> val_;
    std::vector<std::uint32_t> clause_epoch_;   ///< Propagation: counts of the clause are valid in this epoch
    std::vector<int> clause_free_;              ///< Literals of the clause not yet false
    std::vector<char> clause_sat_;              ///< Some literal of the clause is true
    std::vector<std::uint32_t> reach_epoch_;    ///< Per literal index
    std::vector<std::uint32_t> visit_epoch_;    ///< Weak reach: the clause was entered in this epoch
    std::vector<int> visit_entry_;              ///< Literal by which it was entered (0: every literal added)
    long long work_ = 0;
};

} // namespace dimacs2graphs

#endif
