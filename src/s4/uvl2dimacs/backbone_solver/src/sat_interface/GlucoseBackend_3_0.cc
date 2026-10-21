/**
 * @file GlucoseBackend_3_0.cc
 * @brief SatSolver backend over the patched Glucose 3.0.
 *
 * Compiled with only sat_solvers/glucose_3_0/ on the include path (plus the MiniSat root
 * for the shared type vocabulary), and with -DGlucose=Glucose_3_0 so this
 * release's namespace and symbols do not collide with Glucose 4.2.1. Because
 * the macro rewrites the namespace token itself, the `Glucose::` spellings in
 * GlucoseBackendImpl.hh resolve to Glucose_3_0:: here without any source change.
 *
 * Glucose 3.0 predates learnt-clause vivification, so BONEDIGGER_GLUCOSE_HAS_LCM
 * is deliberately not defined.
 */

// MiniSat types first: Glucose defines l_True/l_False/l_Undef as macros that
// would otherwise clobber MiniSat's identically named constants.
#include "sat_interface/SatSolver.hh"

#include "sat_interface/GlucoseBackends.hh"

#include "sat_interface/GlucoseExt_3_0.hh"

#include "sat_interface/GlucoseBackendImpl.hh"

namespace bonedigger {

std::unique_ptr<SatSolver> make_glucose_3_0_backend() {
  return std::unique_ptr<SatSolver>(new GlucoseBackendImpl());
}

}  // namespace bonedigger
