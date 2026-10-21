/**
 * @file BackBone.hh
 * @brief Template Method base class for backbone detection algorithms
 *
 * Holds the pipeline every detector shares (solver setup, candidate seeding,
 * steering, model-driven refinement, blocking-clause verification, result
 * queries) and leaves exactly one step abstract: run(), the schedule of solver
 * calls that distinguishes one algorithm from another.
 */

#ifndef BACKBONE_HH
#define BACKBONE_HH

#include <memory>
#include <vector>

#include "DIMACSReader.hh"
#include "LiteralSet.hh"
#include "sat_interface/SatSolver.hh"

/**
 * @defgroup BackboneDetectors Backbone Detection Algorithms
 * @brief Algorithms for computing the backbone of Boolean formulas
 *
 * ## Overview
 *
 * The backbone of a Boolean formula is the set of literals that must have the
 * same value in all satisfying assignments. BoneDigger provides several algorithms
 * for computing backbones, each with different performance characteristics.
 *
 * ## The detector of Strong4VM
 *
 * Strong4VM ships one detector, bonedigger::RushAndPray, on one engine, the
 * patched Glucose 3.0 (see SatSolver.hh), with attention weight 1: the command
 * line `backbone_solver -r -a 1 -s 'glucose 3.0'`.
 *
 * - **Strategy:** rush and verify. The candidates are the literals of a first
 *   solution. Rush: steer the solver towards solutions that contradict the
 *   candidates and drop every candidate a new solution contradicts, until a
 *   round drops nothing. Verify: forbid the remaining assignment with a blocking
 *   clause and solve again, until the solver proves that none is left.
 * - **Used for:** the core and dead features of Strong4VM (the global backbone),
 *   the backbone simplification of uvl2dimacs, and the API calls that are not
 *   incremental (BoneDiggerAPI::compute_backbone_with_assumptions()).
 *
 * The main loop of Strong4VM, one question per feature that can vary, does not
 * use a detector: a detector adds blocking clauses, so its solver serves one
 * question only. BoneDiggerAPI::compute_backbone_incremental() and
 * BoneDiggerAPI::compute_backbone_incremental_literals() keep one Glucose solver
 * for all the questions of a thread and check the candidates one by one.
 *
 * Upstream BoneDigger has two more detectors, "check candidates one by one"
 * (`-o`) and "fast on cliffs, slow on plains" (`-f`), and two more engines,
 * MiniSat 2.2.0 and Glucose 4.2.1. Strong4VM does not ship them; the detector
 * names "one", "simple" and "flatland" of 1.x are accepted and run RushAndPray.
 *
 * ## Implementing a New Detector
 *
 * BackBone is a Template Method base: it already implements every step that
 * the detectors of BoneDigger have in common, so a new detector only supplies
 * run().
 *
 * @code
 * #include "BackBone.hh"
 *
 * namespace bonedigger {
 *
 * class MyDetector : public BackBone {
 *  public:
 *   using BackBone::BackBone;   // inherit (max_id, clauses, weight, kind)
 *
 *   // The only required override: schedule the solver calls.
 *   void run() override {
 *     while (candidates.size()) {
 *       if (!bump_and_solve()) break;
 *       discard_candidates();
 *     }
 *   }
 * };
 *
 * } // namespace bonedigger
 * @endcode
 *
 * ### Steps inherited from BackBone
 *
 * - initialize(): loads the formula, runs the first solve, seeds `candidates`
 *   from the first model. Returns false if the formula is unsatisfiable.
 * - bump_and_solve(): steers the solver toward re-deriving the current
 *   candidate assignment, then solves (optionally under assumptions).
 * - discard_candidates(): drops every candidate the latest model contradicts
 *   and clears the steering state of the dropped variables.
 * - block_and_refine(): adds a relaxation-guarded blocking clause forbidding
 *   the current candidate assignment and re-solves. Returns true when the
 *   solver proves UNSAT, which confirms the survivors as the backbone.
 * - is_backbone() / backbone_sign(): result queries, non-virtual so the CLI's
 *   per-variable print loop does not pay for dispatch.
 *
 * ### Integration
 *
 * After implementing your detector:
 * 1. Add it to the factory function in cli/main.cc
 * 2. Add it to BoneDiggerAPI.cc for API access
 * 3. Add its source to MAIN_SRCS and API_EXAMPLE_SRCS in src/Makefile
 * 4. Add a command-line option for your detector
 */

namespace bonedigger {
using Minisat::Lit;
using Minisat::Var;
using Minisat::vec;

/**
 * @class BackBone
 * @ingroup BackboneDetectors
 * @brief Template Method base for backbone detection algorithms
 *
 * The invariant shape of every BoneDigger detector is: seed candidates from a
 * first model, then repeatedly ask the solver for a *different* model and drop
 * every candidate the new model contradicts, until a final UNSAT proof confirms
 * the survivors. This class owns that shape. Subclasses override only run(),
 * which decides how the solver calls are scheduled.
 *
 * Typical usage:
 * @code
 * BackBone* detector = new ConcreteDetector(max_id, clauses, weight, kind);
 * if (detector->initialize()) {
 *     detector->run();
 *     // Query results with is_backbone() and backbone_sign()
 * }
 * @endcode
 */
class BackBone {
 public:
  /**
   * @brief Construct a detector over a CNF formula
   * @param max_id Maximum variable ID
   * @param clauses CNF formula (borrowed; must outlive the detector)
   * @param attention_weight Weight for detector activity in variable ordering
   * @param solver_kind Underlying SAT engine to drive
   */
  BackBone(Var max_id, const CNF& clauses, double attention_weight = 1.0,
           SolverKind solver_kind = SolverKind::GLUCOSE_3_0);

