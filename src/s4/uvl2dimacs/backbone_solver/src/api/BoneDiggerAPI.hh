/**
 * @file BoneDiggerAPI.hh
 * @author BoneDigger Team
 * @brief Public C++ API for computing backbones of Boolean formulas
 *
 * This file provides the main API interface for the BoneDigger library,
 * which computes the backbone of Boolean formulas in CNF format.
 * The backbone is the set of literals that must have the same value
 * in all satisfying assignments.
 */

#ifndef BONEDIGGERAPI_HH
#define BONEDIGGERAPI_HH

#include <string>
#include <vector>

using std::string;
using std::vector;

/**
 * @defgroup API BoneDigger API
 * @brief Public API for programmatic backbone computation
 *
 * ## Overview
 *
 * The BoneDigger API provides a clean, high-level interface for computing backbones
 * of Boolean formulas programmatically. It uses the PIMPL (Pointer to Implementation)
 * pattern to hide internal details and provide a stable ABI.
 *
 * ## Quick Start
 *
 * @code
 * #include "BoneDiggerAPI.hh"
 * using namespace bonedigger;
 *
 * int main() {
 *     BoneDiggerAPI api;
 *
 *     // Load a DIMACS CNF file
 *     if (!api.read_dimacs("formula.cnf")) {
 *         return 1;
 *     }
 *
 *     // Create a detector ("rush"; the names "one", "simple" and "flatland" of 1.x are accepted too)
 *     if (!api.create_backbone_detector("rush")) {
 *         return 1;
 *     }
 *
 *     // Compute the backbone
 *     vector<int> backbone = api.compute_backbone();
 *
 *     // Display results
 *     api.print_backbone();
 *
 *     return 0;
 * }
 * @endcode
 *
 * ## Workflow
 *
 * The typical workflow is:
 * 1. **Create API instance**: `BoneDiggerAPI api;`
 * 2. **Read formula**: `api.read_dimacs("file.cnf")`
 * 3. **Create detector**: `api.create_backbone_detector("detector_type")`
 * 4. **Compute backbone**: `vector<int> backbone = api.compute_backbone()`
 * 5. **Query results**: Use `get_max_variable()`, `is_satisfiable()`, etc.
 *
 * ## Detector Types
 *
 * Strong4VM ships one detector of BoneDigger, RushAndPray, on one SAT engine, the patched Glucose 3.0, with
 * attention weight 1: the command line `bonedigger -r -a 1 -s 'glucose 3.0'`. create_backbone_detector() accepts
 * "rush" (also "rushandpray") and, for compatibility with 1.x, "one", "simple" and "flatland", which all compute
 * with RushAndPray (the backbone is unique, so the result is the same).
 *
 * The main loop of Strong4VM does not use a detector: compute_backbone_incremental() and
 * compute_backbone_incremental_literals() keep one Glucose 3.0 solver for all their calls and check the
 * candidates one by one, as the detector "one" of BoneDigger does.
 *
 * ## Building with the API
 *
 * To use the API in your project, compile and link with:
 *
 * @code{.sh}
 * Run `make` in src/ first: it builds sat_solvers/glucose_3_0/lib/libglucose_3_0.a and an object next to every
 * source (GlucoseBackend_3_0.cc needs its own flags, see the Makefile). Then:
 *
 * g++ -std=c++17 -O3 -I/path/to/src -I/path/to/src/sat_solvers/minisat_2_2_0 \
 *     your_program.cc \
 *     src/api/BoneDiggerAPI.o src/io/DIMACSReader.o \
 *     src/detectors/BackBone.o src/detectors/RushAndPray.o \
 *     src/data_structures/LiteralSet.o src/sat_interface/minisat_aux.o \
 *     src/sat_interface/SatSolver.o src/sat_interface/GlucoseBackend_3_0.o \
 *     -Lsrc/sat_solvers/glucose_3_0/lib -lglucose_3_0 -lz \
 *     -o your_program
 *
 * The MiniSat directory holds headers only: the interface of the detectors is written in MiniSat types.
 * @endcode
 *
 * ## Thread Safety
 *
 * The BoneDiggerAPI class is NOT thread-safe. Each thread should use its own
 * BoneDiggerAPI instance.
 *
 * ## Example Program
 *
 * See `src/api/api_example.cc` for a complete working example.
 */

