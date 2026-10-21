/**
 * @file SatSolver.cc
 * @brief Engine name parsing and the backend factory.
 *
 * Strong4VM keeps one engine of BoneDigger: the patched Glucose 3.0. This translation unit sees no Glucose
 * header: the backend lives in GlucoseBackend_3_0.cc, compiled with the Glucose root on its include path, and
 * is reached here through the Glucose-free factory of GlucoseBackends.hh. Upstream BoneDigger also offers
 * MiniSat 2.2.0 and Glucose 4.2.1; Strong4VM does not ship them.
 *
 * The detectors and the rest of BoneDigger speak MiniSat types (headers only, see minisat_aux.hh); the Glucose
 * backend converts at its own boundary.
 */

#include "sat_interface/SatSolver.hh"

#include "sat_interface/GlucoseBackends.hh"

namespace bonedigger {

bool parse_solver_kind(const std::string& name, SolverKind& out) {
  // Canonical name carries a space; the separator-free spellings save the caller
  // from quoting it on a shell.
  if (name == "glucose 3.0" || name == "glucose-3.0" ||
      name == "glucose_3.0" || name == "glucose3.0") {
    out = SolverKind::GLUCOSE_3_0;
    return true;
  }
  return false;
}

const char* solver_kind_name(SolverKind kind) {
  switch (kind) {
    case SolverKind::GLUCOSE_3_0:
      return "glucose 3.0";
  }
  return "unknown";
}

const char* supported_solver_names() { return "'glucose 3.0'"; }

bool is_unversioned_solver_name(const std::string& name) {
  return name == "minisat" || name == "glucose";
}

std::unique_ptr<SatSolver> SatSolver::create(SolverKind kind) {
  switch (kind) {
    case SolverKind::GLUCOSE_3_0:
    default:
      return make_glucose_3_0_backend();
  }
}

}  // namespace bonedigger
