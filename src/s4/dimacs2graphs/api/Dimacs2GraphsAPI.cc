/**
 * @file Dimacs2GraphsAPI.cc
 * @brief Implementation of the Dimacs2GraphsAPI class and of the free functions of R-API-03
 *
 * Every call runs the Strong4VM 2.0 pipeline of core/Pipeline.hh (classify,
 * merge, global backbone, main loop, atomic sets, minimal form, kernel,
 * checks) or one of the analyses of core/Analyses.hh, and returns its
 * products in memory (R-API-02). No exception leaves these functions: each
 * one ends with an exit code of Section 13 and a message, as the command line
 * does, which calls them for its sub-commands.
 *
 * @warning BoneDiggerAPI is NOT thread-safe during initialisation. All solver
 *          instances are created in the calling thread before workers start.
 */

#include "Dimacs2GraphsAPI.hh"
#include "RunResults.hh"
#include "../core/Analyses.hh"
#include "../core/Pipeline.hh"
#include "../core/Version.hh"
#include "../filter/Classifier.hh"
#include "../graphs/Graph.hh"
#include "../io/DimacsFormula.hh"

#include <cstdlib>
#include <exception>
#include <filesystem>
#include <fstream>
#include <map>
#include <new>
#include <sstream>
#include <string>
#include <system_error>
#include <vector>

using namespace std;

namespace dimacs2graphs {

namespace {

CsrGraph to_csr(int n, const vector<Link>& links, bool symmetric) {
    Csr c = Csr::from_links(n, links, symmetric);
    CsrGraph g;
    g.num_nodes = n;
    g.offset = c.offset;
    g.target = c.target;
    return g;
}

VariableInfo to_info(const vector<string>& r) {
    VariableInfo v;
    v.dimacs_var = r[0].empty() ? 0 : atoi(r[0].c_str());
    v.name = r[1];
    v.output_name = r[2];
    v.node_id = r[3].empty() ? 0 : atoi(r[3].c_str());
    v.var_class = r[4];
    v.status = r[5];
    v.decision = r[6];
    v.rule = r[7];
    return v;
}

/// Resolves "model" to "model.dimacs" when only the latter exists (1.x callers). Never throws: a path that
/// cannot be examined is returned as it is, and reading it gives the message.
string resolve(const string& path) {
    error_code ec;
    if (!filesystem::exists(path, ec) && !ec && filesystem::exists(path + ".dimacs", ec)) return path + ".dimacs";
    return path;
}

/// The message of a check that failed (exit code 7), with the identifiers of the checks.
string failed_checks(const string& prefix, const Json& report) {
    string ids;
    if (const Json* results = report.find("results"))
        for (const auto& c : results->items()) {
            const Json* passed = c.find("passed");
            if (passed && !passed->as_bool()) ids += (ids.empty() ? "" : ", ") + c.find("id")->as_string();
        }
    return "consistency check failed for '" + prefix + "': " + ids + ". The report lists the violations of each check "
           "with examples; with fail_on_check = false (option --no-fail-on-check) a failed check does not change the "
           "exit code.";
}

}  // namespace

/**
 * @class Dimacs2GraphsAPI::Impl
 * @brief PIMPL (Pointer to Implementation) idiom for ABI stability
 */
class Dimacs2GraphsAPI::Impl {
public:
    int num_variables = 0;
    int num_clauses = 0;
    vector<int> global_backbone;
    string error_message;
    bool filter_auxiliary = false;
    ExitCode exit_code = ExitCode::Success;

