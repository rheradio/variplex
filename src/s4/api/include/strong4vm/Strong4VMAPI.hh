#include "vp_io.h"  // added by variplex (tools/sync_cpp.R)
/**
 * @file Strong4VMAPI.hh
 * @brief High-level C++ API for Strong4VM - Feature Model to Strong Transitive Graphs
 *
 * This header provides a simple interface for the complete Strong4VM pipeline:
 * 1. Convert UVL feature models to DIMACS CNF (or accept existing DIMACS)
 * 2. Generate strong transitive dependency and conflict graphs
 * 3. Extract core and dead features
 */

/**
 * @defgroup Strong4VMAPI Strong4VM API
 * @brief The whole pipeline from a program: from a UVL model or a DIMACS formula to the graphs
 *
 * strong4vm::Strong4VMAPI converts a UVL model to a formula when the input is one (component
 * uvl2dimacs) and generates the graphs (component dimacs2graphs). It has the calls of two
 * versions:
 * - **Version 2.0**: strong4vm::Strong4VMAPI::analyze(const AnalysisOptions&) takes every option of
 *   the command line (strong4vm::AnalysisOptions) and returns a strong4vm::AnalysisReport with
 *   the exit code, the warnings, the graphs and the classification of every variable in memory.
 *   The command `strong4vm generate` is a call of this function.
 * - **Version 1.x**: the calls with strong4vm::AnalysisConfig and strong4vm::AnalysisResult are
 *   unchanged; they run the pipeline of 2.0 with its default options.
 *
 * The other sub-commands of the command line (`check`, `expand`, `explain`, `diff`), the
 * classification without solving and `--version` are the free functions dimacs2graphs::check(),
 * dimacs2graphs::expand(), dimacs2graphs::explain(), dimacs2graphs::read_renames() with
 * dimacs2graphs::diff(), dimacs2graphs::classify() and dimacs2graphs::version(), declared in
 * Dimacs2GraphsAPI.hh, which this header includes. The command line calls them too.
 *
 * No exception leaves the library: a call that fails returns `success == false` (or an exit
 * code other than 0) with a message that says what to do and, in the calls of 2.0, the exit
 * code that the command line would return; also when a path cannot be examined, a file cannot
 * be read to its end, the system refuses a thread or the machine runs out of memory. Two limits
 * remain, both when the memory runs out: a call that cannot even create its result object (its
 * JSON value allocates when it is created) lets std::bad_alloc out, and the parser of UVL (the
 * ANTLR runtime, third-party) can end the program while it reads a model, because it cleans up
 * in a destructor that allocates. get_last_report() returns a copy of the last report; if there
 * was no memory to keep that copy, it returns a report with exit code 2 that says so.
 *
 * The programs of `api/examples` show both versions in use.
 */

#ifndef STRONG4VM_API_HH
#define STRONG4VM_API_HH

#include <string>
#include <vector>
#include <memory>

// Options of Section 8 (FilterOptions, OutputOptions, RunOptions) and in-memory results (GraphsResult)
#include "../../../dimacs2graphs/api/Dimacs2GraphsAPI.hh"

namespace strong4vm {

/// @addtogroup Strong4VMAPI
/// @{

/**
 * @brief Input file type for Strong4VM
 */
enum class InputType {
    UVL,        ///< Universal Variability Language feature model
    DIMACS,     ///< DIMACS CNF formula
    AUTO        ///< Automatically detect based on file extension (default)
};

/**
 * @brief CNF conversion mode (for UVL input)
 */
enum class ConversionMode {
    STRAIGHTFORWARD,  ///< Direct conversion without auxiliary variables (default)
    TSEITIN           ///< Tseitin transformation with auxiliary variables
};

/**
 * @brief Backbone detector algorithm
 */
enum class BackboneDetector {
    ONE,        ///< One reused Glucose 3.0 solver per thread, candidates checked one by one (default, recommended)
    FLATLAND,   ///< Kept for 1.x: FastOnCliffsSlowOnPlains is no longer shipped, and this value runs RushAndPray
    RUSH        ///< BoneDigger's RushAndPray detector (a new solver per call)
};

/**
 * @brief Configuration options for Strong4VM analysis
 */
struct AnalysisConfig {
    // Input/Output settings
    std::string input_file;           ///< Path to input file (.uvl or .dimacs)
    std::string output_dir;           ///< Output directory (default: same as input file)
    InputType input_type;             ///< Input file type (default: AUTO)

