/**
 * @file Mig.cc
 * @brief Modal implication graph, unit propagation and weak reach (see Mig.hh)
 */

#include "Mig.hh"

#include <algorithm>
#include <cstdlib>

namespace dimacs2graphs {

Mig::Mig(int num_vars, const std::vector<std::vector<int>>& clauses, const std::vector<int>& fixed) : n_(num_vars) {
    start_.push_back(0);
    std::vector<int> mark(2 * (n_ + 1), -1), c;
    int id = 0;
    for (const auto& clause : clauses) {
        c.clear();
        bool satisfied = false;
        for (int lit : clause) {
            const int v = std::abs(lit);
            const int f = fixed[v];
            if (f != 0) {
                if ((f > 0) == (lit > 0)) { satisfied = true; break; }   // true literal: the clause is satisfied
                continue;                                                  // false literal: deleted
            }
            if (mark[lit_index(-lit)] == id) { satisfied = true; break; }  // tautology
            if (mark[lit_index(lit)] == id) continue;                      // repeated literal
            mark[lit_index(lit)] = id;
            c.push_back(lit);
        }
        ++id;
        if (satisfied || c.empty()) continue;   // empty: impossible in a satisfiable formula with its backbone
        lits_.insert(lits_.end(), c.begin(), c.end());
        start_.push_back(static_cast<int>(lits_.size()));
        const long long k = static_cast<long long>(c.size());
        if (k == 2) strong_edges_ += 2;
        else if (k > 2) weak_edges_ += k * (k - 1);
    }

    occ_start_.assign(2 * (n_ + 1) + 1, 0);
    for (int lit : lits_) ++occ_start_[lit_index(lit) + 1];
    for (size_t i = 1; i < occ_start_.size(); ++i) occ_start_[i] += occ_start_[i - 1];
    occ_.resize(lits_.size());
    std::vector<int> pos(occ_start_.begin(), occ_start_.end() - 1);
    for (int cl = 0; cl < num_clauses(); ++cl)
        for (const int* p = clause_begin(cl); p != clause_end(cl); ++p) occ_[pos[lit_index(*p)]++] = cl;
}

void WitnessPool::add(const std::vector<char>& model) {
    const int word = next_ / 64;
    const std::uint64_t bit = std::uint64_t(1) << (next_ % 64);
    const size_t vars = bits_.size() / kWords;
    for (size_t v = 1; v < vars; ++v) {
        std::uint64_t& b = bits_[v * kWords + word];
        if (v < model.size() && model[v]) b |= bit;
        else b &= ~bit;
    }
    valid_[word] |= bit;
    next_ = (next_ + 1) % (64 * kWords);
}

MigScratch::MigScratch(const Mig& g)
    : g_(g),
      val_epoch_(g.num_vars() + 1, 0),
      val_(g.num_vars() + 1, 0),
      clause_epoch_(g.num_clauses(), 0),
      clause_free_(g.num_clauses(), 0),
      clause_sat_(g.num_clauses(), 0),
      reach_epoch_(2 * (g.num_vars() + 1), 0),
      visit_epoch_(g.num_clauses(), 0),
      visit_entry_(g.num_clauses(), 0) {}

void MigScratch::run(int a, MigJob& job) {
    if (++epoch_ == 0) {   // the counter wrapped: clear every array once
        std::fill(val_epoch_.begin(), val_epoch_.end(), 0);
        std::fill(clause_epoch_.begin(), clause_epoch_.end(), 0);
        std::fill(reach_epoch_.begin(), reach_epoch_.end(), 0);
        std::fill(visit_epoch_.begin(), visit_epoch_.end(), 0);
        epoch_ = 1;
    }
    job.forced.clear();
    job.reach.clear();
    job.conflict = !propagate(a, job.forced);
    weak_reach(a, job.reach);
}

// Sets lit true; false if it is already false (a conflict)
bool MigScratch::assign(int lit, std::vector<int>& trail) {
    const int v = std::abs(lit);
    const signed char s = lit > 0 ? 1 : -1;
    if (val_epoch_[v] == epoch_) return val_[v] == s;
    val_epoch_[v] = epoch_;
    val_[v] = s;
    trail.push_back(lit);
    return true;
}

// Unit propagation from a. Each clause keeps the number of its literals that are not false and whether one is
// true; a clause with no true literal and one literal left forces that literal. forced receives every literal
// set after a. Returns false on a conflict (then a is impossible together with the formula).
bool MigScratch::propagate(int a, std::vector<int>& forced) {
    std::vector<int>& trail = forced;
    assign(a, trail);   // a new epoch: nothing is assigned yet
    size_t head = 0;
    auto touch = [&](int c) {
        if (clause_epoch_[c] != epoch_) {
            clause_epoch_[c] = epoch_;
            clause_free_[c] = g_.clause_size(c);
            clause_sat_[c] = 0;
        }
    };
    while (head < trail.size()) {
        const int x = trail[head++];
        for (const int* p = g_.occ_begin(x); p != g_.occ_end(x); ++p) {   // clauses satisfied by x
            touch(*p);
            clause_sat_[*p] = 1;
        }
        for (const int* p = g_.occ_begin(-x); p != g_.occ_end(-x); ++p) {   // clauses that lose the literal ¬x
            const int c = *p;
            ++work_;
            touch(c);
            if (clause_sat_[c]) continue;
            if (--clause_free_[c] > 1) continue;
            // At most one literal is not false: find it
            int unit = 0;
            bool sat = false;
            for (const int* q = g_.clause_begin(c); q != g_.clause_end(c); ++q) {
                const int v = std::abs(*q);
                if (val_epoch_[v] != epoch_) { unit = *q; continue; }
                if ((val_[v] > 0) == (*q > 0)) { sat = true; break; }
            }
            if (sat) { clause_sat_[c] = 1; continue; }
            if (unit == 0) return false;   // every literal false
            if (!assign(unit, trail)) return false;
        }
    }
    trail.erase(trail.begin());   // a itself is not a forced literal
    return true;
}

// Weak reach T(a): the least set that contains a and, for each x in it and each clause C with ¬x, every literal
// of C other than ¬x. A clause is expanded when it is entered the first time (every literal but the entry one)
// and completed when it is entered by another literal (then the entry literal is added too).
void MigScratch::weak_reach(int a, std::vector<int>& reach) {
    reach.push_back(a);
    reach_epoch_[lit_index(a)] = epoch_;
    auto add = [&](int l) {
        std::uint32_t& e = reach_epoch_[lit_index(l)];
        if (e == epoch_) return;
        e = epoch_;
        reach.push_back(l);
    };
    for (size_t head = 0; head < reach.size(); ++head) {
        const int x = reach[head];
        const int entry = -x;   // the literal of the clauses through which x leads on
        for (const int* p = g_.occ_begin(entry); p != g_.occ_end(entry); ++p) {
            const int c = *p;
            ++work_;
            if (visit_epoch_[c] != epoch_) {
                visit_epoch_[c] = epoch_;
                visit_entry_[c] = entry;
                for (const int* q = g_.clause_begin(c); q != g_.clause_end(c); ++q)
                    if (*q != entry) add(*q);
            } else if (visit_entry_[c] != 0 && visit_entry_[c] != entry) {
                add(visit_entry_[c]);
                visit_entry_[c] = 0;
            }
        }
    }
}

} // namespace dimacs2graphs
