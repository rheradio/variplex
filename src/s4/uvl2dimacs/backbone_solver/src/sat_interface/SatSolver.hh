/**
 * @file SatSolver.hh
 * @brief Solver-agnostic backend interface for BoneDigger detectors
 *
 * BoneDigger detectors do not talk to a concrete SAT solver directly. Instead
 * they drive an abstract SatSolver backend. Upstream BoneDigger offers the
 * patched MiniSat 2.2.0, Glucose 4.2.1 and Glucose 3.0, selected at runtime by
 * the `-s` command-line flag; Strong4VM vendors only Glucose 3.0, so that is
 * the only backend here.
 *
 * Engine names are version-qualified ("glucose 3.0" — never a bare "minisat"
 * or "glucose").
 *
 * The interface is expressed entirely in MiniSat types (Lit/Var/lbool/vec),
 * which act as BoneDigger's lingua franca (see minisat_aux.hh). The Glucose
 * backend converts to and from Glucose's own types at the boundary, so this
 * header never pulls Glucose into a detector translation unit.
 *
 * Every backend exposes the same attention-mechanism hooks (bump / detector
 * polarity / detector weight) that override the solver's native branching.
 */

#ifndef SATSOLVER_HH
#define SATSOLVER_HH

#include <memory>

#include "LiteralSet.hh"
#include "sat_interface/minisat_aux.hh"

namespace bonedigger {

/// Which underlying SAT engine a detector should drive. Every entry is
/// version-qualified; one enumerator per vendored engine. Strong4VM vendors only
/// Glucose 3.0 (upstream BoneDigger also has MINISAT_2_2_0 and GLUCOSE_4_2_1).
enum class SolverKind { GLUCOSE_3_0 };

/**
 * @brief Parse a solver name into a SolverKind.
 *
 * The only recognized name in Strong4VM is "glucose 3.0". For convenience on a
 * shell it is also accepted without the space: "glucose-3.0", "glucose_3.0"
 * and "glucose3.0".
 *
 * A bare "minisat" or "glucose" is deliberately rejected: engine names are
 * uniformly version-qualified, and for Glucose an unversioned name would not
 * identify a release at all.
 *
 * @param name Solver name (case-sensitive, lowercase expected).
 * @param[out] out Parsed kind on success; left untouched on failure.
 * @return true if the name was recognized.
 */
bool parse_solver_kind(const std::string& name, SolverKind& out);

/// Human-readable name for a SolverKind (e.g. for logging).
const char* solver_kind_name(SolverKind kind);

/// Comma-separated list of the engine names parse_solver_kind() accepts,
/// for usage and error messages.
const char* supported_solver_names();

/// True for a bare, unversioned solver name ("minisat", "glucose") that used to
/// be valid. Lets callers add a targeted hint to the rejection message.
bool is_unversioned_solver_name(const std::string& name);

/**
 * @class SatSolver
 * @brief Abstract SAT backend exposing the BoneDigger steering hooks.
 *
 * The method surface mirrors exactly what the detectors call on a solver. All
 * literals/variables/models are MiniSat types; concrete backends convert as
 * needed. After a successful solve(), get_model() returns the satisfying
 * assignment.
 */
class SatSolver {
 public:
  virtual ~SatSolver() {}

  // Problem construction.
  virtual Var newVar() = 0;
  virtual void addClause(const vec<Lit>& clause) = 0;
  virtual void addClause(Lit unit) = 0;

  // Solving.
  virtual bool solve() = 0;
  virtual bool solve(const vec<Lit>& assumptions) = 0;

  /// The model of the last successful solve(); valid only when solve() returned true.
  virtual const vec<lbool>& get_model() const = 0;

  // Attention mechanism (steering) hooks.
  virtual void set_detector_weight(double w) = 0;
  virtual void bump(Var v) = 0;
  virtual void reset_activity_for_var(Var v) = 0;
  virtual void set_detector_polarity(Var v, lbool b) = 0;
  virtual void reset_detector_polarity(Var v) = 0;

  /**
   * @brief Bump and phase-force every literal in a candidate set, in bulk
   *
   * Equivalent to calling bump() and set_detector_polarity() once per literal,
   * but crosses the virtual boundary once instead of twice per candidate: the
   * backend runs the loop internally with direct, inlinable calls into its
   * engine. This is the hottest BoneDigger-side loop — it runs over the whole
   * candidate set before every solve — so the saved dispatch scales with
   * formula size.
   *
   * LiteralSet is a BoneDigger type, not an engine type: this keeps the
   * interface engine-neutral.
   *
   * @param lits Literals to steer toward (each variable is forced to the
   *             literal's own sign)
   */
  virtual void bump_and_steer(const LiteralSet& lits) = 0;

  /// Factory: build the backend for the requested engine.
  static std::unique_ptr<SatSolver> create(SolverKind kind);
};

}  // namespace bonedigger

#endif  // SATSOLVER_HH