    // UVL conversion settings (only used for UVL input)
    ConversionMode conversion_mode;   ///< CNF conversion mode (default: STRAIGHTFORWARD)
    bool keep_dimacs;                 ///< Keep intermediate DIMACS file (default: false)

    // Graph generation settings
    BackboneDetector detector;        ///< Backbone detector algorithm (default: ONE)
    int num_threads;                  ///< Number of threads for parallel processing (default: 1)

    // Verbosity
    bool verbose;                     ///< Print progress messages (default: false)

    /**
     * @brief Default constructor with sensible defaults
     */
    AnalysisConfig()
        : input_file("")
        , output_dir("")
        , input_type(InputType::AUTO)
        , conversion_mode(ConversionMode::STRAIGHTFORWARD)
        , keep_dimacs(false)
        , detector(BackboneDetector::ONE)
        , num_threads(1)
        , verbose(false) {}
};

/**
 * @brief Result of a Strong4VM analysis
 */
struct AnalysisResult {
    bool success;                     ///< Whether the analysis was successful
    std::string error_message;        ///< Error message if analysis failed

    // Input file information
    InputType input_type;             ///< Type of input file processed
    std::string input_file;           ///< Path to input file

    // Feature model statistics (only for UVL input)
    int num_features;                 ///< Number of features in the model
    int num_relations;                ///< Number of parent-child relations
    int num_constraints;              ///< Number of cross-tree constraints

    // CNF formula statistics
    int num_variables;                ///< Number of variables in the CNF
    int num_clauses;                  ///< Number of clauses in the CNF
    int num_skipped_constraints;      ///< UVL constraints skipped (not Boolean, or naming an undeclared feature)

    // Graph analysis results
    std::vector<int> global_backbone; ///< Global backbone literals
    std::vector<int> core_features;   ///< Core features (always selected)
    std::vector<int> dead_features;   ///< Dead features (never selected)

    // Output files
    std::string requires_graph_file;  ///< Path to requires graph (.net)
    std::string excludes_graph_file;  ///< Path to excludes graph (.net)
    std::string core_features_file;   ///< Path to core features (.txt)
    std::string dead_features_file;   ///< Path to dead features (.txt)
    std::string dimacs_file;          ///< Path to DIMACS file (if kept)

