/**
 * @file GlucoseBackends.hh
 * @brief Factories for the per-release Glucose backends.
 *
 * This header deliberately mentions no Glucose type and pulls in no Glucose
 * header, so SatSolver.cc can dispatch to any vendored release without ever
 * seeing one of their (mutually incompatible) `namespace Glucose` trees. Each
 * factory is defined in its own translation unit, compiled with only that
 * release's engine root on the include path.
 */

#ifndef GLUCOSEBACKENDS_HH
#define GLUCOSEBACKENDS_HH

#include <memory>

#include "sat_interface/SatSolver.hh"

namespace bonedigger {

/// Build a backend over the patched Glucose 3.0 (see GlucoseBackend_3_0.cc).
std::unique_ptr<SatSolver> make_glucose_3_0_backend();

}  // namespace bonedigger

#endif  // GLUCOSEBACKENDS_HH
