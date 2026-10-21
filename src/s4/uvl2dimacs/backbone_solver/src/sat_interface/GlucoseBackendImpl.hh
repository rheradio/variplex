/**
 * @file GlucoseBackendImpl.hh
 * @brief Shared SatSolver backend body for any vendored Glucose release.
 *
 * Every vendored Glucose declares `namespace Glucose` and includes its own
 * headers relative to its engine root, so no two releases can be seen by one
 * translation unit. This header holds the one backend implementation they all
 * share; each release gets a thin .cc that
 *
 *   1. includes SatSolver.hh  (MiniSat types first — Glucose defines
 *      l_True/l_False/l_Undef as macros that would otherwise clobber MiniSat's
 *      identically named constants),
 *   2. includes its own GlucoseExt_<version>.hh,
 *   3. includes this header,
 *   4. defines the factory declared in GlucoseBackends.hh.
 *
 * That .cc must be compiled with only its own engine root on the include path.
 * Keeping the body here rather than duplicating it per release is what makes
 * every engine produce identical backbones: the incremental-mode and
 * relaxation-variable invariants below exist in exactly one place.
 *
 * Define BONEDIGGER_GLUCOSE_HAS_LCM before including this header for releases
 * that carry learnt-clause vivification (4.x; 3.0 predates it).
 *
 * The class lands in an anonymous namespace on purpose: each including
 * translation unit gets its own internal-linkage instantiation over a different
 * `Glucose` namespace, so the identical class name is not an ODR violation.
 */

#ifndef GLUCOSEBACKENDIMPL_HH
#define GLUCOSEBACKENDIMPL_HH

namespace bonedigger {
namespace {

// MiniSat and Glucose both encode lbool as 0=True, 1=False, 2=Undef and expose
// toInt/toLbool. Converting through the integer value sidesteps the fact that
// Glucose defines l_True/l_False/l_Undef as macros that would otherwise clobber
// MiniSat's constants in this dual-include translation unit.
inline Glucose::lbool to_glucose(lbool b) {
  return Glucose::toLbool(Minisat::toInt(b));
}

inline lbool from_glucose(Glucose::lbool b) {
  return Minisat::toLbool(Glucose::toInt(b));
}

inline Glucose::Lit to_glucose(Lit l) {
  return Glucose::mkLit(var(l), sign(l));
}

/// SatSolver backend over one vendored Glucose release.
class GlucoseBackendImpl : public SatSolver {
 public:
  GlucoseBackendImpl() : initial_vars_fixed_(false) {
    // Glucose needs incremental mode for sound repeated solve()+addClause()
    // with assumptions; the relaxation literals added by detectors are treated
    // as selector variables and their clauses are protected from deletion.
    solver_.setIncrementalMode();
#ifdef BONEDIGGER_GLUCOSE_HAS_LCM
    // Disable LCM (learnt-clause vivification, an inprocessing technique). It
    // strengthens learnt clauses using propagations that can depend on the
    // current assumptions, which is unsound once BoneDigger changes assumptions
    // between solve() calls and leads to spurious UNSAT (over-claimed backbone).
    solver_.useLCM = false;
#endif
  }

  Var newVar() override { return solver_.newVar(); }

  void addClause(const vec<Lit>& clause) override {
    gclause_.clear();
    for (int i = 0; i < clause.size(); ++i) gclause_.push(to_glucose(clause[i]));
    solver_.addClause(gclause_);
  }

  void addClause(Lit unit) override { solver_.addClause(to_glucose(unit)); }

  bool solve() override {
    Glucose::vec<Glucose::Lit> none;
    return run(none);
  }

  bool solve(const vec<Lit>& assumptions) override {
    gassumps_.clear();
    for (int i = 0; i < assumptions.size(); ++i)
      gassumps_.push(to_glucose(assumptions[i]));
    return run(gassumps_);
  }

  const vec<lbool>& get_model() const override { return model_; }

  void set_detector_weight(double w) override { solver_.set_detector_weight(w); }
  void bump(Var v) override { solver_.bump(v); }
  void reset_activity_for_var(Var v) override {
    solver_.reset_activity_for_var(v);
  }
  void set_detector_polarity(Var v, lbool b) override {
    solver_.set_detector_polarity(v, to_glucose(b));
  }
  void reset_detector_polarity(Var v) override {
    solver_.reset_detector_polarity(v);
  }

  // Bulk steering: one virtual call for the whole candidate set. Inside this
  // header l_True/l_False are *Glucose's* macros (see the file comment), so
  // they are already Glucose::lbool and need no conversion.
  void bump_and_steer(const LiteralSet& lits) override {
    for (auto li = lits.begin(); li != lits.end(); ++li) {
      const Lit l = *li;
      const Var v = var(l);
      solver_.bump(v);
      solver_.set_detector_polarity(v, sign(l) ? l_False : l_True);
    }
  }

 private:
  bool run(const Glucose::vec<Glucose::Lit>& assumptions) {
    if (!initial_vars_fixed_) {
      // Freeze the boundary between the original formula variables and any
      // later relaxation/selector variables (which get higher indices).
      solver_.initNbInitialVars(solver_.nVars());
      initial_vars_fixed_ = true;
    }
    const bool sat = solver_.solve(assumptions);
    if (sat) sync_model();
    return sat;
  }

  void sync_model() {
    const int n = solver_.model.size();
    model_.clear();
    model_.growTo(n);
    for (int i = 0; i < n; ++i) model_[i] = from_glucose(solver_.model[i]);
  }

  Glucose::GlucoseExt solver_;
  vec<lbool> model_;                 // MiniSat-typed mirror of the Glucose model.
  Glucose::vec<Glucose::Lit> gclause_;
  Glucose::vec<Glucose::Lit> gassumps_;
  bool initial_vars_fixed_;
};

}  // namespace
}  // namespace bonedigger

#endif  // GLUCOSEBACKENDIMPL_HH