    GraphsResult run(const string& dimacs_file, const GenerateOptions& options) {
        GraphsResult out;   // the one allocation outside the guard (RunResults.hh)
        num_variables = num_clauses = 0;
        global_backbone.clear();
        error_message.clear();
        exit_code = ExitCode::Success;

        run_guarded([&] { return "analyse '" + dimacs_file + "'"; }, exit_code, error_message,
                    [&] { fill(dimacs_file, options, out); });
        out.exit_code = static_cast<int>(exit_code);
        copy_message(out.error_message, error_message);
        out.success = exit_code == ExitCode::Success;
        return out;
    }

private:
    /// Computes everything first, then hands it over with moves that cannot throw: after an exception the result
    /// and the getters are still those of an empty run.
    void fill(const string& dimacs_file, const GenerateOptions& options, GraphsResult& out) {
        GenerateRequest req;
        req.dimacs_path = resolve(dimacs_file);
        req.input_path = req.dimacs_path;
        req.options = options;
        req.stem = path_stem(req.dimacs_path);
        string dir = options.run.output_dir;
        if (dir.size() > 1 && (dir.back() == '/' || dir.back() == '\\')) dir.pop_back();
        req.output_dir = dir.empty() ? path_dir(req.dimacs_path) : dir;
        req.command_line = "Dimacs2GraphsAPI::generate(" + dimacs_file + ")";

        GenerateResult g = run_generate(req);
        GraphsResult converted = to_graphs_result(g);
        vector<int> backbone = backbone_literals(g);
        int variables = 0, clauses = 0;
        if (const Json* in = g.summary.find("input")) {
            if (const Json* v = in->find("variables")) variables = static_cast<int>(v->as_int());
            if (const Json* c = in->find("clauses")) clauses = static_cast<int>(c->as_int());
        }
        exit_code = g.code;
        error_message.swap(g.error);
        out = std::move(converted);
        global_backbone.swap(backbone);
        num_variables = variables;
        num_clauses = clauses;
    }
};

// API Implementation

Dimacs2GraphsAPI::Dimacs2GraphsAPI() : pimpl(new Impl()) {}

Dimacs2GraphsAPI::~Dimacs2GraphsAPI() {
    delete pimpl;
}

bool Dimacs2GraphsAPI::generate_graphs(const string& dimacs_file, const string& output_folder,
                                       const string& detector, int num_of_threads) {
    if (num_of_threads < 1) {
        pimpl->exit_code = ExitCode::Usage;
        pimpl->error_message = "num_of_threads must be at least 1 (got " + std::to_string(num_of_threads) +
                               "). Give a positive number of threads.";
        return false;
    }
    GenerateOptions o;
    o.filter.translator = pimpl->filter_auxiliary ? Translator::Uvl : Translator::Auto;
    o.run.output_dir = output_folder;
    o.run.detector = detector;
    o.run.threads = num_of_threads;
    return pimpl->run(dimacs_file, o).success;
}

GraphsResult Dimacs2GraphsAPI::generate(const string& dimacs_file, const GenerateOptions& options) {
    return pimpl->run(dimacs_file, options);
}

int Dimacs2GraphsAPI::get_num_variables() const {
    return pimpl->num_variables;
}

int Dimacs2GraphsAPI::get_num_clauses() const {
    return pimpl->num_clauses;
}

vector<int> Dimacs2GraphsAPI::get_global_backbone() const {
    return pimpl->global_backbone;
}

string Dimacs2GraphsAPI::get_error_message() const {
    return pimpl->error_message;
}

void Dimacs2GraphsAPI::set_filter_auxiliary(bool filter) {
    pimpl->filter_auxiliary = filter;
}

int Dimacs2GraphsAPI::get_exit_code() const {
    return static_cast<int>(pimpl->exit_code);
}

// The products of a run in the form of the API (RunResults.hh)

GraphsResult to_graphs_result(const GenerateResult& g) {
    GraphsResult out;
    out.exit_code = static_cast<int>(g.code);
    out.error_message = g.error;
    out.success = g.code == ExitCode::Success;
    out.summary = g.summary;
    out.summary_json = g.summary.dump();
    out.warnings = g.warnings;
    out.files = g.files;
    const int n = static_cast<int>(g.node_names.size());
    out.node_names = g.node_names;
    out.requires_graph = to_csr(n, g.requires_arcs, false);
    out.excludes_graph = to_csr(n, g.excludes_edges, true);
    out.atleastone_graph = to_csr(n, g.atleastone_edges, true);
    for (const auto& c : g.core) out.core.push_back(c.name);
    for (const auto& d : g.dead) out.dead.push_back(d.name);
    for (const auto& r : g.variable_rows) out.variables.push_back(to_info(r));
    return out;
}

namespace {

/// Sets the message of an exception; if there is no memory to make it, a text short enough to need none.
template <class Make>
void set_message(string& error, const char* fallback, Make&& make) noexcept {
    try {
        error = make();
    } catch (...) {
        try { error = fallback; } catch (...) {}   // 15 characters or fewer: no allocation
    }
}

}  // namespace

bool run_guarded(FunctionRef<string()> what, ExitCode& code, string& error, FunctionRef<void()> body) noexcept {
    try {
        body();
        return true;
    } catch (const bad_alloc&) {
        code = ExitCode::Input;
        set_message(error, "out of memory", [&] {
            return "not enough memory to " + what() + ". The input, or the graphs it gives, are too large for this machine. "
                   "Check that the input files are right (one wrong number in a formula or in a graph makes it as large as "
                   "that number), or use a machine with more memory.";
        });
    } catch (const exception& e) {
        code = ExitCode::Solver;
        set_message(error, "internal error", [&] {
            return "internal error while trying to " + what() + ": " + e.what() + ". Please report it with the input files.";
        });
    } catch (...) {
        code = ExitCode::Solver;
        set_message(error, "internal error", [&] {
            return "internal error while trying to " + what() + ". Please report it with the input files.";
        });
    }
    return false;
}

void copy_message(string& to, const string& from) noexcept {
    set_message(to, "out of memory", [&] { return from; });
}

vector<int> backbone_literals(const GenerateResult& g) {
    vector<int> literals;
    for (size_t v = 1; v < g.status.size(); ++v) {
        if (g.status[v] == VarStatus::Core) literals.push_back(static_cast<int>(v));
        else if (g.status[v] == VarStatus::Dead) literals.push_back(-static_cast<int>(v));
    }
    return literals;
}

// Free functions (R-API-03)

string version() {
    return STRONG4VM_VERSION;
}

ClassificationResult classify(const string& dimacs_file, const FilterOptions& options) {
    ClassificationResult out;
    ExitCode code = ExitCode::Success;
    string error;
    const bool finished = run_guarded([&] { return "classify '" + dimacs_file + "'"; }, code, error, [&] {
        GenerateOptions o;
        o.filter = options;
        error = validate_options(o);
        if (!error.empty()) {
            code = ExitCode::Usage;
            return;
        }
        DimacsFormula f;
        if (!read_dimacs(resolve(dimacs_file), f, error)) {
            code = ExitCode::Input;
            return;
        }
        ClassifyContext ctx;
        ctx.input_path = dimacs_file;
        Classification c = classify(f, options, ctx);
        if (c.code != ExitCode::Success) {
            code = c.code;
            error = c.error;
            return;
        }
        apply_merges(f, c, options);
        out.translator = to_string(c.detection.profile);
        out.detected_by = c.detection.how;
        out.warnings = c.warnings;
        for (int v = 1; v <= f.num_vars; ++v) {
            const VarInfo& vi = c.vars[v];
            const bool kept = vi.decision == Decision::Keep || vi.decision == Decision::MergeCandidate;
            VariableInfo info;
            info.dimacs_var = v;
            info.name = f.names[v];
            info.output_name = kept ? vi.output_name : "";
            info.var_class = to_string(vi.cls);
            info.decision = vi.decision == Decision::Merged ? "merged_into:" + c.vars[vi.merged_into].output_name
                                                            : kept ? "kept" : "dropped";
            info.rule = vi.rule;
            out.variables.push_back(info);
        }
    });
    if (!finished || code != ExitCode::Success) out = ClassificationResult();   // allocates nothing
    out.exit_code = static_cast<int>(code);
    out.error_message.swap(error);
    out.success = code == ExitCode::Success;
    return out;
}

Json check(const string& prefix, int& exit_code, string& error, double max_matrix_memory_gb, bool fail_on_check) {
    Json r;
    ExitCode code = ExitCode::Success;
    error.clear();
    run_guarded([&] { return "check '" + prefix + "'"; }, code, error, [&] {
        if (!(max_matrix_memory_gb > 0)) {   // also NaN
            GenerateOptions o;
            o.run.max_matrix_memory_gb = max_matrix_memory_gb;
            error = validate_options(o);
            code = ExitCode::Usage;
            return;
        }
        AnalysisStatus st;
        r = check_outputs(prefix, max_matrix_memory_gb, st);
        code = st.code;
        error = st.error;
        if (st.ok() && fail_on_check && !r.find("passed")->as_bool()) {
            code = ExitCode::CheckFailed;
            error = failed_checks(prefix, r);
        }
    });
    exit_code = static_cast<int>(code);
    return r;
}

Json expand(const string& prefix, const string& output_dir, int& exit_code, string& error) {
    Json r;
    ExitCode code = ExitCode::Success;
    error.clear();
    run_guarded([&] { return "expand '" + prefix + "'"; }, code, error, [&] {
        AnalysisStatus st;
        r = expand_outputs(prefix, output_dir, st);
        code = st.code;
        error = st.error;
    });
    exit_code = static_cast<int>(code);
    return r;
}

bool expand(const string& prefix, const string& output_dir, string& error) {
    int code = 0;
    expand(prefix, output_dir, code, error);
    return code == 0;
}

Json explain(const string& prefix, const string& a, const string& b, const string& kind, int& exit_code, string& error) {
    Json r;
    ExitCode code = ExitCode::Success;
    error.clear();
    run_guarded([&] { return "explain '" + a + "' and '" + b + "' in '" + prefix + "'"; }, code, error, [&] {
        if (kind != "conflict" && kind != "requires") {
            error = "unknown kind '" + kind + "' for explain. Give \"conflict\" or \"requires\".";
            code = ExitCode::Usage;
            return;
        }
        AnalysisStatus st;
        r = explain_relation(prefix, kind == "conflict" ? ExplainKind::Conflict : ExplainKind::Requires, a, b, st);
        code = st.code;
        error = st.error;
    });
    exit_code = static_cast<int>(code);
    return r;
}

bool read_renames(const string& path, map<string, string>& renames, string& error) {
    ExitCode code = ExitCode::Success;
    error.clear();
    bool ok = false;
    run_guarded([&] { return "read the renamed options of '" + path + "'"; }, code, error, [&] {
        ifstream in(path);
        if (!in.is_open()) {
            error = "cannot open '" + path + "', the file given with --rename. Check that the file exists and is readable.";
            return;
        }
        string line;
        long no = 0;
        map<string, long> old_line, new_line;   // where each old and each new name of this file was given
        auto bad = [&](const string& what) {
            error = path + ":" + std::to_string(no) + ": " + what + " Write one rename per line: the old name, a space, and the "
                    "new name, as in 'BLEv40Old BLEv40' (a tab instead of the space if a name has spaces).";
        };
        auto trimmed = [](const string& s) {
            size_t b = s.find_first_not_of(" "), e = s.find_last_not_of(" ");
            return b == string::npos ? string() : s.substr(b, e - b + 1);
        };
        while (getline(in, line)) {
            ++no;
            if (!line.empty() && line.back() == '\r') line.pop_back();
            if (line.find_first_not_of(" \t") == string::npos || line[0] == '#') continue;
            string old_name, new_name;
            size_t tab = line.find('\t');
            if (tab != string::npos) {
                if (line.find('\t', tab + 1) != string::npos) { bad("expected 'old_name new_name', but the line has more than one tab."); return; }
                old_name = trimmed(line.substr(0, tab));
                new_name = trimmed(line.substr(tab + 1));
                if (old_name.empty() || new_name.empty()) { bad("expected 'old_name new_name', but a name on one side of the tab is empty."); return; }
            } else {
                vector<string> words;
                std::istringstream ws(line);
                for (string w; ws >> w;) words.push_back(w);
                if (words.size() == 1) {
                    error = path + ":" + std::to_string(no) + ": expected 'old_name new_name'. Write one pair per line, the old name, "
                            "a space, and the new name (a tab instead of the space if a name has spaces).";
                    return;
                }
                if (words.size() > 2) {
                    bad("expected 'old_name new_name', but the line has " + std::to_string(words.size()) + " words.");
                    return;
                }
                old_name = words[0];
                new_name = words[1];
                const char last = old_name.back();
                if (last == ',' || last == ';') {
                    bad(string("the old name '") + old_name + "' ends with '" + last + "': nothing goes between the two names but the "
                        "space (if the name really ends so, separate the names with a tab).");
                    return;
                }
            }
            if (old_line.count(old_name)) {
                bad("'" + old_name + "' was already renamed on line " + std::to_string(old_line[old_name]) + ".");
                return;
            }
            if (new_line.count(new_name)) {
                bad("two features cannot both become '" + new_name + "' (line " + std::to_string(new_line[new_name]) + " gives it too).");
                return;
            }
            old_line[old_name] = no;
            new_line[new_name] = no;
            renames[old_name] = new_name;
        }
        if (in.bad()) {   // a read error ends the loop as the end of the file would
            error = read_error(path, no);
            return;
        }
        ok = true;
    });
    return ok;
}

Json diff(const string& old_prefix, const string& new_prefix, const map<string, string>& renames,
          const string& output_dir, int& exit_code, string& error) {
    Json r;
    ExitCode code = ExitCode::Success;
    error.clear();
    run_guarded([&] { return "compare '" + old_prefix + "' with '" + new_prefix + "'"; }, code, error, [&] {
        AnalysisStatus st;
        r = diff_outputs(old_prefix, new_prefix, renames, output_dir, st);
        code = st.code;
        error = st.error;
    });
    exit_code = static_cast<int>(code);
    return r;
}

} // namespace dimacs2graphs
