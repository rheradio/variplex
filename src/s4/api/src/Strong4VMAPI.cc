/**
 * @file Strong4VMAPI.cc
 * @brief Implementation of Strong4VM unified API
 *
 * This file implements the Strong4VMAPI class: the whole pipeline of Strong4VM, from a UVL model or a DIMACS
 * formula to the graphs of strong dependencies and conflicts. The command `strong4vm generate` calls
 * Strong4VMAPI::analyze(const AnalysisOptions&), so the API and the command line run the same code.
 *
 * ## Pipeline
 *
 * 1. **Options and input**: the options are checked as the command line checks them
 *    (dimacs2graphs::validate_options()), then the input file and its type (by extension when the type is AUTO).
 * 2. **UVL to DIMACS** (UVL input only, component uvl2dimacs): STRAIGHTFORWARD or TSEITIN conversion; the
 *    skipped constraints and typed features are reported, and with `run.strict_uvl` a skipped constraint ends
 *    the analysis (exit code 6). The DIMACS file is removed at the end unless `keep_dimacs`.
 * 3. **DIMACS to graphs** (component dimacs2graphs, core/Pipeline.hh): classification of every variable,
 *    backbone, main loop, atomic sets, minimal form, kernel and consistency checks; the files are written.
 * 4. **Report**: the fields of 1.x and the products of 2.0 in memory.
 *
 * ## Errors
 *
 * No exception leaves the API: paths are examined without throwing, and analyze() runs the work through
 * dimacs2graphs::run_guarded(), which turns any exception that remains into an exit code (not enough memory: 2;
 * anything else: 4) and a message, as the command line does. Before the guard, analyze() only creates its report;
 * after it, it hands the report over with operations that cannot throw. The copy that get_last_report() returns is
 * made in the same way: if there is no memory for it, analyze() still returns its report, and get_last_report()
 * says that the copy could not be kept.
 *
 * ## PIMPL
 *
 * The class keeps its state in Strong4VMAPI::Impl, so the binary interface of the calls of 1.x stays the same
 * (R-API-04).
 */

#include "strong4vm/Strong4VMAPI.hh"
#include "../../uvl2dimacs/api/include/uvl2dimacs/UVL2Dimacs.hh"
#include "../../dimacs2graphs/api/Dimacs2GraphsAPI.hh"
#include "../../dimacs2graphs/api/RunResults.hh"
#include "../../dimacs2graphs/core/Pipeline.hh"
#include "../../dimacs2graphs/io/DimacsFormula.hh"

#include <filesystem>
#include <iostream>
#include <algorithm>
#include <cctype>
#include <system_error>

namespace fs = std::filesystem;

namespace strong4vm {

/**
 * @brief Internal implementation class (PIMPL idiom)
 *
 * This class encapsulates all implementation details of the Strong4VM API:
 * - **Configuration state**: Default settings for conversion mode, detector, threads, verbosity
 * - **Pipeline orchestration**: Coordinates uvl2dimacs and dimacs2graphs execution
 * - **File management**: Handles paths, extensions, temporary files
 * - **Validation logic**: Ensures configuration parameters are valid before execution
 * - **Result aggregation**: Combines statistics from both pipeline stages
 *
 * The PIMPL pattern ensures that changes to these internal details do not
 * affect the binary interface of the public Strong4VMAPI class.
 */
class Strong4VMAPI::Impl {
public:
    // Default settings
    bool verbose;
    ConversionMode default_conversion_mode;
    BackboneDetector default_detector;
    int default_num_threads;

    // Last result (the 1.x fields are its base part); false if there was no memory to keep a copy of it
    AnalysisReport last_report;
    bool last_report_kept = true;

    Impl()
        : verbose(false)
        , default_conversion_mode(ConversionMode::STRAIGHTFORWARD)
        , default_detector(BackboneDetector::ONE)
        , default_num_threads(1) {}

