/**
 * @file Args.cc
 * @brief Option table and parser of `strong4vm generate` (see Args.hh)
 */

#include "Args.hh"

#include <cstdlib>
#include <map>
#include <sstream>

using namespace dimacs2graphs;

namespace strong4vm {

namespace {

// Groups of --help, as in the table of Section 10 (R-CLI-04)
const char* G_RUN = "Input, output and threads";
const char* G_TRANSLATOR = "Translator profile (Section 6.0)";
const char* G_FILTER = "Filtering decisions (Section 8)";
const char* G_DECLS = "Declared names (Section 6.8)";
const char* G_NAMES = "Names (Section 6.9)";
const char* G_PATTERNS = "Escape hatches (Section 6.1)";
const char* G_PIPE = "Pipeline (Section 7)";
const char* G_OR = "Third graph (F2)";
const char* G_PRODUCTS = "Atomic sets, minimal form, kernel and checks (F5-F8)";
const char* G_COUNT = "What the graphs leave out (GANAK)";
const char* G_UVL = "UVL input (R-UVL-03)";
const char* G_COMPAT = "Compatibility (R-PRI-06)";
const char* G_TERM = "Output on the terminal";
const char* G_INFO = "Information";

bool on_off(const std::string& v, bool& out) {
    if (v == "on") { out = true; return true; }
    if (v == "off") { out = false; return true; }
    return false;
}

template <class E>
bool pick(const std::string& v, const std::vector<std::pair<const char*, E>>& table, E& out) {
    for (const auto& p : table)
        if (v == p.first) { out = p.second; return true; }
    return false;
}

std::vector<OptionSpec> build_table() {
    std::vector<OptionSpec> t;
    auto flag = [&](const char* name, const char* alias, const char* group, const char* help, const char* api,
                    std::function<void(CliOptions&)> set, bool hidden = false) {
        OptionSpec s;
        s.name = name; s.alias = alias; s.group = group; s.help = help; s.default_text = "off"; s.hidden = hidden;
        s.api = api;
        s.set = [set](CliOptions& o, const std::string&) { set(o); return true; };
        t.push_back(s);
    };
    auto value = [&](const char* name, const char* alias, const char* arg, std::vector<std::string> values,
                     const char* def, const char* group, const char* help, const char* api,
                     std::function<bool(CliOptions&, const std::string&)> set) {
        OptionSpec s;
        s.name = name; s.alias = alias; s.arg = arg; s.values = std::move(values); s.default_text = def;
        s.group = group; s.help = help; s.api = api; s.set = std::move(set);
        t.push_back(s);
    };

    // Execution
    value("--threads", "-t", "N", {}, "1", G_RUN, "Number of worker threads (more than the cores: warning, uses the cores)",
          "`run.threads`",
          [](CliOptions& o, const std::string& v) {
              char* end; long n = std::strtol(v.c_str(), &end, 10);
              if (*end || n < 1) return false;
              o.gen.run.threads = static_cast<int>(n > 1000000 ? 1000000 : n);
              return true;
          });
    value("--output", "-o", "DIR", {}, "next to the input", G_RUN, "Output directory",
          "`run.output_dir` (\"\" = next to the input)",
          [](CliOptions& o, const std::string& v) { o.gen.run.output_dir = v; return !v.empty(); });
    value("--mig", "", "M", {"on", "off"}, "on", G_RUN,
          "Use a modal implication graph to skip solver calls in the main loop; same graphs, usually faster",
          "`run.mig`",
          [](CliOptions& o, const std::string& v) { return on_off(v, o.gen.run.mig); });
    flag("--keep-dimacs", "-k", G_RUN, "Keep the DIMACS file produced from UVL",
         "`keep_dimacs = true` (`AnalysisOptions` only: UVL input)",
         [](CliOptions& o) { o.keep_dimacs = true; });
    flag("--enable-tseitin", "-e", G_RUN, "Tseitin mode for UVL conversion",
         "`conversion_mode = ConversionMode::TSEITIN` (`AnalysisOptions` only: UVL input)",
         [](CliOptions& o) { o.tseitin = true; });

    // Filtering
    value("--translator", "", "P", {"auto", "kmax", "kconfigreader", "kconfigsampler", "travart", "uvl", "generic"}, "auto",
          G_TRANSLATOR, "Translator profile; auto detects it (R-FLT-02)",
          "`filter.translator`: `Translator::Auto`, `KMax`, `KConfigReader`, `KconfigSampler`, `TraVarT`, `Uvl`, `Generic`",
          [](CliOptions& o, const std::string& v) { return parse_translator(v, o.gen.filter.translator); });
    value("--tristate", "", "M", {"merge", "builtin", "both"}, "merge", G_FILTER,
          "Tristate X / X_MODULE: one node 'X built in or module', X only, or both",
          "`filter.tristate`: `TristateMode::Merge`, `Builtin`, `Both`",
          [](CliOptions& o, const std::string& v) {
              return pick<TristateMode>(v, {{"merge", TristateMode::Merge}, {"builtin", TristateMode::Builtin}, {"both", TristateMode::Both}}, o.gen.filter.tristate);
          });
    value("--nonbool", "", "M", {"merge", "drop", "keep"}, "merge", G_FILTER,
          "Value variables of non-Boolean options: one node 'P is set', none, or every value",
          "`filter.nonbool`: `NonBoolMode::Merge`, `Drop`, `Keep`",
          [](CliOptions& o, const std::string& v) {
              return pick<NonBoolMode>(v, {{"merge", NonBoolMode::Merge}, {"drop", NonBoolMode::Drop}, {"keep", NonBoolMode::Keep}}, o.gen.filter.nonbool);
          });
    value("--visibility", "", "M", {"drop", "keep"}, "drop", G_FILTER, "KMax visibility variables",
          "`filter.drop_visibility`: `true` for drop",
          [](CliOptions& o, const std::string& v) { if (v != "drop" && v != "keep") return false; o.gen.filter.drop_visibility = v == "drop"; return true; });
    value("--abstract-groups", "", "M", {"merge", "keep"}, "merge", G_FILTER,
          "TraVarT abstract group features (_xor, _or, _alt) equivalent to their parent",
          "`filter.abstract_groups`: `AbstractGroupMode::Merge`, `Keep`",
          [](CliOptions& o, const std::string& v) {
              return pick<AbstractGroupMode>(v, {{"merge", AbstractGroupMode::Merge}, {"keep", AbstractGroupMode::Keep}}, o.gen.filter.abstract_groups);
          });
    value("--synthetic-root", "", "M", {"drop", "keep"}, "drop", G_FILTER, "Synthetic root __Root__ added by the transformation",
          "`filter.drop_synthetic_root`: `true` for drop",
          [](CliOptions& o, const std::string& v) { if (v != "drop" && v != "keep") return false; o.gen.filter.drop_synthetic_root = v == "drop"; return true; });
    value("--abstract", "", "M", {"keep", "drop", "merge"}, "drop", G_FILTER,
          "UVL features marked {abstract}, the root included; merge: into an equivalent feature that is not abstract, if there is one",
          "`filter.abstract_features`: `AbstractMode::Keep`, `Drop`, `Merge`",
          [](CliOptions& o, const std::string& v) {
              return pick<AbstractMode>(v, {{"keep", AbstractMode::Keep}, {"drop", AbstractMode::Drop}, {"merge", AbstractMode::Merge}},
                                        o.gen.filter.abstract_features);
          });
    value("--fixed-nodes", "", "M", {"drop", "keep"}, "drop", G_FILTER,
          "Core and dead options as graph vertices (they are always in __core.txt/__dead.txt)",
          "`filter.drop_fixed_nodes`: `true` for drop",
          [](CliOptions& o, const std::string& v) { if (v != "drop" && v != "keep") return false; o.gen.filter.drop_fixed_nodes = v == "drop"; return true; });
    value("--unnamed", "", "M", {"drop", "keep"}, "drop", G_FILTER, "Variables without a name comment (keep: named v<n>)",
          "`filter.drop_unnamed`: `true` for drop",
          [](CliOptions& o, const std::string& v) { if (v != "drop" && v != "keep") return false; o.gen.filter.drop_unnamed = v == "drop"; return true; });
    value("--unknown-names", "", "M", {"keep", "drop", "error"},
          "drop for kmax, kconfigreader, kconfigsampler; keep otherwise", G_FILTER, "Names that match no rule of the profile",
          "`filter.unknown_names`: `UnknownNames::Keep`, `Drop`, `Error`; the default is `ProfileDefault`",
          [](CliOptions& o, const std::string& v) {
              return pick<UnknownNames>(v, {{"keep", UnknownNames::Keep}, {"drop", UnknownNames::Drop}, {"error", UnknownNames::Error}}, o.gen.filter.unknown_names);
          });

    // Declarations
    value("--decls", "", "FILE", {}, "none", G_DECLS, "Declared option names, one per line: other variables are dropped (C6)",
          "`filter.decls_file`",
          [](CliOptions& o, const std::string& v) { o.gen.filter.decls_file = v; return !v.empty(); });
    value("--decls-unconstrained", "", "M", {"ignore", "add"}, "ignore", G_DECLS,
          "Declared names absent from the formula: ignore, or add as isolated nodes",
          "`filter.add_unconstrained`: `true` for add",
          [](CliOptions& o, const std::string& v) { if (v != "ignore" && v != "add") return false; o.gen.filter.add_unconstrained = v == "add"; return true; });

    // Names
    flag("--keep-type-prefix", "", G_NAMES, "Keep the prefixes boolean_ and tristate_ (KconfigSampler)",
         "`filter.keep_type_prefix = true`",
         [](CliOptions& o) { o.gen.filter.keep_type_prefix = true; });
    flag("--strip-config-prefix", "", G_NAMES, "Strip the prefix CONFIG_",
         "`filter.strip_config_prefix = true`",
         [](CliOptions& o) { o.gen.filter.strip_config_prefix = true; });

    // Patterns
    value("--keep-pattern", "", "RE", {}, "none", G_PATTERNS, "Keep names matching RE (repeatable; overrides every other rule)",
          "`filter.keep_patterns`: one element per pattern",
          [](CliOptions& o, const std::string& v) { o.gen.filter.keep_patterns.push_back(v); return true; });
    value("--drop-pattern", "", "RE", {}, "none", G_PATTERNS, "Drop names matching RE (repeatable)",
          "`filter.drop_patterns`: one element per pattern",
          [](CliOptions& o, const std::string& v) { o.gen.filter.drop_patterns.push_back(v); return true; });
    value("--drop-names", "", "FILE", {}, "none", G_PATTERNS, "Drop the names listed in FILE (optional class after a tab)",
          "`filter.drop_names_file`",
          [](CliOptions& o, const std::string& v) { o.gen.filter.drop_names_file = v; return !v.empty(); });

    // Pipeline
    value("--filter-at", "", "M", {"input", "output"}, "input", G_PIPE,
          "input: never query dropped variables; output: query all, filter when writing (for testing)",
          "`filter.filter_at`: `FilterAt::Input`, `Output`",
          [](CliOptions& o, const std::string& v) {
              return pick<FilterAt>(v, {{"input", FilterAt::Input}, {"output", FilterAt::Output}}, o.gen.filter.filter_at);
          });

    flag("--classify-only", "", G_PIPE, "Only classify the variables: write __variables.csv and __summary.json without solving",
         "`run.classify_only = true`; for a DIMACS file, `dimacs2graphs::classify()` gives the same rows without writing files",
         [](CliOptions& o) { o.gen.run.classify_only = true; });

    // Products
    flag("--or-graph", "", G_OR, "Write the third graph __atleastone.net (doubles the solver calls)",
         "`output.or_graph = true`",
         [](CliOptions& o) { o.gen.output.or_graph = true; });
    value("--atomic", "", "M", {"on", "off"}, "on", G_PRODUCTS, "Write the atomic sets (__atomic.txt)",
          "`output.atomic`",
          [](CliOptions& o, const std::string& v) { return on_off(v, o.gen.output.atomic); });
    value("--minimal", "", "M", {"on", "off"}, "on", G_PRODUCTS,
          "Write the minimal form (skeleton and primitive links), from which 'expand' rebuilds the graphs",
          "`output.minimal`",
          [](CliOptions& o, const std::string& v) { return on_off(v, o.gen.output.minimal); });
    flag("--kernel", "", G_PRODUCTS,
         "Write the kernel. It preserves what two-option rules say about compatibility, not rules over three or more options",
         "`output.kernel = true`",
         [](CliOptions& o) { o.gen.output.kernel = true; });
    value("--check", "", "M", {"on", "off"}, "on", G_PRODUCTS, "Run the consistency checks on the output",
          "`output.check`",
          [](CliOptions& o, const std::string& v) { return on_off(v, o.gen.output.check); });
    flag("--no-fail-on-check", "", G_PRODUCTS, "A failed check does not change the exit code",
         "`output.fail_on_check = false`",
         [](CliOptions& o) { o.gen.output.fail_on_check = false; });
    value("--max-matrix-memory", "", "GB", {}, "2", G_PRODUCTS, "Above this estimate, minimal form and checks use sparse algorithms",
          "`run.max_matrix_memory_gb`",
          [](CliOptions& o, const std::string& v) {
              char* end; double d = std::strtod(v.c_str(), &end);
              if (*end || !(d > 0)) return false;   // also NaN
              o.gen.run.max_matrix_memory_gb = d;
              return true;
          });
    flag("--representativeness", "", G_COUNT,
         "Count with GANAK the products and the choices that the graphs let pass: how much of the model the graphs leave out "
         "(turns on --or-graph)",
         "`output.representativeness = true` (and `output.or_graph = true`)",
         [](CliOptions& o) { o.gen.output.representativeness = true; o.gen.output.or_graph = true; });
    value("--ganak", "", "PATH", {}, "ganak", G_COUNT, "The model counter GANAK, a path or a name found on the PATH",
          "`run.ganak`",
          [](CliOptions& o, const std::string& v) {
              if (v.empty()) return false;
              o.gen.run.ganak = v;
              return true;
          });

    // UVL
    flag("--strict-uvl", "", G_UVL, "A skipped UVL constraint (not Boolean, or naming a feature that the model does not declare, such as an imported one) is an error (exit code 6)",
         "`run.strict_uvl = true`",
         [](CliOptions& o) { o.gen.run.strict_uvl = true; });

    // Compatibility
    flag("--legacy", "", G_COMPAT, "Reproduce the output of Strong4VM 1.x (except defects D5–D7)",
         "`set_legacy()` (`dimacs2graphs::apply_legacy()` for `GenerateOptions`); call it before setting other fields",
         [](CliOptions&) {});  // applied before the other options (see parse_generate_args)

    // Terminal
    value("--progress", "", "M", {"auto", "on", "off"}, "auto", G_TERM, "Progress output (auto: only on a terminal)",
          "`run.progress`: `Progress::Auto`, `On`, `Off`",
          [](CliOptions& o, const std::string& v) {
              return pick<Progress>(v, {{"auto", Progress::Auto}, {"on", Progress::On}, {"off", Progress::Off}}, o.gen.run.progress);
          });
    flag("--quiet", "-q", G_TERM, "Only warnings and errors",
         "`run.quiet = true`, the default of `AnalysisOptions` (set `false` to see the messages)",
         [](CliOptions& o) { o.gen.run.quiet = true; });
    flag("--verbose", "-v", G_TERM, "More detail",
         "`run.verbose = true`, with `run.quiet = false`",
         [](CliOptions& o) { o.gen.run.verbose = true; });

    // Information
    flag("--version", "", G_INFO, "Print the version",
         "`dimacs2graphs::version()`",
         [](CliOptions& o) { o.version = true; });
    flag("--help", "-h", G_INFO, "Print this help",
         "",
         [](CliOptions& o) { o.help = true; });
    flag("--print-rules-md", "", G_INFO, "Print docs/filters.md",
         "",
         [](CliOptions& o) { o.print_rules_md = true; }, true);
    flag("--print-options-md", "", G_INFO, "Print the option reference of README.md",
         "",
         [](CliOptions& o) { o.print_options_md = true; }, true);
    flag("--print-api-md", "", G_INFO, "Print the table of README.md that gives the field of the API of each option",
         "",
         [](CliOptions& o) { o.print_api_md = true; }, true);
    return t;
}

std::string accepted(const OptionSpec& s) {
    std::string a;
    for (size_t i = 0; i < s.values.size(); ++i) a += (i ? ", " : "") + s.values[i];
    return a;
}

}  // namespace

const std::vector<OptionSpec>& generate_options() {
    static const std::vector<OptionSpec> table = build_table();
    return table;
}

bool parse_generate_args(const std::vector<std::string>& args, CliOptions& out, std::string& error) {
    const auto& table = generate_options();
    for (const auto& a : args)
        if (a == "--legacy") apply_legacy(out.gen);

    for (size_t i = 0; i < args.size(); ++i) {
        std::string a = args[i];
        if (a.empty()) continue;
        if (a[0] != '-' || a == "-") {
            if (!out.input.empty()) {
                error = "more than one input file given ('" + out.input + "' and '" + a + "'). Give exactly one input file.";
                return false;
            }
            out.input = a;
            continue;
        }
        std::string value;
        bool inline_value = false;
        size_t eq = a.find('=');
        if (a.compare(0, 2, "--") == 0 && eq != std::string::npos) {
            value = a.substr(eq + 1);
            a = a.substr(0, eq);
            inline_value = true;
        }
        const OptionSpec* spec = nullptr;
        for (const auto& s : table)
            if (a == s.name || (!s.alias.empty() && a == s.alias)) spec = &s;
        if (!spec) {
            error = "unknown option '" + a + "'. Run 'strong4vm --help' for the list of options.";
            return false;
        }
        if (spec->arg.empty()) {
            if (inline_value) {
                error = "option " + spec->name + " takes no value; write it without '=" + value + "'.";
                return false;
            }
            spec->set(out, "");
            continue;
        }
        if (!inline_value) {
            if (i + 1 >= args.size()) {
                error = "option " + spec->name + " needs a value" +
                        (spec->values.empty() ? " (" + spec->arg + ")." : "; accepted values: " + accepted(*spec) + ".");
                return false;
            }
            value = args[++i];
        }
        if (!spec->values.empty()) {
            bool ok = false;
            for (const auto& v : spec->values) ok = ok || v == value;
            if (!ok) {
                error = "invalid value '" + value + "' for " + spec->name + "; accepted values: " + accepted(*spec) + ".";
                return false;
            }
        }
        if (!spec->set(out, value)) {
            error = "invalid value '" + value + "' for " + spec->name + " (expected " + spec->arg + ").";
            return false;
        }
    }
    return true;
}

void print_options_markdown(std::ostream& out) {
    std::vector<std::string> groups;
    for (const auto& s : generate_options()) {
        bool seen = false;
        for (const auto& g : groups) seen = seen || g == s.group;
        if (!seen) groups.push_back(s.group);
    }
    auto cell = [](const std::string& t) {
        std::string o;
        for (char c : t) o += c == '|' ? std::string("\\|") : std::string(1, c);
        return o;
    };
    for (const auto& g : groups) {
        out << "**" << g << "**\n\n| Option | Values | Default | Meaning |\n|---|---|---|---|\n";
        for (const auto& s : generate_options()) {
            if (s.group != g || s.hidden) continue;
            std::string name = (s.alias.empty() ? "" : "`" + s.alias + "`, ") + "`" + s.name + (s.arg.empty() ? "" : " " + s.arg) + "`";
            std::string values;
            for (size_t i = 0; i < s.values.size(); ++i) values += (i ? ", " : "") + ("`" + s.values[i] + "`");
            std::string def = (s.group == G_INFO || s.default_text.empty()) ? "" : s.default_text;
            out << "| " << name << " | " << values << " | " << cell(def) << " | " << cell(s.help) << " |\n";
        }
        out << "\n";
    }
}

void print_api_markdown(std::ostream& out) {
    auto cell = [](const std::string& t) {
        std::string o;
        for (char c : t) o += c == '|' ? std::string("\\|") : std::string(1, c);
        return o;
    };
    out << "| Option of `generate` | In the API: field of `AnalysisOptions` (or of `GenerateOptions`) |\n|---|---|\n";
    for (const auto& s : generate_options()) {
        if (s.hidden || s.api.empty()) continue;
        std::string name = (s.alias.empty() ? "" : "`" + s.alias + "`, ") + "`" + s.name + (s.arg.empty() ? "" : " " + s.arg) + "`";
        out << "| " << name << " | " << cell(s.api) << " |\n";
    }
    out << "\n";
}

void print_generate_help(std::ostream& out, const std::string& program) {
    out << "Usage:\n"
        << "  " << program << " [generate] <input.uvl|input.dimacs|input.cnf> [options]\n"
        << "  " << program << " check   <prefix> [--no-fail-on-check] [--max-matrix-memory GB] [--json]\n"
        << "  " << program << " expand  <prefix> [-o DIR]\n"
        << "  " << program << " explain <prefix> (--conflict A B | --requires A B) [--json]\n"
        << "  " << program << " diff    <old_prefix> <new_prefix> [-o DIR] [--rename FILE]\n"
        << "  " << program << " --version | --help\n\n"
        << "A <prefix> is the path of the output files without their suffix, e.g. out/model.\n\n"
        << "Options of generate:\n";
    std::vector<std::string> groups;
    for (const auto& s : generate_options()) {
        bool seen = false;
        for (const auto& g : groups) seen = seen || g == s.group;
        if (!seen) groups.push_back(s.group);
    }
    for (const auto& g : groups) {
        out << "\n  " << g << ":\n";
        for (const auto& s : generate_options()) {
            if (s.group != g || s.hidden) continue;
            std::string left = "    " + (s.alias.empty() ? "    " : s.alias + ", ") + s.name;
            if (!s.arg.empty()) left += " " + (s.values.empty() ? s.arg : "{" + accepted(s) + "}");
            out << left << "\n        " << s.help;
            if (s.group == G_INFO || s.default_text.empty()) out << "\n";
            else out << " [default: " << s.default_text << "]\n";
        }
    }
    out << "\nOutput files (<prefix> = <output dir>/<input base name>):\n"
        << "  __requires.net, __excludes.net   strong dependencies and conflicts (Pajek)\n"
        << "  __atleastone.net                 \"at least one\" graph (--or-graph)\n"
        << "  __core.txt, __dead.txt           core and dead options\n"
        << "  __atomic.txt                     atomic sets (--atomic on)\n"
        << "  __requires_skeleton.net, __excludes_primitive.net, __atleastone_primitive.net  minimal form\n"
        << "  __kernel_requires.net, __kernel_excludes.net, __kernel_classes.txt            kernel (--kernel)\n"
        << "  __variables.csv                  classification of every variable\n"
        << "  __summary.json                   counts, options, checks, warnings, timings\n"
        << "\nExit codes: 0 success, 1 usage error, 2 input error, 3 void model, 4 solver error,\n"
        << "            5 unknown name (--unknown-names error), 6 skipped constraint (--strict-uvl),\n"
        << "            7 consistency check failed\n";
}

} // namespace strong4vm