  virtual ~BackBone() {}

  /**
   * @brief Load the formula, check satisfiability, seed the candidate set
   *
   * Shared by every detector. Must be called before run().
   *
   * @return true if the instance is satisfiable
   * @return false if the instance is unsatisfiable
   */
  virtual bool initialize();

  /**
   * @brief Run the backbone detection algorithm
   *
   * The one varying step of the Template Method. Assumes initialize() has been
   * called and returned true. After this returns, is_backbone() answers
   * correctly.
   */
  virtual void run() = 0;

  /**
   * @brief Check if a literal is in the backbone
   * @param literal The literal to check
   * @return true if the literal must appear in all satisfying assignments
   */
  bool is_backbone(const Lit& literal) const { return backbone.get(literal); }

  /**
   * @brief Check if a variable is in the backbone
   * @param var The variable to check
   * @return true if the variable has a fixed value in all satisfying assignments
   */
  bool is_backbone(Var var) const {
    return is_backbone(~mkLit(var)) || is_backbone(mkLit(var));
  }

  /**
   * @brief Get the sign of a backbone variable
   *
   * Only meaningful for variables that are in the backbone.
   *
   * @param var The backbone variable
   * @return true if the variable must be true in all satisfying assignments
   */
  bool backbone_sign(Var var) const {
    assert(is_backbone(var));
    return is_backbone(mkLit(var));
  }

  /**
   * @brief Restrict the search to some variables (Strong4VM)
   *
   * By default every variable is a candidate. With a filter, only the
   * literals of the variables v with (*wanted)[v] != 0 become candidates in
   * initialize(); the other variables are neither tested nor reported by
   * is_backbone(). A caller that needs the status of a few variables only
   * (for instance, when the rest are known to be fixed, or are of no
   * interest) saves the solver work for every variable left out.
   *
   * Must be called before initialize(). The vector must outlive the detector.
   *
   * @param wanted Flags indexed by variable, or nullptr for every variable
   */
  void set_candidate_filter(const std::vector<char>* wanted) { wanted_vars = wanted; }

 protected:
  /**
   * @brief Whether the literals of a variable may be candidates
   */
  bool is_wanted(Var v) const {
    return !wanted_vars || (v >= 0 && static_cast<size_t>(v) < wanted_vars->size() && (*wanted_vars)[v]);
  }

  /**
   * @brief Steer the solver toward the current candidates, then solve
   *
   * Bumps the detector activity of every candidate variable and forces its
   * branch phase to the candidate's sign, so the next model either confirms the
   * candidates cheaply or exposes a contradiction fast.
   *
   * @param assumptions Literals to assume for this call
   * @return true if satisfiable
   */
  bool bump_and_solve(const vec<Lit>& assumptions);

  /**
   * @brief Steer the solver toward the current candidates, then solve
   * @return true if satisfiable
   */
  bool bump_and_solve() { return bump_and_solve(no_assumptions); }

  /**
   * @brief Drop every candidate contradicted by the solver's latest model
   *
   * Also clears the steering state of the dropped variables so they stop
   * competing for branching decisions.
   */
  void discard_candidates();

  /**
   * @brief Forbid the current candidate assignment and re-solve
   *
   * Adds the clause (r | ~c1 | ~c2 | ...) over the current candidates, guarded
   * by a fresh relaxation literal r, and solves under the assumption ~r.
   *
   * @param retire_previous When true, the previous call's blocking clause is
   *        permanently satisfied first (its guard is asserted as a unit), so
   *        the spent clause is subsumed at level 0 and stops being watched and
   *        propagated. Logically a no-op either way — an unassumed guard is
   *        already free, so the old clause is inert — but it changes the search
   *        trajectory. RushAndPray calls this back-to-back, so spent clauses
   *        pile up fast and retiring them is a consistent win (upstream
   *        measurements: coreboot -23%, embtoolkit and uClibc -12%, never a
   *        regression across the ten example formulas). Upstream's
   *        "fast on cliffs" detector, not shipped here, opts out.
   * @return true if the solver proved UNSAT — the survivors are the backbone,
   *         and `backbone` has been set. false if a new model was found, in
   *         which case the contradicted candidates have been discarded.
   */
  bool block_and_refine(bool retire_previous = true);

  const Var max_id;                   ///< Maximum variable ID
  const CNF& clauses;                 ///< CNF formula
  const double attention_weight;      ///< Weight for detector activity
  std::unique_ptr<SatSolver> solver;  ///< SAT solver backend (Glucose 3.0 in Strong4VM)
  LiteralSet candidates;              ///< Candidate backbone literals
  LiteralSet backbone;                ///< Confirmed backbone literals
  vec<Lit> discarded_candidates;      ///< Candidates dropped by the last refinement
  /// Round-robin cursor over `candidates` (declared after it: binds by reference)
  const_infinite_LiteralSetIterator candidates_iterator;

 private:
  const std::vector<char>* wanted_vars = nullptr;  ///< Candidate filter (not owned)
  const vec<Lit> no_assumptions;   ///< Empty assumption vector, reused
  vec<Lit> blocking_clause;        ///< Scratch buffer for block_and_refine()
  vec<Lit> blocking_assumptions;   ///< Single-element ~relaxation assumption
  Lit relaxation_literal;          ///< Guard of the blocking clause in flight
};

}  // end of namespace bonedigger

#endif  // BACKBONE_HH