    /**
     * @brief Detect file type based on file extension
     *
     * Performs case-insensitive extension matching to determine input type:
     * - `.uvl` → InputType::UVL (feature model file)
     * - `.dimacs` or `.cnf` → InputType::DIMACS (CNF formula file)
     * - Other extensions → InputType::AUTO (unknown, requires manual specification)
     *
     * @param filename Path to the input file (can be relative or absolute)
     * @return Detected InputType enum value
     */
    InputType detect_file_type(const std::string& filename) const {
        fs::path path(filename);
        std::string ext = path.extension().string();

        // Convert to lowercase for case-insensitive comparison
        std::transform(ext.begin(), ext.end(), ext.begin(),
                      [](unsigned char c) { return std::tolower(c); });

        if (ext == ".uvl") {
            return InputType::UVL;
        } else if (ext == ".dimacs" || ext == ".cnf") {
            return InputType::DIMACS;
        }

        return InputType::AUTO;
    }

    /**
     * @brief Extract basename from file path without extension
     *
     * Uses filesystem::path::stem() to extract the filename without directory
     * components or file extension. Used for generating output filenames.
     *
     * Examples:
     * - "/path/to/model.uvl" → "model"
     * - "example.dimacs" → "example"
     * - "../test/file.cnf" → "file"
     *
     * @param filepath Full path to file
     * @return Basename without directory path or extension
     */
    std::string get_basename(const std::string& filepath) const {
        fs::path path(filepath);
        return path.stem().string();
    }

    /**
     * @brief Extract directory path from file path
     *
     * Returns the parent directory of the file. If the file path has no
     * directory component, returns "." (current directory).
     *
     * @param filepath Full path to file
     * @return Parent directory path, or "." if no parent
     */
    std::string get_directory(const std::string& filepath) const {
        fs::path path(filepath);
        if (path.has_parent_path()) {
            return path.parent_path().string();
        }
        return ".";
    }

    /**
     * @brief Validate analysis configuration before execution
     *
     * Performs comprehensive validation of configuration parameters:
     * - **Input file checks**: Exists, non-empty path
     * - **File type detection**: Can determine UVL or DIMACS if AUTO
     * - **Thread count validation**: At least 1 thread specified
     * - **Output directory**: Exists or can be created
     *
     * This validation happens before any pipeline execution to ensure
     * fast-fail behavior and clear error messages.
     *
     * @param config Configuration to validate
     * @return Empty string if valid, descriptive error message if invalid
     */
    std::string validate_configuration(const AnalysisConfig& config) const {
        // Check input file
        if (config.input_file.empty()) {
            return "Input file not specified";
        }

        std::string access;   // a path that cannot be examined (permissions, a name too long)
        if (!dimacs2graphs::path_exists(config.input_file, access)) {
            return access.empty() ? "Input file not found: " + config.input_file : access;
        }

        // Detect file type if AUTO
        InputType type = config.input_type;
        if (type == InputType::AUTO) {
            type = detect_file_type(config.input_file);
        }

        if (type == InputType::AUTO) {
            return "Cannot determine file type. Expected .uvl or .dimacs extension";
        }

        // Validate thread count
        if (config.num_threads < 1) {
            return "Thread count must be at least 1";
        }

        // Validate output directory if specified
        if (!config.output_dir.empty() && !dimacs2graphs::path_exists(config.output_dir, access)) {
            if (!access.empty()) return access;
            // Try to create it
            try {
                fs::create_directories(config.output_dir);
            } catch (const std::exception& e) {
                return "Cannot create output directory: " + std::string(e.what());
            }
        }

        return ""; // Valid
    }

    /**
     * @brief Convert detector enum to string identifier
     *
     * Translates BackboneDetector enum values to the names that dimacs2graphs::RunOptions::detector takes:
     * - BackboneDetector::ONE → "one" (the default: one reused Glucose 3.0 solver per thread, candidates checked
     *   one by one)
     * - BackboneDetector::FLATLAND → "flatland" (kept for 1.x; FastOnCliffsSlowOnPlains is no longer shipped, and
     *   the name now runs RushAndPray)
     * - BackboneDetector::RUSH → "rush" (RushAndPray)
     *
     * @param detector Detector enum value
     * @return String identifier for dimacs2graphs API
     */
    std::string detector_to_string(BackboneDetector detector) const {
        if (detector == BackboneDetector::FLATLAND) return "flatland";
        if (detector == BackboneDetector::RUSH) return "rush";
        return "one";  // ONE is the default
    }

