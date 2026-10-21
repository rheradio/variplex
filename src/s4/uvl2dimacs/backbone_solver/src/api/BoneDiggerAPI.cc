#include "vp_io.h"  // added by variplex (tools/sync_cpp.R)
/**
 * @file BoneDiggerAPI.cc
 * @brief Implementation file for BoneDiggerAPI
 */

// File:   BoneDiggerAPI.cc
// Implementation of BoneDigger API

#include "BoneDiggerAPI.hh"
#include "DIMACSReader.hh"
#include "RushAndPray.hh"
#include "sat_interface/SatSolver.hh"
#include <algorithm>
#include <cstdlib>
#include <iostream>
#include <iomanip>
#include <memory>
#include <set>



using std::endl;

namespace bonedigger {

// Private implementation class (PIMPL pattern)
class BoneDiggerAPI::Impl {
public:
    Impl() : max_id(0), has_file(false), is_sat(false), attention_weight(1.0) {}

    ~Impl() {
        cleanup_detector();
        cleanup_reader();
    }

    bool read_file(const string& file_name) {
        cleanup_detector();
        cleanup_reader();

        // Open the file
        gzFile ff = gzopen(file_name.c_str(), "rb");
        if (ff == Z_NULL) {
            return false;
        }
        // The reader and its buffer live while the file is read: the clauses are copied out of them.
        // (1.x kept the reader, never freed its buffer and never closed the file.)
        bool ok = false;
        try {
            Reader file_reader(ff);
            DIMACSReader dimacs_reader(file_reader);
            dimacs_reader.read();

            // Store the data
            max_id = dimacs_reader.get_max_id();
            clauses = dimacs_reader.get_clause_vector();
            has_file = true;
            is_sat = false;
            ok = true;
        } catch (...) {
            cleanup_reader();
        }
        gzclose(ff);
        return ok;
    }

    bool load_clauses(int nvars, const vector<vector<int>>& cls) {
        cleanup_detector();
        cleanup_reader();
        try {
            CNF loaded;
            loaded.reserve(cls.size());
            LiteralVector lits;
            for (const auto& c : cls) {
                lits.clear();
                for (int l : c) {
                    int v = l < 0 ? -l : l;
                    if (l == 0 || v > nvars) return false;
                    lits.push_back(mkLit(static_cast<Var>(v), l < 0));
                }
                loaded.push_back(LitSet(lits));
            }
            clauses.swap(loaded);
            max_id = nvars;
            has_file = true;
            is_sat = false;
            return true;
        } catch (...) {
            cleanup_reader();
            return false;
        }
    }

    bool create_detector(const string& type) {
        if (!has_file) {
            return false;
        }

        cleanup_detector();

        // Strong4VM keeps one detector, RushAndPray. The names of the detectors of 1.x are still accepted (the
        // backbone is unique, so every detector gives the same result): "one" and "simple" also select the
        // incremental session that compute_in_session() uses; "flatland" is now an alias of "rush".
        if (type == "one" || type == "simple" || type == "flatland" || type == "rush" || type == "rushandpray") {
            detector_set = true;
            return true;
        }
        return false;
    }

    vector<int> compute() {
        vector<int> result;

        if (!has_file || !detector_set) {
            return result;
        }

        if (!detector) {
            try {
                detector.reset(new RushAndPray(max_id, clauses, attention_weight, solver_kind));
                ++instances;
                if (!detector->initialize()) {
                    is_sat = false;
                    cleanup_detector();
                    return result;
                }
                is_sat = true;
                detector->run();
            } catch (...) {
                cleanup_detector();
                return vector<int>();
            }
        }
        return backbone_of(*detector);
    }
    
    vector<int> compute_with_assumptions(const vector<int>& assumptions) {
        vector<int> result;
        compute_with_assumptions_status(assumptions, result);
        return result;
    }