namespace bonedigger {

/**
 * @class BoneDiggerAPI
 * @ingroup API
 * @brief Main API class for backbone computation using PIMPL pattern
 *
 * This class provides a high-level interface for computing backbones
 * of Boolean formulas. It uses the PIMPL (Pointer to Implementation)
 * pattern to hide implementation details and provide a stable ABI.
 *
 * Typical workflow:
 * 1. Create a BoneDiggerAPI instance
 * 2. Call read_dimacs() to load a CNF formula
 * 3. Call create_backbone_detector() to choose an algorithm
 * 4. Call compute_backbone() to get the result
 *
 * Example:
 * @code
 * BoneDiggerAPI api;
 * api.read_dimacs("formula.cnf");
 * api.create_backbone_detector("rush");
 * vector<int> backbone = api.compute_backbone();
 * @endcode
 */
class BoneDiggerAPI {
public:
    /**
     * @brief Construct a new BoneDiggerAPI object
     */
    BoneDiggerAPI();

    /**
     * @brief Destroy the BoneDiggerAPI object
     */
    ~BoneDiggerAPI();

    /**
     * @brief Read a DIMACS CNF file
     *
     * Parses a CNF formula from a file in DIMACS format.
     * The file must follow the standard DIMACS CNF specification.
     *
     * @param file_name Path to the DIMACS CNF file
     * @return true if file is valid and successfully read
     * @return false if file cannot be opened or has invalid format
     */
    bool read_dimacs(const string& file_name);

    /**
     * @brief Create a backbone detector for the last read DIMACS file
     *
     * Creates and initializes a backbone detection algorithm.
     * Must be called after read_dimacs().
     *
     * @param bb_detector "rush" or "rushandpray": RushAndPray. For compatibility with 1.x, "one", "simple"
     *                    and "flatland" are accepted and also use RushAndPray.
     * @return true if detector was successfully created
     * @return false if no DIMACS file has been read or bb_detector is invalid
     */
    bool create_backbone_detector(const string& bb_detector = "simple");

    /**
     * @brief Compute the backbone using the created detector
     *
     * Runs the backbone detection algorithm and returns the result.
     * Must be called after create_backbone_detector().
     *
     * @return vector<int> Vector of backbone literals:
     *                     - Positive values indicate variables that must be true
     *                     - Negative values indicate variables that must be false
     *                     - Empty vector if no file read, no detector created,
     *                       or formula is unsatisfiable
     */
    vector<int> compute_backbone();

    /**
     * @brief Get the maximum variable ID from the last read file
     *
     * @return int The highest variable number in the CNF formula
     */
    int get_max_variable() const;

    /**
     * @brief Check if the last read formula is satisfiable
     *
     * This can only be called after compute_backbone() has been executed.
     *
     * @return true if the formula has at least one satisfying assignment
     * @return false if the formula is unsatisfiable
     */
    bool is_satisfiable() const;

    /**
     * @brief Set the detector attention weight
     *
     * Controls how much influence the detector's activity bumping has
     * on variable ordering relative to the VSIDS activity.
     * Combined activity = vsids_activity + weight * detector_activity
     *
     * Must be called before compute_backbone().
     *
     * @param weight The attention weight (must be >= 0, default is 1.0)
     */
    void set_attention_weight(double weight);

    /**
     * @brief Compute the backbone under given assumptions
     *
     * Adds the assumptions as unit clauses to the formula and computes the backbone
     * of the resulting formula. A fresh detector instance is created for each call.
     * Must be called after read_dimacs() and create_backbone_detector().
     *
     * @param assumptions Literals to assume: positive int forces var=true,
     *                    negative int forces var=false (1-indexed DIMACS convention)
     * @return vector<int> Backbone literals under the assumptions, or empty if UNSAT
     */
    vector<int> compute_backbone_with_assumptions(const vector<int>& assumptions);

    /**
     * @brief Print the backbone to standard output
     *
     * Outputs the computed backbone in human-readable format.
     * Prints "UNSATISFIABLE" if formula is not satisfiable.
     * Otherwise prints backbone size and the list of backbone literals.
     */
    void print_backbone() const;

    /**
     * @brief Select the SAT engine by name
     *
     * Strong4VM vendors one engine, "glucose 3.0" (also "glucose-3.0", "glucose_3.0", "glucose3.0"), which
     * is the default. Must be called before compute_backbone().
     *
     * @return true if the name is known
     */
    bool set_solver(const string& solver);

    /**
     * @brief The engine names that set_solver() accepts, for messages
     */
    static string supported_solvers();

    /**
     * @brief Result of a backbone computation (see R-ERR-03 of Strong4VM 2.0).
     *
     * - Sat:   the formula (with the assumptions) is satisfiable; the backbone is valid
     * - Unsat: the formula (with the assumptions) is unsatisfiable; the backbone is empty
     * - Error: the computation failed (no file loaded, no detector, exception)
     */
    enum class SolveStatus { Sat, Unsat, Error };