    /// Makes `r` the report of an analysis that ends with an error. Cannot throw: it runs after the guard.
    static void mark_failed(AnalysisReport& r, const AnalysisOptions& o, dimacs2graphs::ExitCode code,
                            const std::string& msg) noexcept {
        try { r.input_file = o.input_file; } catch (...) {}   // without memory for it, the name stays empty
        r.success = false;
        r.exit_code = static_cast<int>(code);
        dimacs2graphs::copy_message(r.error_message, msg);
        r.graphs.success = false;
        r.graphs.exit_code = r.exit_code;
        dimacs2graphs::copy_message(r.graphs.error_message, msg);
    }

    /// Keeps a copy of the report for get_last_report(). Cannot throw: without memory for the copy, the getters
    /// say so instead.
    void keep(const AnalysisReport& r) noexcept {
        try {
            last_report = r;
            last_report_kept = true;
        } catch (...) {
            last_report_kept = false;
        }
    }

    /// What get_last_report() returns.
    AnalysisReport kept() const {
        if (last_report_kept) return last_report;
        AnalysisReport r;
        r.success = false;
        r.exit_code = static_cast<int>(dimacs2graphs::ExitCode::Input);
        r.error_message = "there was not enough memory to keep a copy of the report of the last analysis; use the report "
                          "that analyze() returned";
        r.graphs.success = false;
        r.graphs.exit_code = r.exit_code;
        r.graphs.error_message = r.error_message;
        return r;
    }

    /// Removes the DIMACS file converted from a UVL model when the analysis ends, however it ends.
    struct TemporaryFile {
        fs::path path;   ///< empty = nothing to remove; a path, so that the destructor allocates nothing
        TemporaryFile() = default;
        TemporaryFile(const TemporaryFile&) = delete;
        TemporaryFile& operator=(const TemporaryFile&) = delete;
        ~TemporaryFile() {   // cannot throw: an exception from a destructor would end the program
            std::error_code ec;
            if (!path.empty()) fs::remove(path, ec);
        }
    };