    BoneDiggerAPI::SolveStatus compute_with_assumptions_status(const vector<int>& assumptions, vector<int>& out,
                                                               const vector<char>* wanted = nullptr) {
        using S = BoneDiggerAPI::SolveStatus;
        out.clear();
        if (!has_file) return S::Error;

        // Build a modified CNF by adding assumption unit clauses
        CNF modified_clauses = clauses;
        for (int assump : assumptions) {
            if (assump == 0 || std::abs(assump) > max_id) return S::Error;
            Var var = (Var)(std::abs(assump));  // MiniSat vars are 1-indexed here, matching DIMACS
            bool sign = (assump < 0);           // true = negative literal in MiniSat
            LiteralVector unit;
            unit.push_back(mkLit(var, sign));
            modified_clauses.push_back(LitSet(unit));
        }

        std::unique_ptr<RushAndPray> det;
        try {
            det.reset(new RushAndPray(max_id, modified_clauses, attention_weight, solver_kind));
        } catch (...) {
            return S::Error;
        }
        ++instances;

        S status = S::Unsat;
        try {
            det->set_candidate_filter(wanted);
            if (det->initialize()) {
                status = S::Sat;
                det->run();
                out = backbone_of(*det);
            }
        } catch (...) {
            out.clear();
            status = S::Error;
        }
        return status;
    }

    /**
     * Builds the solver that is kept between the calls of compute_in_session(): the formula is loaded
     * once. Returns false if no formula is loaded.
     */
    bool prepare_session() {
        if (!has_file) return false;
        if (session) return true;
        try {
            std::unique_ptr<SatSolver> solver = SatSolver::create(solver_kind);
            solver->set_detector_weight(attention_weight);
            for (Var i = 0; i <= max_id; ++i) solver->newVar();
            vec<Lit> ls;
            for (auto ci = clauses.begin(); ci != clauses.end(); ++ci) {
                ls.clear();
                for (auto li = (*ci).begin(); li != (*ci).end(); ++li) ls.push(*li);
                solver->addClause(ls);
            }
            session = std::move(solver);
            ++instances;
            return true;
        } catch (...) {
            session.reset();
            return false;
        }
    }

    /**
     * Backbone of the formula under the assumptions, among the wanted variables, computed with the solver
     * of the session. The assumptions are passed to the solver as such (the formula is not copied), so
     * what the solver learns in one call is still valid in the next ones. The algorithm is the one of
     * detector "one" of BoneDigger (CheckCandidatesOneByOne, which Strong4VM no longer ships as a detector): the
     * candidates are the literals of a first solution; each call to the solver either confirms one candidate or
     * discards every candidate that the new solution contradicts. No clause is added, so the solver is reused.
     */
    BoneDiggerAPI::SolveStatus compute_in_session(const vector<int>& assumptions, vector<int>& out,
                                                  const vector<char>* wanted,
                                                  const vector<char>* literal_flags = nullptr,
                                                  vector<vector<char>>* models = nullptr) {
        using S = BoneDiggerAPI::SolveStatus;
        out.clear();
        if (!prepare_session()) return S::Error;
        try {
            SatSolver& solver = *session;
            vec<Lit> assume;
            for (int a : assumptions) {
                if (a == 0 || std::abs(a) > max_id) return S::Error;
                assume.push(mkLit(std::abs(a), a < 0));
            }
            if (!solver.solve(assume)) return S::Unsat;

            // Every solution found is handed to the caller, which may use it as a witness for later calls
            auto keep_model = [&]() {
                if (!models) return;
                vector<char> m(max_id + 1, 0);
                const vec<lbool>& model = solver.get_model();
                for (Var v = 1; v <= max_id; ++v) m[v] = model[v] == l_True;
                models->push_back(std::move(m));
            };
            keep_model();

            // Candidates: the literals of the first solution, for the wanted variables only; with literal
            // flags, only the wanted polarity of each variable (bit 1: the positive literal, bit 2: the negative)
            LiteralSet candidates;
            {
                const vec<lbool>& solution = solver.get_model();
                for (Var v = 1; v <= max_id; ++v) {
                    if (wanted && (static_cast<size_t>(v) >= wanted->size() || !(*wanted)[v])) continue;
                    const lbool value = solution[v];
                    if (value == l_Undef) continue;
                    if (literal_flags) {
                        const char f = static_cast<size_t>(v) < literal_flags->size() ? (*literal_flags)[v] : 0;
                        if (!(f & (value == l_True ? 1 : 2))) continue;
                    }
                    candidates.add(mkLit(v, value == l_False));
                }
            }
            const_infinite_LiteralSetIterator it = candidates.infinite_iterator();
            vec<Lit> discarded;
            assume.push(Minisat::lit_Undef);
            while (candidates.size()) {
                ++it;
                const Lit candidate = *it;
                assume.last() = ~candidate;
                // Guide the solver towards solutions that contradict the remaining candidates
                solver.bump_and_steer(candidates);
                if (!solver.solve(assume)) {
                    // No solution with the candidate false: it belongs to the backbone
                    out.push_back(sign(candidate) ? -var(candidate) : var(candidate));
                    candidates.remove(candidate);
                    solver.reset_activity_for_var(var(candidate));
                    solver.reset_detector_polarity(var(candidate));
                } else {
                    keep_model();
                    candidates.discard_from_model(solver.get_model(), max_id, discarded);
                    for (int i = 0; i < discarded.size(); ++i) {
                        solver.reset_activity_for_var(var(discarded[i]));
                        solver.reset_detector_polarity(var(discarded[i]));
                    }
                }
            }
            std::sort(out.begin(), out.end(), [](int a, int b) { return std::abs(a) < std::abs(b); });
            return S::Sat;
        } catch (...) {
            // The state of the solver is unknown: build a new one for the next call
            out.clear();
            session.reset();
            return S::Error;
        }
    }