    /**
     * @brief Loads a formula from memory instead of a file.
     *
     * @param max_var Number of variables (variables that appear in no clause are free)
     * @param clauses Clauses as DIMACS literals (non-zero integers)
     * @return true on success, false if a literal is 0 or exceeds max_var
     */
    bool load_formula(int max_var, const vector<vector<int>>& clauses);

    /**
     * @brief Computes the global backbone and reports whether the formula is satisfiable.
     * @param backbone Output: backbone literals (empty unless Sat)
     */
    SolveStatus compute_backbone(vector<int>& backbone);

    /**
     * @brief Computes the backbone under assumptions, distinguishing "unsatisfiable"
     * from "error" (the vector-returning overload returns an empty vector in both cases).
     * @param assumptions Literals assumed true
     * @param backbone    Output: backbone literals (empty unless Sat)
     */
    SolveStatus compute_backbone_with_assumptions(const vector<int>& assumptions, vector<int>& backbone);

    /**
     * @brief Computes the backbone under assumptions for some variables only.
     *
     * Only the literals of the variables v with wanted_variables[v] != 0 are candidates: the
     * other variables cost no solver call and are not reported. Used by Strong4VM to skip the
     * variables that are fixed in every configuration and those that are not options.
     *
     * @param assumptions      Literals assumed true
     * @param backbone         Output: backbone literals of the wanted variables (empty unless Sat)
     * @param wanted_variables Flags indexed by variable (index 0 unused); variables beyond its size are not wanted
     */
    SolveStatus compute_backbone_with_assumptions(const vector<int>& assumptions, vector<int>& backbone,
                                                  const vector<char>& wanted_variables);

    /**
     * @brief Builds the solver used by compute_backbone_incremental().
     *
     * The formula is loaded into a solver that is kept between calls. Calling this method is
     * optional (the first call to compute_backbone_incremental() does it), but it lets the caller
     * create every solver in one thread before the worker threads start.
     *
     * @return true on success, false if no formula is loaded
     */
    bool prepare_incremental();

    /**
     * @brief Computes the backbone under assumptions, for some variables, reusing one solver.
     *
     * Same result as compute_backbone_with_assumptions() with wanted variables, but the formula is
     * not copied and the solver is not rebuilt: the assumptions are given to a solver that is kept
     * between calls, together with everything it has learned. Meant for many calls on the same
     * formula with different assumptions, as in the main loop of Strong4VM, where the two calls for
     * a variable (v true, v false) and the calls for the following variables share the solver.
     * It uses the algorithm of the detector "one", whatever detector was created.
     *
     * A BoneDiggerAPI object must be used by one thread at a time.
     *
     * @param assumptions      Literals assumed true
     * @param backbone         Output: backbone literals of the wanted variables, by variable (empty unless Sat)
     * @param wanted_variables Flags indexed by variable (index 0 unused); variables beyond its size are not wanted
     */
    SolveStatus compute_backbone_incremental(const vector<int>& assumptions, vector<int>& backbone,
                                             const vector<char>& wanted_variables);

    /**
     * @brief Same as compute_backbone_incremental(), but the candidates are chosen per literal.
     *
     * literal_flags[v] says which literals of the variable v may be reported: bit 1 the positive literal v,
     * bit 2 the negative literal -v (3: both, as a wanted variable; 0: none). A literal that is not wanted
     * costs no solver call even if it belongs to the backbone, and is not reported. Used by the main loop of
     * Strong4VM with a modal implication graph, which knows beforehand which literals cannot be forced.
     *
     * @param assumptions   Literals assumed true
     * @param backbone      Output: the wanted backbone literals, by variable (empty unless Sat)
     * @param literal_flags Flags indexed by variable (index 0 unused); variables beyond its size are not wanted
     * @param models        If not null, every solution the solver found during the call is appended to it,
     *                      as a vector indexed by variable (1 = true, 0 = false; index 0 unused). Each one is a
     *                      solution of the formula with the assumptions.
     */
    SolveStatus compute_backbone_incremental_literals(const vector<int>& assumptions, vector<int>& backbone,
                                                      const vector<char>& literal_flags,
                                                      vector<vector<char>>* models = nullptr);
    /**
     * @brief Number of SAT solvers this object has built since it was created.
     *
     * compute_backbone() and compute_backbone_with_assumptions() build one solver per call;
     * compute_backbone_incremental() builds one for all its calls (one more after an error or a new
     * formula). Lets a caller verify that its calls share a solver (R-OR-04).
     */
    long solver_instances() const;

private:
    /**
     * @brief Forward declaration of implementation class
     */
    class Impl;

    /**
     * @brief Pointer to implementation (PIMPL pattern)
     */
    Impl* pimpl;
};

} // namespace bonedigger

#endif // BONEDIGGERAPI_HH
