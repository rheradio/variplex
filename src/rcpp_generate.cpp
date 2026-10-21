// The R interface of the engine: `strong4vm generate`, as one function.
//
// vp_generate() (R/generate.R) turns its arguments into the command line of Strong4VM, so that the option table of
// the command line (s4/cli/Args.cc) checks them and fills the options of the API, exactly as the program does.

#include <Rcpp.h>

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <new>
#include <sstream>
#include <string>
#include <vector>

#include "vp_io.h"
#include "s4/cli/Args.hh"
#include "s4/api/include/strong4vm/Strong4VMAPI.hh"
#include "s4/dimacs2graphs/core/Pipeline.hh"
#include "s4/dimacs2graphs/core/Version.hh"

namespace {

Rcpp::List outcome(int code, const std::string& error, const std::vector<std::string>& warnings = {},
                   const std::string& help = "") {
    return Rcpp::List::create(Rcpp::Named("exit_code") = code, Rcpp::Named("error") = error,
                              Rcpp::Named("warnings") = Rcpp::wrap(warnings), Rcpp::Named("help") = help);
}

}  // namespace

// [[Rcpp::export(.vp_generate_cpp)]]
Rcpp::List vp_generate_cpp(std::vector<std::string> args, std::string command_line) {
    using dimacs2graphs::ExitCode;
    try {
        strong4vm::CliOptions cli;
        std::string error;
        if (!strong4vm::parse_generate_args(args, cli, error)) return outcome(static_cast<int>(ExitCode::Usage), error);
        if (cli.help) {
            std::ostringstream help;
            strong4vm::print_generate_help(help, "strong4vm");
            return outcome(0, "", {}, help.str());
        }
        if (cli.input.empty()) return outcome(static_cast<int>(ExitCode::Usage), "no input file given");

        std::string ext = std::filesystem::path(cli.input).extension().string();
        std::transform(ext.begin(), ext.end(), ext.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

        strong4vm::AnalysisOptions options;
        options.input_file = cli.input;
        options.input_type = ext == ".uvl" ? strong4vm::InputType::UVL : strong4vm::InputType::DIMACS;
        options.conversion_mode = cli.tseitin ? strong4vm::ConversionMode::TSEITIN : strong4vm::ConversionMode::STRAIGHTFORWARD;
        options.keep_dimacs = cli.keep_dimacs;
        options.filter = cli.gen.filter;
        options.output = cli.gen.output;
        options.run = cli.gen.run;
        options.command_line = command_line;

        strong4vm::Strong4VMAPI api;
        vp::start_capture();
        strong4vm::AnalysisReport r;
        try {
            r = api.analyze(options);
        } catch (...) {
            REprintf("%s", vp::stop_capture().c_str());
            throw;
        }
        // The warnings become R warnings: print only the rest of what the engine wrote to the error stream
        std::istringstream lines(vp::stop_capture());
        std::string line;
        while (std::getline(lines, line))
            if (line.rfind("Warning: ", 0) != 0) REprintf("%s\n", line.c_str());
        return outcome(r.exit_code, r.exit_code == 0 ? "" : r.error_message, r.warnings);
    } catch (const vp::exit_error& e) {
        return outcome(static_cast<int>(ExitCode::Solver), std::string("internal error: ") + e.what());
    } catch (const std::bad_alloc&) {
        return outcome(static_cast<int>(ExitCode::Input),
                       "not enough memory: the input, or the graphs it gives, are too large for this machine");
    } catch (const std::exception& e) {
        return outcome(static_cast<int>(ExitCode::Solver), std::string("internal error: ") + e.what());
    }
}

// [[Rcpp::export(.vp_engine_version)]]
std::string vp_engine_version() { return STRONG4VM_VERSION; }
