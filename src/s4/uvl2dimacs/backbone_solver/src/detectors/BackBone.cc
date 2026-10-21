/**
 * @file BackBone.cc
 * @brief Shared Template Method steps for every backbone detector
 *
 * Everything the detectors of BoneDigger have in common lives here exactly once:
 * solver construction, formula loading, candidate seeding, steering, and the
 * blocking-clause verification step. Only run() varies per detector.
 */

#include "BackBone.hh"

using namespace bonedigger;
using Minisat::lit_Undef;

BackBone::BackBone(Var _max_id, const CNF& _clauses, double _attention_weight,
                   SolverKind _solver_kind)
    : max_id(_max_id),
      clauses(_clauses),
      attention_weight(_attention_weight),
      solver(SatSolver::create(_solver_kind)),
      candidates_iterator(candidates.infinite_iterator()),
      blocking_assumptions(1),
      relaxation_literal(lit_Undef) {}

bool BackBone::initialize() {
  // Initialize the solver
  solver->set_detector_weight(attention_weight);
  for (Var i = 0; i <= max_id; ++i) {
    solver->newVar();
  }
  vec<Lit> ls;
  for (auto ci = clauses.begin(); ci != clauses.end(); ++ci) {
    ls.clear();
    for (auto li = (*ci).begin(); li != (*ci).end(); ++li) {
      const Lit l = *li;
      assert(var(l) <= max_id);
      ls.push(l);
    }
    solver->addClause(ls);
  }

  // Get the first solution of the formula
  const bool is_sat = solver->solve();

  if (!is_sat) {
    // Finish if the formula is unsatisfiable
    return false;
  }

  // Initialize the candidates set with the literals of the first solution
  const vec<lbool>& solution = solver->get_model();

  for (Var variable = 1; variable <= max_id; ++variable) {
    const lbool value = solution[variable];
    if (value != l_Undef && is_wanted(variable)) {
      const Lit l = mkLit(variable, value == l_False);
      candidates.add(l);
    }
  }

  // The formula is satisfiable. Let's go for the backbone!
  return true;
}

bool BackBone::bump_and_solve(const vec<Lit>& assumptions) {
  // One virtual call for the whole candidate set; the backend loops internally
  // with direct, inlinable calls into its engine.
  solver->bump_and_steer(candidates);
  return solver->solve(assumptions);
}

void BackBone::discard_candidates() {
  candidates.discard_from_model(solver->get_model(), max_id,
                                discarded_candidates);
  for (int i = 0; i < discarded_candidates.size(); ++i) {
    const Var v = var(discarded_candidates[i]);
    solver->reset_activity_for_var(v);
    solver->reset_detector_polarity(v);
  }
}

bool BackBone::block_and_refine(bool retire_previous) {
  // Permanently satisfy the blocking clause added by the previous call: with
  // its guard forced true the clause is subsumed at level 0, so the solver
  // stops watching and propagating a constraint that is already spent. Opt-in
  // per detector -- see the header for the measured trade-off.
  if (retire_previous && relaxation_literal != lit_Undef) {
    solver->addClause(relaxation_literal);
  }

  blocking_clause.clear();
  // Create a new relaxation literal
  relaxation_literal = mkLit(solver->newVar());
  blocking_clause.push(relaxation_literal);

  // Create the clause ~lit1 or ~lit2 or ... for all candidates
  const int candidates_size = (int)candidates.size();
  while (blocking_clause.size() <= candidates_size) {
    ++candidates_iterator;
    const Lit lit = *candidates_iterator;
    blocking_clause.push(~lit);
  }

  // Add the new clause
  solver->addClause(blocking_clause);

  // Run the solver enabling the clause (assuming that the relaxation_literal
  // is false)
  blocking_assumptions[0] = ~relaxation_literal;
  const bool is_sat = bump_and_solve(blocking_assumptions);

  // Analyze solver's output
  if (!is_sat) {
    backbone = candidates;
    return true;
  }
  discard_candidates();
  return false;
}
