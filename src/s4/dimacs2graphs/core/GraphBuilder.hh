/**
 * @file GraphBuilder.hh
 * @brief Global backbone and the main loop of graph generation (R-PIPE-01 steps 5–8)
 *
 * Only the variables of the query set Q are assumed and reported (R-PIPE-02,
 * R-PERF-01). For each v in Q, the backbone under v = true gives
 *   - the arc v → i of the requires graph for each i in Q that is true, and
 *   - the edge {v, i} of the excludes graph for each i in Q that is false;
 * with --or-graph, the backbone under v = false gives
 *   - the edge {v, i} of the "at least one" graph for each i in Q that is true, and
 *   - the implied arc i → v for each i in Q that is false (cross-check, R-OR-02).
 *
 * With the modal implication graph (GraphBuildOptions::mig, Mig.hh), unit propagation gives the links that
 * need no solver, the weak reach discards the literals that cannot be forced, and stored solutions refute
 * more; the solver only checks what is left. The links are the same.
 *
 * Threads (R-IMP-03, R-PERF-02..04): one solver per worker, created in the
 * calling thread before the workers start; an atomic counter hands out the
 * next variable; results are integer pairs merged and sorted once, so the
 * output does not depend on the number of threads.
 */

#ifndef DIMACS2GRAPHS_GRAPH_BUILDER_HH
#define DIMACS2GRAPHS_GRAPH_BUILDER_HH

#include "../io/DimacsFormula.hh"
#include "../io/OutputFiles.hh"
#include "Status.hh"
#include "../filter/Options.hh"

#include <cstdint>
#include <string>
#include <vector>

namespace dimacs2graphs {

using ProgressMode = Progress;

/// Status of a variable after the global backbone (R-CLS-02).
enum class VarStatus : std::int8_t { Variable = 0, Core = 1, Dead = -1 };

struct GlobalBackbone {
    bool satisfiable = false;
    std::vector<VarStatus> status;  ///< Index 1..num_vars
    std::vector<int> literals;      ///< Backbone literals
};

/**
 * @brief Computes the global backbone of a formula.
 * @return Success, VoidModel (unsatisfiable; bb.satisfiable = false) or Solver.
 */
ExitCode compute_global_backbone(const DimacsFormula& f, const std::string& detector,
                                 GlobalBackbone& bb, std::string& error);

struct GraphBuildOptions {
    int threads = 1;
    std::string detector = "one";
    bool or_graph = false;
    bool mig = true;   ///< Use the modal implication graph to skip solver calls (only with the detector "one")
    ProgressMode progress = ProgressMode::Auto;
};

/// What the modal implication graph saved (all zero when it was not used).
struct MigStats {
    bool used = false;
    long long clauses = 0;                  ///< Clauses left after simplification with the global backbone
    long long strong_edges = 0;             ///< From the two-literal clauses
    long long weak_edges = 0;               ///< Implied by the longer clauses (not stored)
    long long jobs = 0;                     ///< Literals assumed (one per queried variable, two with --or-graph)
    long long jobs_without_solver = 0;      ///< Jobs answered by the graph and the witnesses alone
    long long forced_by_propagation = 0;    ///< Links found by unit propagation, without the solver
    long long literals_in_reach = 0;        ///< Candidate literals left by the weak reach
    long long refuted_by_witness = 0;       ///< Of those, refuted by a stored solution
    long long candidates_to_solver = 0;     ///< Of those, given to the solver
    long long solver_solutions = 0;         ///< Solutions the solver found (each one is kept as a witness)
    long long possible_candidates = 0;      ///< Candidate literals without the graph, for comparison
    long long graph_work = 0;               ///< Clause visits of propagation and weak reach
    // Times in seconds. The *_seconds of the jobs are thread time: summed over the workers, so with several
    // threads they can add up to more than the wall time of the loop.
    double build_seconds = 0;               ///< Building the graph (wall, before the workers start)
    double setup_seconds = 0;               ///< Creating the solvers and scratch arrays of the workers (wall)
    double jobs_seconds = 0;                ///< The parallel loop over the jobs (wall)
    double graph_seconds = 0;               ///< Unit propagation and weak reach (thread time)
    double filter_seconds = 0;              ///< Choosing the candidates, witness checks, storing solutions (thread time)
    double solver_seconds = 0;              ///< Backbone calls to the solver (thread time)
};

struct GraphBuildResult {
    ExitCode code = ExitCode::Success;
    std::string error;
    std::vector<std::string> warnings;
    std::vector<Link> requires_arcs;      ///< (v, i) as DIMACS variables, sorted
    std::vector<Link> excludes_edges;     ///< (v, i), v < i, sorted
    std::vector<Link> atleastone_edges;   ///< (v, i), v < i, sorted (--or-graph)
    std::vector<Link> or_implied_arcs;    ///< (i, v) implied under v = false, sorted (--or-graph)
    long long solver_calls = 0;
    long long solver_instances = 0;   ///< Solvers built by the workers: one per worker when they keep it between calls (R-OR-04)
    int threads_used = 0;
    MigStats mig;
};

/**
 * @brief Runs the main loop over the query set.
 * @param f     Formula (already transformed, if a merge was requested)
 * @param bb    Global backbone of f
 * @param query Variables to assume (each must have status Variable), any order
 * @param opts  Threads, detector, third graph and progress
 *
 * Threads: more than the cores is a warning and the cores are used (R-CLI-05). A thread that the system refuses
 * to start (a limit on processes, or no memory for it) is a warning too: the run goes on with the threads that
 * started, or in the calling thread, and gives the same files. Out of memory in a worker is exit code 2, as in
 * the calling thread.
 */
GraphBuildResult build_graphs(const DimacsFormula& f, const GlobalBackbone& bb,
                              const std::vector<int>& query, const GraphBuildOptions& opts);

/// Number of hardware threads (at least 1).
int hardware_threads();

} // namespace dimacs2graphs

#endif
