/**
 * @file Status.hh
 * @brief Exit codes of Strong4VM (Section 13 of the 2.0 requirements)
 */

#ifndef DIMACS2GRAPHS_STATUS_HH
#define DIMACS2GRAPHS_STATUS_HH

namespace dimacs2graphs {

/// Outcome of a run; the numeric value is the process exit code.
enum class ExitCode : int {
    Success = 0,       ///< Success
    Usage = 1,         ///< Unknown option, invalid value, missing input
    Input = 2,         ///< File not found, malformed DIMACS or UVL, duplicate names
    VoidModel = 3,     ///< The formula is unsatisfiable
    Solver = 4,        ///< Solver error
    UnknownName = 5,   ///< Unknown name with --unknown-names error
    StrictUvl = 6,     ///< Skipped constraint with --strict-uvl
    CheckFailed = 7    ///< A consistency check failed (unless --no-fail-on-check)
};

} // namespace dimacs2graphs

#endif