    long get_instances() const { return instances; }

    void set_weight(double w) {
        attention_weight = w;
        if (session) session->set_detector_weight(w);
    }
    int get_max_var() const { return max_id; }
    bool get_is_sat() const { return is_sat; }
    
    void print_bb() const {
        if (!is_sat) {
            vp::out() << "Formula is UNSATISFIABLE" << endl;
            return;
        }
        
        if (!has_file || !detector) {
            vp::out() << "No backbone computed yet" << endl;
            return;
        }
        
        // Print formula statistics
        vp::out() << "Formula statistics:" << endl;
        vp::out() << "  Variables: " << max_id << endl;
        vp::out() << "  Clauses: " << clauses.size() << endl;
        vp::out() << "Formula is SATISFIABLE" << endl;
        
        // Count and collect backbone literals
        vector<int> backbone_lits;
        if (detector) backbone_lits = backbone_of(*detector);

        // Calculate percentage
        double percentage = (max_id > 0) ? (100.0 * backbone_lits.size() / max_id) : 0.0;
        
        vp::out() << "Backbone size: " << backbone_lits.size() << " literals";
        vp::out() << " (" << std::fixed << std::setprecision(2) << percentage << "% of variables)" << endl;
        
        if (backbone_lits.size() > 0) {
            vp::out() << "Backbone literals: ";
            for (int lit : backbone_lits) {
                vp::out() << lit << " ";
            }
            vp::out() << endl;
        }
    }
    
    bool set_solver_kind(const string& name) { return parse_solver_kind(name, solver_kind); }

private:
    /// The backbone found by a detector, as DIMACS literals sorted by variable
    vector<int> backbone_of(const RushAndPray& det) const {
        vector<int> lits;
        for (Var v = 1; v <= max_id; ++v) {
            if (det.is_backbone(v)) lits.push_back(det.backbone_sign(v) ? v : -v);
        }
        return lits;
    }

    void cleanup_detector() {
        detector.reset();
        detector_set = false;
    }
    
    void cleanup_reader() {
        clauses.clear();
        max_id = 0;
        has_file = false;
        session.reset();
    }
    
