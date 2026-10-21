/**
 * @file Args.hh
 * @brief Table-driven parser of the options of `strong4vm generate` (Section 10)
 *
 * Every option is described once (name, alias, accepted values, default,
 * group, help text, setter, field of the API); the same table produces --help
 * (R-CLI-04), the error messages for unknown options and invalid values
 * (R-CLI-03), the option reference of README.md and the table that gives the
 * field of the API for each option (R-API-01).
 */

#ifndef STRONG4VM_CLI_ARGS_HH
#define STRONG4VM_CLI_ARGS_HH

#include "../dimacs2graphs/filter/Options.hh"

#include <functional>
#include <ostream>
#include <string>
#include <vector>

namespace strong4vm {

/// Options of `generate` that are not part of dimacs2graphs::GenerateOptions.
struct CliOptions {
    dimacs2graphs::GenerateOptions gen;
    std::string input;
    bool keep_dimacs = false;
    bool tseitin = false;
    bool help = false;
    bool version = false;
    bool print_rules_md = false;   ///< hidden: writes docs/filters.md to stdout
    bool print_options_md = false; ///< hidden: writes the option reference of README.md to stdout
    bool print_api_md = false;     ///< hidden: writes the table "command line → API" of README.md to stdout
};

struct OptionSpec {
    std::string name;                     ///< "--tristate"
    std::string alias;                    ///< "-t" or ""
    std::string arg;                      ///< "" for flags, "M", "N", "FILE", "RE", …
    std::vector<std::string> values;      ///< Accepted values (empty: free text)
    std::string default_text;             ///< Default, as shown by --help
    std::string group;                    ///< Group in --help
    std::string help;                     ///< Description
    std::function<bool(CliOptions&, const std::string&)> set;  ///< Returns false on invalid value
    bool hidden = false;
    /// What the option is in the API (Markdown): the field of strong4vm::AnalysisOptions that it sets, whose
    /// `filter`, `output` and `run` are those of dimacs2graphs::GenerateOptions. The field comes first, in
    /// backquotes; the unit tests check that the option sets that field and no other.
    std::string api;
};

/// The option table of `generate`.
const std::vector<OptionSpec>& generate_options();

/**
 * @brief Parses the arguments of `generate` (argv without program name and sub-command).
 * @return true on success; on failure `error` names the option and the accepted values.
 */
bool parse_generate_args(const std::vector<std::string>& args, CliOptions& out, std::string& error);

/// Writes the help text of `generate`, grouped, with defaults (R-CLI-04).
void print_generate_help(std::ostream& out, const std::string& program);

/// Writes the option reference of README.md (Markdown tables, one per group), from the same table (R-IMP-05).
void print_options_markdown(std::ostream& out);

/// Writes the table "command line → API" of README.md and api/docs/api_overview.md, from the same table (R-API-01).
void print_api_markdown(std::ostream& out);

} // namespace strong4vm

#endif
