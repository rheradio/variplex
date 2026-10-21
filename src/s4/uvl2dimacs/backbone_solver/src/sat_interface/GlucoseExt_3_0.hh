/**
 * @file GlucoseExt_3_0.hh
 * @brief Extended Glucose 3.0 solver with the BoneDigger attention mechanism
 *
 * The Glucose 3.0 counterpart of upstream's MiniSatExt (not shipped in Strong4VM). It exposes the
 * activity/polarity steering hooks (detector_activity, detector_weight,
 * detector_pol) that BoneDigger uses to override the solver's branching.
 *
 * The underlying Glucose::Solver has been patched (core/Solver.h, core/Solver.cc)
 * with the same additive-VSIDS attention term and decision-phase override used
 * by the patched MiniSat and Glucose 4.2.1, so the detector hooks port verbatim.
 *
 * This header is specific to the tree in src/sat_solvers/glucose_3_0/, whose
 * namespace is renamed to Glucose_3_0 at compile time (-DGlucose=Glucose_3_0) so
 * its symbols do not collide with Glucose 4.2.1. Include it in exactly one
 * translation unit, compiled with only this engine's root on the include path.
 */

#ifndef GLUCOSEEXT_3_0_HH
#define GLUCOSEEXT_3_0_HH
// Included via the release-qualified path (resolved by -I. on src/), not via
// this release's own -I root. The full prefix is what keeps the include from
// resolving into a different vendored Glucose release.
#include "sat_solvers/glucose_3_0/core/Solver.h"

namespace Glucose {

/**
 * @class GlucoseExt
 * @brief Glucose 3.0 solver exposing the BoneDigger activity/polarity hooks
 *
 * Provides the exact same steering surface as Minisat::MiniSatExt:
 *  - bump(): float a candidate variable to the top of the decision heap
 *  - reset_activity_for_var(): clear that boost
 *  - set_detector_weight(): scale the additive detector term
 *  - set_detector_polarity()/reset_detector_polarity(): force/clear decision phase
 */
class GlucoseExt : public Solver {
 public:
  /// Bump the detector activity of a variable (see Minisat::MiniSatExt::bump).
  inline void bump(const Var var) { detectorBumpActivity(var); }

  /// Reset the detector activity of a variable back to zero.
  inline void reset_activity_for_var(Var v) { resetDetectorActivity(v); }

  /// Set the weight combining detector activity with VSIDS activity.
  inline void set_detector_weight(double w) { setDetectorWeight(w); }

  /// Set the detector polarity for a variable (overrides other phase heuristics).
  inline void set_detector_polarity(Var v, lbool b) { setDetectorPolarity(v, b); }

  /// Reset the detector polarity for a variable.
  inline void reset_detector_polarity(Var v) { setDetectorPolarity(v, l_Undef); }
};

}  // namespace Glucose

#endif  // GLUCOSEEXT_3_0_HH