    /**
     * @brief Default constructor for failed analysis
     */
    AnalysisResult()
        : success(false)
        , error_message("")
        , input_type(InputType::AUTO)
        , input_file("")
        , num_features(0)
        , num_relations(0)
        , num_constraints(0)
        , num_variables(0)
        , num_clauses(0)
        , num_skipped_constraints(0)
        , requires_graph_file("")
        , excludes_graph_file("")
        , core_features_file("")
        , dead_features_file("")
        , dimacs_file("") {}
};

/**
 * @brief Configuration of an analysis with every option of Strong4VM 2.0 (R-API-01)
 *
 * Mirrors the command line of `strong4vm generate`, one field per option:
 * - `input_file`, `input_type`, `conversion_mode` (`-e`) and `keep_dimacs` (`-k`);
 * - `filter`: classification and filtering (Sections 5–7; `--translator`,
 *   `--tristate`, `--nonbool`, `--decls`, the patterns, …);
 * - `output`: products (`--or-graph`, `--atomic`, `--minimal`, `--kernel`,
 *   `--check`, `--no-fail-on-check`);
 * - `run`: execution (`--threads`, `--output`, `--progress`, `--quiet`,
 *   `--verbose`, `--max-matrix-memory`, `--strict-uvl`, `--classify-only`),
 *   and the backbone detector, which only the API sets;
 * - set_legacy() for `--legacy`. Call it first: it sets every option, and the
 *   fields set afterwards override it, as the options written after `--legacy`.
 *
 * The README has the field of every option (section "C++ API"). The values
 * that the command line rejects are rejected by analyze() with exit code 1
 * (dimacs2graphs::validate_options()).
 *
 * AnalysisConfig, the configuration of 1.x, keeps its layout and its calls,
 * so programs written for 1.x keep working (R-API-04).
 */
struct AnalysisOptions {
    std::string input_file;                                            ///< Path to a .uvl, .dimacs or .cnf file
    InputType input_type = InputType::AUTO;                            ///< AUTO: by extension
    ConversionMode conversion_mode = ConversionMode::STRAIGHTFORWARD;  ///< UVL input (`-e` selects TSEITIN)
    bool keep_dimacs = false;                                          ///< UVL input: keep the DIMACS file (`-k`)
    dimacs2graphs::FilterOptions filter;                               ///< Options of Sections 5–7
    dimacs2graphs::OutputOptions output;                               ///< Products besides the two graphs
    dimacs2graphs::RunOptions run;                                     ///< Threads, output directory, verbosity, …
    std::string command_line;                                          ///< Recorded in __summary.json

    /// The API is silent by default, as in 1.x (`run.quiet = false` prints the progress messages).
    AnalysisOptions() { run.quiet = true; }

    /// Sets every option to its 1.x behaviour (`--legacy`, R-PRI-06).
    void set_legacy() { dimacs2graphs::apply_legacy(filter, output, run); }
};

/**
 * @brief Result of an analysis with the products of Strong4VM 2.0 (R-API-02)
 *
 * The inherited fields are those of 1.x. `graphs` holds everything written to
 * `__summary.json`, the graphs in compressed sparse row form and the
 * classification of every variable, so callers need not parse files.
 */
struct AnalysisReport : AnalysisResult {
    int exit_code = 0;                    ///< Exit code of Section 13 (0 = success)
    std::vector<std::string> warnings;    ///< Warnings of R-ERR-04
    dimacs2graphs::GraphsResult graphs;   ///< Summary, graphs (CSR) and classification
};

/**
 * @brief Main API class for Strong4VM analysis
 *
 * This class provides a high-level interface for analyzing feature models
 * and generating strong transitive dependency and conflict graphs.
 *
 * Example usage:
 * @code
 * strong4vm::Strong4VMAPI api;
 *
 * // Simple analysis with defaults
 * auto result = api.analyze("model.uvl");
 * if (result.success) {
 *     vp::out() << "Analysis successful!\n";
 *     vp::out() << "Core features: " << result.core_features.size() << "\n";
 *     vp::out() << "Dead features: " << result.dead_features.size() << "\n";
 * }
 *
 * // Advanced analysis with custom configuration
 * strong4vm::AnalysisConfig config;
 * config.input_file = "model.uvl";
 * config.output_dir = "./output";
 * config.conversion_mode = strong4vm::ConversionMode::TSEITIN;
 * config.num_threads = 4;
 * config.keep_dimacs = true;
 * config.verbose = true;
 *
 * auto result2 = api.analyze(config);
 *
 * // Version 2.0: every option of the command line, the results in memory
 * strong4vm::AnalysisOptions options;
 * options.input_file = "model.uvl";              // strong4vm model.uvl -o out -t 4 --or-graph
 * options.run.output_dir = "out";
 * options.run.threads = 4;
 * options.output.or_graph = true;
 * strong4vm::AnalysisReport report = api.analyze(options);
 * if (!report.success)
 *     vp::err() << "exit code " << report.exit_code << ": " << report.error_message << "\n";
 * @endcode
 */
class Strong4VMAPI {
public:
    /**
     * @brief Constructor
     */
    Strong4VMAPI();