    Var max_id;
    CNF clauses;
    std::unique_ptr<SatSolver> session;    ///< Solver kept between the calls of compute_in_session()
    long instances = 0;                    ///< Solvers built so far (one per detector, one per session)
    std::unique_ptr<RushAndPray> detector; ///< Detector of compute(), kept for print_bb()
    bool detector_set = false;             ///< create_detector() was called with a known name
    SolverKind solver_kind = SolverKind::GLUCOSE_3_0;
    bool has_file;
    bool is_sat;
    double attention_weight;
};

// BoneDiggerAPI implementation

BoneDiggerAPI::BoneDiggerAPI() : pimpl(new Impl()) {}

BoneDiggerAPI::~BoneDiggerAPI() {
    delete pimpl;
}

bool BoneDiggerAPI::read_dimacs(const string& file_name) {
    return pimpl->read_file(file_name);
}

bool BoneDiggerAPI::create_backbone_detector(const string& bb_detector) {
    return pimpl->create_detector(bb_detector);
}

vector<int> BoneDiggerAPI::compute_backbone() {
    return pimpl->compute();
}

int BoneDiggerAPI::get_max_variable() const {
    return pimpl->get_max_var();
}

void BoneDiggerAPI::set_attention_weight(double weight) {
    pimpl->set_weight(weight);
}

bool BoneDiggerAPI::is_satisfiable() const {
    return pimpl->get_is_sat();
}

void BoneDiggerAPI::print_backbone() const {
    pimpl->print_bb();
}

vector<int> BoneDiggerAPI::compute_backbone_with_assumptions(const vector<int>& assumptions) {
    return pimpl->compute_with_assumptions(assumptions);
}

bool BoneDiggerAPI::load_formula(int max_var, const vector<vector<int>>& clauses) {
    return pimpl->load_clauses(max_var, clauses);
}

BoneDiggerAPI::SolveStatus BoneDiggerAPI::compute_backbone(vector<int>& backbone) {
    backbone.clear();
    try {
        backbone = pimpl->compute();
    } catch (...) {
        backbone.clear();
        return SolveStatus::Error;
    }
    if (pimpl->get_is_sat()) return SolveStatus::Sat;
    // compute() leaves is_sat false both for UNSAT and for errors; tell them apart
    // by checking satisfiability directly.
    vector<int> none;
    SolveStatus s = pimpl->compute_with_assumptions_status({}, none);
    return s == SolveStatus::Sat ? SolveStatus::Error : s;
}

BoneDiggerAPI::SolveStatus BoneDiggerAPI::compute_backbone_with_assumptions(const vector<int>& assumptions,
                                                                           vector<int>& backbone) {
    return pimpl->compute_with_assumptions_status(assumptions, backbone);
}

BoneDiggerAPI::SolveStatus BoneDiggerAPI::compute_backbone_with_assumptions(const vector<int>& assumptions,
                                                                           vector<int>& backbone,
                                                                           const vector<char>& wanted_variables) {
    return pimpl->compute_with_assumptions_status(assumptions, backbone, &wanted_variables);
}

bool BoneDiggerAPI::set_solver(const string& solver) {
    return pimpl->set_solver_kind(solver);
}

string BoneDiggerAPI::supported_solvers() {
    return supported_solver_names();
}

long BoneDiggerAPI::solver_instances() const {
    return pimpl->get_instances();
}

bool BoneDiggerAPI::prepare_incremental() {
    return pimpl->prepare_session();
}

BoneDiggerAPI::SolveStatus BoneDiggerAPI::compute_backbone_incremental(const vector<int>& assumptions,
                                                                      vector<int>& backbone,
                                                                      const vector<char>& wanted_variables) {
    return pimpl->compute_in_session(assumptions, backbone, &wanted_variables);
}

BoneDiggerAPI::SolveStatus BoneDiggerAPI::compute_backbone_incremental_literals(const vector<int>& assumptions,
                                                                               vector<int>& backbone,
                                                                               const vector<char>& literal_flags,
                                                                               vector<vector<char>>* models) {
    return pimpl->compute_in_session(assumptions, backbone, nullptr, &literal_flags, models);
}

} // namespace bonedigger
