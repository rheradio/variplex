/**
 * @file RushAndPray.cc
 * @brief Implementation file for RushAndPray
 */

#include "RushAndPray.hh"

using namespace bonedigger;

// Run of the worker
void RushAndPray::run() {
  // Rush: bulk refinement until the candidate count stops shrinking.
  size_t number_of_previous_candidates;
  size_t number_of_current_candidates;
  do {
    number_of_previous_candidates = candidates.size();

    // Early termination if no candidates left
    if (number_of_previous_candidates == 0) break;

    bump_and_solve();
    discard_candidates();
    number_of_current_candidates = candidates.size();
  } while (number_of_previous_candidates != number_of_current_candidates);

  // Pray: verify what survived, one blocking clause per round.
  while (candidates.size()) {
    if (block_and_refine()) break;
  }
}