    /**
     * @brief Destructor
     */
    ~Strong4VMAPI();

    /**
     * @brief Analyze a feature model or CNF formula (simple interface)
     *
     * Uses default configuration with auto-detection of file type.
     *
     * @param input_file Path to input file (.uvl or .dimacs)
     * @param output_dir Optional output directory (default: same as input file)
     * @return AnalysisResult with success status, statistics, and output file paths
     */
    AnalysisResult analyze(
        const std::string& input_file,
        const std::string& output_dir = ""
    );

    /**
     * @brief Analyze a feature model or CNF formula (full configuration)
     *
     * Provides complete control over all analysis parameters.
     *
     * @param config Analysis configuration with all options
     * @return AnalysisResult with success status, statistics, and output file paths
     */
    AnalysisResult analyze(const AnalysisConfig& config);

    /**
     * @brief Analyze with every option of Strong4VM 2.0 (R-API-01)
     *
     * Runs the pipeline of `strong4vm generate` (it is the function the command
     * line calls) and returns its products in memory (R-API-02).
     *
     * The options are checked first as the command line checks them: an invalid
     * value (`run.threads` below 1, a memory limit that is not positive, an
     * unknown detector, an empty file name) ends the call with exit code 1.
     *
     * @param options Input, conversion, filtering, output and execution options
     * @return AnalysisReport: the 1.x fields, the exit code, the warnings and the graphs.
     *         The exit code is the one the command line would return: 0 success,
     *         1 invalid option or input type, 2 input error (also a path that cannot be
     *         read, and not enough memory), 3 void model, 4 internal error, 5 unknown
     *         name, 6 skipped UVL constraint with `run.strict_uvl`, 7 failed check
     */
    AnalysisReport analyze(const AnalysisOptions& options);

    /**
     * @brief Get the last analysis result with the 2.0 products
     * @return A copy of the report that the last call of analyze() returned. If there was not enough memory to keep
     *         that copy, a report with `success == false`, exit code 2 and a message that says so (the report that
     *         analyze() returned is complete).
     */
    AnalysisReport get_last_report() const;

    /**
     * @brief Set verbose output mode
     * @param verbose If true, print progress messages during analysis
     */
    void set_verbose(bool verbose);

    /**
     * @brief Get verbose output mode
     * @return Current verbose setting
     */
    bool get_verbose() const;

    /**
     * @brief Set default conversion mode for UVL input
     * @param mode Default CNF conversion mode
     */
    void set_default_conversion_mode(ConversionMode mode);

    /**
     * @brief Get default conversion mode
     * @return Current default conversion mode
     */
    ConversionMode get_default_conversion_mode() const;

    /**
     * @brief Set default backbone detector
     * @param detector Default backbone detector algorithm
     */
    void set_default_detector(BackboneDetector detector);

    /**
     * @brief Get default backbone detector
     * @return Current default detector
     */
    BackboneDetector get_default_detector() const;

    /**
     * @brief Set default number of threads
     * @param num_threads Default thread count for parallel processing
     */
    void set_default_threads(int num_threads);

    /**
     * @brief Get default number of threads
     * @return Current default thread count
     */
    int get_default_threads() const;

    /**
     * @brief Validate configuration before analysis
     * @param config Configuration to validate
     * @return Error message if invalid, empty string if valid
     */
    std::string validate_config(const AnalysisConfig& config) const;

    /**
     * @brief Get the last analysis result
     * @return Last AnalysisResult (useful for debugging)
     */
    AnalysisResult get_last_result() const;

private:
    class Impl;
    std::unique_ptr<Impl> pimpl_;  ///< Pointer to implementation (PIMPL idiom)
};

/// @}

} // namespace strong4vm

#endif // STRONG4VM_API_HH