    /**
     * @brief Runs the complete Strong4VM 2.0 pipeline (it is what the command line runs)
     *
     * 1. Check the options as the command line does, then the input file and its type
     * 2. UVL input: convert to DIMACS (uvl2dimacs 2.0); report skipped constraints
     *    and typed features; with strict_uvl a skipped constraint is exit code 6
     * 3. Run the generate pipeline of dimacs2graphs (core/Pipeline.hh)
     * 4. Fill the report: the 1.x fields and the 2.0 in-memory products
     */
    AnalysisReport perform_analysis(const AnalysisOptions& o) {
        using namespace dimacs2graphs;
        AnalysisReport result;
        result.input_file = o.input_file;
        auto fail = [&](ExitCode code, const std::string& msg) {
            result.success = false;
            result.exit_code = static_cast<int>(code);
            result.error_message = msg;
            result.graphs.success = false;
            result.graphs.exit_code = result.exit_code;
            result.graphs.error_message = msg;
            return result;
        };

        if (o.input_file.empty())
            return fail(ExitCode::Usage, "no input file given. Set the input to a .uvl, .dimacs or .cnf file.");
        {
            // The values that the parser of the command line rejects (R-CLI-03), before any work
            GenerateOptions given;
            given.filter = o.filter;
            given.output = o.output;
            given.run = o.run;
            const std::string invalid = validate_options(given);
            if (!invalid.empty()) return fail(ExitCode::Usage, invalid);
        }
        std::string access;   // a path that cannot be examined (permissions, a name too long)
        if (!path_exists(o.input_file, access))
            return fail(ExitCode::Input, access.empty() ? "input file not found: '" + o.input_file + "'. Check the path." : access);
        InputType input_type = o.input_type == InputType::AUTO ? detect_file_type(o.input_file) : o.input_type;
        if (input_type == InputType::AUTO)
            return fail(ExitCode::Usage, "unknown input type for '" + o.input_file + "'. Expected a .uvl, .dimacs or .cnf file.");
        result.input_type = input_type;

        std::string output_dir = o.run.output_dir.empty() ? get_directory(o.input_file) : o.run.output_dir;
        if (output_dir.size() > 1 && (output_dir.back() == '/' || output_dir.back() == '\\')) output_dir.pop_back();
        try {
            if (!fs::exists(output_dir)) fs::create_directories(output_dir);
        } catch (const std::exception& e) {
            return fail(ExitCode::Input, "could not create output directory '" + output_dir + "': " + e.what() +
                        ". Choose a writable directory with the output option.");
        }
        const std::string basename = get_basename(o.input_file);

        GenerateRequest req;
        req.input_path = o.input_file;
        req.input_is_uvl = input_type == InputType::UVL;
        req.output_dir = output_dir;
        req.stem = basename;
        req.command_line = o.command_line.empty() ? "Strong4VMAPI::analyze(" + o.input_file + ")" : o.command_line;
        req.options.filter = o.filter;
        req.options.output = o.output;
        req.options.run = o.run;
        req.options.run.output_dir = output_dir;

        TemporaryFile temp_dimacs;
        if (req.input_is_uvl) {
            req.dimacs_path = output_dir + "/" + basename + ".dimacs";
            if (!o.keep_dimacs) temp_dimacs.path = req.dimacs_path;
            const bool tseitin = o.conversion_mode == ConversionMode::TSEITIN;
            uvl2dimacs::UVL2Dimacs converter;
            converter.set_verbose(!o.run.quiet);
            auto conv = converter.convert_report(o.input_file, req.dimacs_path,
                                                 tseitin ? uvl2dimacs::ConversionMode::TSEITIN
                                                         : uvl2dimacs::ConversionMode::STRAIGHTFORWARD);
            if (!conv.success) {
                return fail(ExitCode::Input, "UVL to DIMACS conversion of '" + o.input_file + "' failed: " + conv.error_message +
                            ". Check that the file is a valid UVL model of the Boolean language level.");
            }
            result.num_features = conv.num_features;
            result.num_relations = conv.num_relations;
            result.num_constraints = conv.num_constraints;
            result.num_skipped_constraints = conv.num_skipped_constraints;
            req.uvl.present = true;
            req.uvl.mode = tseitin ? "tseitin" : "straightforward";
            req.uvl.features = conv.num_features;
            req.uvl.skipped_constraints = conv.num_skipped_constraints;
            req.uvl.typed_features = conv.num_typed_features;
            req.uvl.abstract_features = conv.num_abstract_features;
            req.uvl.feature_cardinalities = static_cast<int>(conv.feature_cardinalities.size());
            // Printed by the converter; they also go to the summary (R-UVL-03, R-ERR-04)
            for (const auto& m : conv.skipped_constraints) req.uvl.warnings.push_back(o.input_file + ": " + m);
            for (const auto& m : conv.feature_cardinalities) req.uvl.warnings.push_back(o.input_file + ": " + m + ".");
            if (conv.num_typed_features > 0)
                req.uvl.warnings.push_back(o.input_file + ": " + std::to_string(conv.num_typed_features) +
                                           " feature(s) are declared Integer, String or Real; they are encoded only by "
                                           "their presence, their values are not represented (R-UVL-06).");
            if (conv.num_skipped_constraints > 0 && o.run.strict_uvl) {
                return fail(ExitCode::StrictUvl, std::to_string(conv.num_skipped_constraints) + " constraint(s) of '" +
                            o.input_file + "' were skipped and --strict-uvl is set. Remove --strict-uvl to accept a "
                            "weaker model, or rewrite the constraints in Boolean form.");
            }
            if (o.keep_dimacs) result.dimacs_file = req.dimacs_path;
        } else {
            req.dimacs_path = o.input_file;
        }

        GenerateResult g = run_generate(req);

        result.exit_code = static_cast<int>(g.code);
        result.warnings = g.warnings;
        // The products in memory, converted by the library as for Dimacs2GraphsAPI::generate (see RunResults.hh)
        result.graphs = to_graphs_result(g);
        const GraphsResult& gr = result.graphs;
        if (const Json* in = g.summary.find("input")) {
            if (const Json* v = in->find("variables")) result.num_variables = static_cast<int>(v->as_int());
            if (const Json* c = in->find("clauses")) result.num_clauses = static_cast<int>(c->as_int());
        }
        result.global_backbone = backbone_literals(g);
        for (const auto& v : gr.variables) {
            if (v.decision != "kept" || !v.dimacs_var) continue;
            if (v.status == "core") result.core_features.push_back(v.dimacs_var);
            else if (v.status == "dead") result.dead_features.push_back(v.dimacs_var);
        }
        const std::string base = output_dir + "/" + basename;
        result.requires_graph_file = base + "__requires.net";
        result.excludes_graph_file = base + "__excludes.net";
        result.core_features_file = base + "__core.txt";
        result.dead_features_file = base + "__dead.txt";
        result.success = g.code == ExitCode::Success;
        if (!result.success) result.error_message = g.error;
        return result;
    }
};

// ============================================================================
// Strong4VMAPI Public Interface Implementation
// ============================================================================

Strong4VMAPI::Strong4VMAPI()
    : pimpl_(new Impl()) {}

Strong4VMAPI::~Strong4VMAPI() = default;

AnalysisResult Strong4VMAPI::analyze(
    const std::string& input_file,
    const std::string& output_dir
) {
    AnalysisConfig config;
    config.input_file = input_file;
    config.output_dir = output_dir;
    config.input_type = InputType::AUTO;
    config.conversion_mode = pimpl_->default_conversion_mode;
    config.keep_dimacs = false;
    config.detector = pimpl_->default_detector;
    config.num_threads = pimpl_->default_num_threads;
    config.verbose = pimpl_->verbose;

    return analyze(config);
}

AnalysisResult Strong4VMAPI::analyze(const AnalysisConfig& config) {
    // 1.x call: the same pipeline with the default options of 2.0 (R-API-04)
    AnalysisOptions options;
    options.input_file = config.input_file;
    options.input_type = config.input_type;
    options.conversion_mode = config.conversion_mode;
    options.keep_dimacs = config.keep_dimacs;
    options.run.output_dir = config.output_dir;
    options.run.detector = pimpl_->detector_to_string(config.detector);
    options.run.threads = config.num_threads;
    options.run.quiet = !config.verbose;
    return analyze(options);  // the 1.x result is the base part of the report
}

AnalysisReport Strong4VMAPI::analyze(const AnalysisOptions& options) {
    // Last line of defence, as in the command line: no exception leaves the library. Creating the report is the
    // one allocation outside it; what follows the guard cannot throw.
    AnalysisReport report;
    dimacs2graphs::ExitCode code = dimacs2graphs::ExitCode::Success;
    std::string error;
    if (!dimacs2graphs::run_guarded([&] { return "analyse '" + options.input_file + "'"; }, code, error,
                                    [&] { report = pimpl_->perform_analysis(options); }))
        Impl::mark_failed(report, options, code, error);
    pimpl_->keep(report);
    return report;
}

AnalysisReport Strong4VMAPI::get_last_report() const {
    return pimpl_->kept();
}

void Strong4VMAPI::set_verbose(bool verbose) {
    pimpl_->verbose = verbose;
}

bool Strong4VMAPI::get_verbose() const {
    return pimpl_->verbose;
}

void Strong4VMAPI::set_default_conversion_mode(ConversionMode mode) {
    pimpl_->default_conversion_mode = mode;
}

ConversionMode Strong4VMAPI::get_default_conversion_mode() const {
    return pimpl_->default_conversion_mode;
}

void Strong4VMAPI::set_default_detector(BackboneDetector detector) {
    pimpl_->default_detector = detector;
}

BackboneDetector Strong4VMAPI::get_default_detector() const {
    return pimpl_->default_detector;
}

void Strong4VMAPI::set_default_threads(int num_threads) {
    pimpl_->default_num_threads = num_threads;
}

int Strong4VMAPI::get_default_threads() const {
    return pimpl_->default_num_threads;
}

std::string Strong4VMAPI::validate_config(const AnalysisConfig& config) const {
    return pimpl_->validate_configuration(config);
}

AnalysisResult Strong4VMAPI::get_last_result() const {
    return pimpl_->kept();
}

} // namespace strong4vm
