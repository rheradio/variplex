/**
 * @file RushAndPray.hh
 * @brief The rush-and-pray backbone detector (`backbone_solver -r`), the only one Strong4VM ships
 *
 * Combines fast elimination with verification phase.
 * Named "rush and pray" because it rushes through elimination
 * and then verifies remaining candidates.
 */

#ifndef RUSHANDPRAY_HH
#define RUSHANDPRAY_HH

#include "BackBone.hh"

namespace bonedigger {

/**
 * @class RushAndPray
 * @ingroup BackboneDetectors
 * @brief Experimental backbone detector with rush and verify strategy
 *
 * This algorithm uses a two-phase approach:
 *
 * 1. **Rush phase**:
 *    - Quickly eliminates easy non-backbone candidates using activity bumping
 *    - Repeats bulk refinement until the candidate count stops shrinking
 *
 * 2. **Verify phase**:
 *    - Explicitly verifies the remaining candidates with blocking clauses
 *    - Each round forbids the current candidate assignment and re-solves
 *
 * The "pray" part refers to hoping that the rush phase eliminates most
 * non-backbone candidates, leaving only a small number to verify.
 *
 * Every step other than run() is inherited from BackBone.
 */
class RushAndPray : public BackBone {
 public:
  using BackBone::BackBone;

  /**
   * @brief Run rush-and-verify backbone detection
   *
   * Performs bulk elimination until it converges, then verifies the survivors
   * with the shared blocking-clause loop.
   */
  void run() override;
};

}  // end of namespace bonedigger

#endif  // RUSHANDPRAY_HH
