#include "vp_io.h"  // added by variplex (tools/sync_cpp.R)
/**
 * @file Pipeline.cc
 * @brief The `generate` pipeline (see Pipeline.hh)
 */

#include "Counting.hh"
#include "Pipeline.hh"
#include "Version.hh"
#include "../graphs/Atomic.hh"
#include "../graphs/Checks.hh"
#include "../graphs/Minimal.hh"
#include "../graphs/Kernel.hh"

#include <new>
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <iostream>
#include <map>

namespace dimacs2graphs {

const char* status_name(VarStatus s) {
    switch (s) {
        case VarStatus::Core: return "core";
        case VarStatus::Dead: return "dead";
        default: return "variable";
    }
}

std::string csv_field(const std::string& s) {
    if (s.find_first_of(",\"\r\n") == std::string::npos) return s;
    std::string q = "\"";
    for (char c : s) {
        if (c == '"') q += '"';
        q += c;
    }
    return q + "\"";
}

namespace {

using Clock = std::chrono::steady_clock;

double seconds_since(Clock::time_point t) {
    return std::chrono::duration<double>(Clock::now() - t).count();
}

Json options_json(const GenerateOptions& o) {
    const FilterOptions& f = o.filter;
    Json j = Json::object();
    j["translator"] = to_string(f.translator);
    j["tristate"] = to_string(f.tristate);
    j["nonbool"] = to_string(f.nonbool);
    j["visibility"] = f.drop_visibility ? "drop" : "keep";
    j["abstract_groups"] = to_string(f.abstract_groups);
    j["synthetic_root"] = f.drop_synthetic_root ? "drop" : "keep";
    j["abstract"] = to_string(f.abstract_features);
    j["fixed_nodes"] = f.drop_fixed_nodes ? "drop" : "keep";
    j["unnamed"] = f.drop_unnamed ? "drop" : "keep";
    j["unknown_names"] = to_string(f.unknown_names);
    j["decls"] = f.decls_file ? Json(*f.decls_file) : Json();
    j["decls_unconstrained"] = f.add_unconstrained ? "add" : "ignore";
    j["keep_type_prefix"] = f.keep_type_prefix;
    j["strip_config_prefix"] = f.strip_config_prefix;
    j["keep_pattern"] = Json::array_of(f.keep_patterns);
    j["drop_pattern"] = Json::array_of(f.drop_patterns);
    j["drop_names"] = f.drop_names_file ? Json(*f.drop_names_file) : Json();
    j["filter_at"] = to_string(f.filter_at);
    j["or_graph"] = o.output.or_graph;
    j["atomic"] = o.output.atomic ? "on" : "off";
    j["minimal"] = o.output.minimal ? "on" : "off";
    j["kernel"] = o.output.kernel;
    j["representativeness"] = o.output.representativeness;
    j["ganak"] = o.run.ganak;
    j["check"] = o.output.check ? "on" : "off";
    j["fail_on_check"] = o.output.fail_on_check;
    j["strict_uvl"] = o.run.strict_uvl;
    j["legacy"] = o.run.legacy;
    j["threads"] = o.run.threads;
    j["output"] = o.run.output_dir;
    j["progress"] = to_string(o.run.progress);
    j["max_matrix_memory_gb"] = o.run.max_matrix_memory_gb;
    j["detector"] = o.run.detector;
    return j;
}

}  // namespace

namespace {
GenerateResult run_pipeline(const GenerateRequest& req);
}  // namespace

GenerateResult run_generate(const GenerateRequest& req) {
    // No exception leaves the library: a run ends with one of the exit codes of Section 13 and a message
    // that says what happened and what to do (R-ERR-01).
    try {
        return run_pipeline(req);
    } catch (const std::bad_alloc&) {
        GenerateResult res;
        res.code = ExitCode::Input;
        res.error = "not enough memory to analyse '" + req.dimacs_path + "'. The formula, or the graphs it gives, are too "
                    "large for this machine. Check the 'p cnf' line and the variable numbers of the file (one wrong number "
                    "makes the formula as large as that number), or use a machine with more memory.";
        return res;
    } catch (const std::exception& e) {
        GenerateResult res;
        res.code = ExitCode::Solver;
        res.error = std::string("internal error while analysing '") + req.dimacs_path + "': " + e.what() +
                    ". Please report it with the input file.";
        return res;
    }
}

namespace {

GenerateResult run_pipeline(const GenerateRequest& req) {
    GenerateResult res;
    const GenerateOptions& opt = req.options;
    const bool quiet = opt.run.quiet;
    auto info = [&](const std::string& m) { if (!quiet) vp::out() << m << std::endl; };
    // -v, --verbose: classification counts, sizes and timings
    auto detail = [&](const std::string& m) { if (opt.run.verbose && !quiet) vp::out() << "  " << m << std::endl; };
    auto warn = [&](const std::string& m) {
        res.warnings.push_back(m);
        vp::err() << "Warning: " << m << std::endl;
    };
    auto fail = [&](ExitCode c, const std::string& m) {
        res.code = c;
        res.error = m;
        return res;
    };
    // Values that the parser of the command line rejects can come from the API (R-CLI-03)
    const std::string invalid = validate_options(opt);
    if (!invalid.empty()) return fail(ExitCode::Usage, invalid);
    const std::string base = req.output_dir + "/" + req.stem;
    Json& summary = res.summary;
    summary = Json::object();
    summary["strong4vm_version"] = STRONG4VM_VERSION;
    summary["command_line"] = req.command_line;
    summary["void"] = false;
    summary["options"] = options_json(opt);
    Json timings = Json::object();
    const auto run_start = Clock::now();

    // 1. Formula and name table
    auto t0 = Clock::now();
    DimacsFormula f;
    std::string err;
    if (!read_dimacs(req.dimacs_path, f, err)) return fail(ExitCode::Input, err);
    timings["parse"] = seconds_since(t0);
    if (static_cast<long long>(f.clauses.size()) < f.declared_clauses)
        warn("'" + req.dimacs_path + "' has " + std::to_string(f.clauses.size()) + " clauses, fewer than the " +
             std::to_string(f.declared_clauses) + " that its 'p cnf' line declares: the file may be cut short, and then it "
             "is analysed without the missing clauses. Check that the file was written or copied completely.");
    info("Loaded formula: " + req.dimacs_path + " (" + std::to_string(f.num_vars) + " variables, " +
         std::to_string(f.clauses.size()) + " clauses)");
    {
        // Names are bytes (R-OUT-02) and are written as they are; the reports are UTF-8 only if the names are
        long not_utf8 = 0;
        int first = 0;
        for (int v = 1; v <= f.num_vars; ++v)
            if (f.has_name(v) && !Json::valid_utf8(f.names[v])) { if (!not_utf8++) first = v; }
        if (not_utf8)
            warn("names that are not valid UTF-8 in '" + req.dimacs_path + "': " + std::to_string(not_utf8) + " (the first one is "
                 "the name of variable " + std::to_string(first) + "). Names are written to the graphs and to __variables.csv byte "
                 "for byte, so these files are not valid UTF-8 either; in __summary.json the offending bytes appear as U+FFFD. "
                 "Convert the formula to UTF-8 (for example with iconv) to get standard files.");
    }
    Json& input = summary["input"];
    input["path"] = req.input_path;
    input["dimacs"] = req.dimacs_path;
    input["variables"] = f.num_vars;
    input["clauses"] = static_cast<long long>(f.clauses.size());

    try {
        if (!std::filesystem::exists(req.output_dir)) std::filesystem::create_directories(req.output_dir);
    } catch (const std::exception& e) {
        return fail(ExitCode::Input, "could not create output directory '" + req.output_dir + "': " + e.what() +
                    ". Choose a writable directory with -o.");
    }

    // 2–3. Profile, classification, merges
    t0 = Clock::now();
    ClassifyContext cctx;
    cctx.input_is_uvl = req.input_is_uvl;
    cctx.input_path = req.input_path;
    res.classification = classify(f, opt.filter, cctx);
    Classification& cls = res.classification;
    if (cls.code != ExitCode::Success) return fail(cls.code, cls.error);
    const int original_vars = f.num_vars;
    int fresh = apply_merges(f, cls, opt.filter);
    timings["classify"] = seconds_since(t0);
    const Translator profile = cls.detection.profile;
    info(std::string("Translator profile: ") + to_string(profile) + " (" + cls.detection.how + ": " + cls.detection.evidence + ")");
    input["translator"]["profile"] = to_string(profile);
    input["translator"]["how"] = cls.detection.how;
    input["translator"]["evidence"] = cls.detection.evidence;
    input["translator"]["weak_evidence"] = cls.detection.weak;
    // The default of --unknown-names depends on the profile: record the value in effect (R-PRI-05)
    summary["options"]["unknown_names_effective"] = to_string(cls.unknown_policy);
    for (const auto& w : cls.warnings) warn(w);
    for (const auto& w : req.uvl.warnings) res.warnings.push_back(w);  // already printed by the converter
    if (opt.run.verbose && !quiet) {
        std::map<std::string, std::map<std::string, long>> rules;
        for (int v = 1; v <= f.num_vars; ++v) {
            const VarInfo& vi = cls.vars[v];
            const char* d = vi.decision == Decision::Merged ? "merged"
                            : (vi.decision == Decision::Keep || vi.decision == Decision::MergeCandidate) ? "kept" : "dropped";
            ++rules[std::string(to_string(vi.cls)) + " by " + vi.rule][d];
        }
        detail("Classification (class by rule: kept / dropped / merged):");
        for (const auto& r : rules)
            detail("  " + r.first + ": " + std::to_string(r.second.count("kept") ? r.second.at("kept") : 0) + " / " +
                   std::to_string(r.second.count("dropped") ? r.second.at("dropped") : 0) + " / " +
                   std::to_string(r.second.count("merged") ? r.second.at("merged") : 0));
        if (fresh) detail("Merges: " + std::to_string(cls.tristate_merged) + " tristate pairs, " +
                          std::to_string(cls.nonbool_merged) + " non-Boolean options (" + std::to_string(fresh) + " defined variables added)");
    }

    if (opt.run.classify_only) {
        AtomicFile vf(base + "__variables.csv");
        vf.out() << "dimacs_var,name,output_name,node_id,class,status,decision,rule\n";
        std::map<std::string, long> by_class;
        std::map<std::string, std::map<std::string, long>> by_rule;
        for (int v = 1; v <= f.num_vars; ++v) {
            const VarInfo& vi = cls.vars[v];
            bool k = vi.decision == Decision::Keep || vi.decision == Decision::MergeCandidate;
            std::string decision = vi.decision == Decision::Merged ? "merged_into:" + cls.vars[vi.merged_into].output_name
                                                                   : k ? "kept" : "dropped";
            vf.out() << v << ',' << csv_field(f.names[v]) << ',' << csv_field(k ? vi.output_name : "") << ",,"
                     << to_string(vi.cls) << ",," << csv_field(decision) << ',' << vi.rule << '\n';
            res.variable_rows.push_back({std::to_string(v), f.names[v], k ? vi.output_name : "", "", to_string(vi.cls), "",
                                         decision, vi.rule});
            ++by_class[to_string(vi.cls)];
            ++by_rule[vi.rule][vi.decision == Decision::Merged ? "merged" : k ? "kept" : "dropped"];
        }
        if (!vf.commit(err)) return fail(ExitCode::Input, err);
        res.files.push_back(base + "__variables.csv");
        Json& counts = summary["counts"];
        for (const auto& kv : by_class) counts["variables_by_class"][kv.first] = kv.second;
        for (const auto& kv : by_rule)
            for (const char* d : {"kept", "dropped", "merged"})
                counts["by_rule"][kv.first][d] = kv.second.count(d) ? kv.second.at(d) : 0L;
        counts["formula_variables"] = original_vars;
        counts["fresh_variables"] = fresh;
        counts["tristate_merged_pairs"] = cls.tristate_merged;
        counts["nonbool_merged_options"] = cls.nonbool_merged;
        counts["nonbool_without_not_set"] = Json::array_of(cls.nonbool_without_n);
        counts["unknown_kept"] = cls.unknown_kept;
        if (cls.decls_given) {
            Json& d = summary["decls"];
            d["declared_not_found"] = Json::array_of(cls.declared_not_found);
            d["declared_encoded_by_values"] = Json::array_of(cls.declared_encoded);
            d["undeclared_nonbool_options"] = Json::array_of(cls.undeclared_nonbool);
            d["dropped_only_by_decls"] = cls.dropped_only_by_decls;
        }
        summary["classify_only"] = true;
        summary["warnings"] = Json::array_of(res.warnings);
        summary["timings"] = timings;
        AtomicFile sf(base + "__summary.json");
        summary.dump(sf.out());
        if (!sf.commit(err)) return fail(ExitCode::Input, err);
        res.files.push_back(base + "__summary.json");
        info("Saved " + base + "__variables.csv and __summary.json (classification only)");
        return res;
    }

    // 4–5. Satisfiability and global backbone
    t0 = Clock::now();
    GlobalBackbone bb;
    const ExitCode backbone_code = compute_global_backbone(f, opt.run.detector, bb, err);
    timings["backbone"] = seconds_since(t0);
    auto write_summary = [&]() {
        summary["warnings"] = Json::array_of(res.warnings);
        summary["timings"] = timings;
        AtomicFile sf(base + "__summary.json");
        summary.dump(sf.out());
        std::string e;
        if (sf.commit(e)) res.files.push_back(base + "__summary.json");
        return e;
    };
    if (backbone_code == ExitCode::VoidModel) {
        summary["void"] = true;
        write_summary();
        return fail(ExitCode::VoidModel, "the formula '" + req.dimacs_path +
                    "' is unsatisfiable (void model): no configuration exists, so no graphs were written. "
                    "Look for contradictory constraints in the model; the summary " + base + "__summary.json records \"void\": true.");
    }
    if (backbone_code != ExitCode::Success) return fail(backbone_code, err);
    res.status = bb.status;

    // 6. Main loop over the queried variables (R-PIPE-02, R-PIPE-03)
    auto kept = [&](int v) {
        Decision d = cls.vars[v].decision;
        return d == Decision::Keep || d == Decision::MergeCandidate;
    };
    std::vector<int> query;
    for (int v = 1; v <= f.num_vars; ++v) {
        if (bb.status[v] != VarStatus::Variable) continue;
        if (opt.filter.filter_at == FilterAt::Output || kept(v)) query.push_back(v);
    }
    info("Querying " + std::to_string(query.size()) + " variables (" + to_string(opt.filter.filter_at) + " filter)");
    t0 = Clock::now();
    GraphBuildOptions gopts;
    gopts.threads = opt.run.threads;
    gopts.detector = opt.run.detector;
    gopts.or_graph = opt.output.or_graph;
    gopts.mig = opt.run.mig;
    gopts.progress = quiet ? Progress::Off : opt.run.progress;
    GraphBuildResult g = build_graphs(f, bb, query, gopts);
    timings["main_loop"] = seconds_since(t0);
    for (const auto& w : g.warnings) warn(w);
    if (g.code != ExitCode::Success) return fail(g.code, g.error);

    // 7. Atomic sets of the queried graph; resolve abstract group features (T2, pipeline step 10)
    t0 = Clock::now();
    {
        std::vector<int> gidx(f.num_vars + 1, -1), gvar;
        for (int v = 1; v <= f.num_vars; ++v)
            if (kept(v) && bb.status[v] == VarStatus::Variable) { gidx[v] = static_cast<int>(gvar.size()); gvar.push_back(v); }
        std::vector<Link> links;
        for (const auto& l : g.requires_arcs)
            if (gidx[l.first] >= 0 && gidx[l.second] >= 0) links.push_back({gidx[l.first] + 1, gidx[l.second] + 1});
        AtomicSets a = strongly_connected_components(Csr::from_links(static_cast<int>(gvar.size()), links, false));
        std::vector<std::string> not_equivalent;
        // A candidate is merged into an equivalent variable that is not a candidate itself (rule T2: "in an atomic
        // set with at least one variable not matching T2"; --abstract merge: an abstract feature, U4, into one that is
        // not abstract in the model). The targets are fixed before any candidate is resolved, so that a candidate kept
        // as an option never becomes the target of another one.
        std::vector<char> is_target(f.num_vars + 1, 0);
        for (int v = 1; v <= f.num_vars; ++v) is_target[v] = cls.vars[v].decision == Decision::Keep;
        for (int v = 1; v <= f.num_vars; ++v) {
            VarInfo& vi = cls.vars[v];
            if (vi.decision != Decision::MergeCandidate) continue;
            const bool abstract = vi.cls == VarClass::Abstract;
            auto fits = [&](int w) { return is_target[w] && !(abstract && f.is_abstract[w]); };
            int target = 0;
            if (bb.status[v] == VarStatus::Variable) {
                for (int m : a.members[a.comp[gidx[v]]]) {
                    int w = gvar[m];
                    if (fits(w)) { target = w; break; }  // members sorted: smallest first
                }
            } else {
                // Core (dead) variables are all equivalent to each other
                for (int w = 1; w <= f.num_vars && !target; ++w)
                    if (fits(w) && bb.status[w] == bb.status[v]) target = w;
            }
            if (target) {
                vi.decision = Decision::Merged;
                vi.merged_into = target;
                vi.marker = abstract ? "abstract" : "abstract-group";
            } else if (abstract) {
                vi.decision = Decision::Keep;   // equivalent to no feature that is not abstract: it stands for a choice
            } else {
                vi.cls = VarClass::Option;
                vi.decision = Decision::Keep;
                not_equivalent.push_back(f.names[v]);
            }
        }
        if (!not_equivalent.empty()) {
            std::string ex;
            for (size_t i = 0; i < not_equivalent.size() && i < 10; ++i) ex += (i ? ", " : "") + not_equivalent[i];
            warn(std::to_string(not_equivalent.size()) + " name(s) ending in _xor/_or/_alt are not equivalent to any "
                 "feature without such a suffix and are kept as options (T2): " + ex);
        }
    }
    timings["atomic"] = seconds_since(t0);

    // 8. Nodes: kept variables, without fixed ones under --fixed-nodes drop (R-FLT-20)
    t0 = Clock::now();
    res.var_node.assign(f.num_vars + 1, 0);
    for (int v = 1; v <= f.num_vars; ++v) {
        if (!kept(v)) continue;
        if (bb.status[v] != VarStatus::Variable && opt.filter.drop_fixed_nodes) continue;
        res.node_names.push_back(cls.vars[v].output_name);
        res.node_var.push_back(v);
        res.var_node[v] = static_cast<int>(res.node_names.size());
    }
    std::vector<std::string> unconstrained;
    if (opt.filter.add_unconstrained && cls.decls_given) {
        unconstrained = cls.declared_not_found;
        for (const auto& n : unconstrained) {
            res.node_names.push_back(n);
            res.node_var.push_back(0);
        }
    }
    for (int v = 1; v <= f.num_vars; ++v) {
        if (!kept(v)) continue;
        ListedNode ln{res.var_node[v], cls.vars[v].output_name};
        if (bb.status[v] == VarStatus::Core) res.core.push_back(ln);
        else if (bb.status[v] == VarStatus::Dead) res.dead.push_back(ln);
    }
    auto to_nodes = [&](const std::vector<Link>& links) {
        std::vector<Link> out;
        out.reserve(links.size());
        for (const auto& l : links) {
            int a = res.var_node[l.first], b = res.var_node[l.second];
            if (a && b) out.push_back({a, b});
        }
        std::sort(out.begin(), out.end());
        return out;
    };
    res.requires_arcs = to_nodes(g.requires_arcs);
    res.excludes_edges = to_nodes(g.excludes_edges);
    res.atleastone_edges = to_nodes(g.atleastone_edges);

    // Atomic sets in node ids (R-ATM-01, R-ATM-02)
    const int n_nodes = static_cast<int>(res.node_names.size());
    AtomicSets atomic = strongly_connected_components(Csr::from_links(n_nodes, res.requires_arcs, false));
    // Names are written as fields of a tab-separated line (tsv_field): unchanged, unless they hold a tab or
    // a backslash or end like a marker, so that `expand` reads every name back exactly.
    std::vector<std::vector<std::string>> marked(atomic.count());
    std::vector<char> has_group(atomic.count(), 0);
    for (int v = 1; v <= f.num_vars; ++v) {
        const VarInfo& vi = cls.vars[v];
        if (vi.decision != Decision::Merged || (vi.marker != "abstract-group" && vi.marker != "tristate" && vi.marker != "abstract"))
            continue;
        int node = res.var_node[vi.merged_into];
        if (!node || vi.output_name == cls.vars[vi.merged_into].output_name) continue;
        marked[atomic.comp[node - 1]].push_back(tsv_field(vi.output_name) + "[" + vi.marker + "]");
        if (vi.marker == "abstract-group" || vi.marker == "abstract") has_group[atomic.comp[node - 1]] = 1;
    }
    std::vector<std::string> atomic_lines;
    size_t largest = 1;
    for (int c = 0; c < atomic.count(); ++c) {
        const auto& m = atomic.members[c];
        if (m.size() < 2 && !has_group[c]) continue;
        std::string line;
        for (size_t i = 0; i < m.size(); ++i) line += (i ? "\t" : "") + tsv_field(res.node_names[m[i]], true);
        for (const auto& x : marked[c]) line += "\t" + x;
        atomic_lines.push_back(line);
        largest = std::max(largest, m.size() + marked[c].size());
    }
    timings["post_processing"] = seconds_since(t0);

    // 9. Write
    t0 = Clock::now();
    auto check = [&](bool ok, const std::string& file) {
        if (ok) { res.files.push_back(file); info("Saved " + file); }
        return ok;
    };
    if (!check(write_pajek(base + "__requires.net", res.node_names, res.requires_arcs, true, err), base + "__requires.net") ||
        !check(write_pajek(base + "__excludes.net", res.node_names, res.excludes_edges, false, err), base + "__excludes.net") ||
        (opt.output.or_graph &&
         !check(write_pajek(base + "__atleastone.net", res.node_names, res.atleastone_edges, false, err), base + "__atleastone.net")) ||
        !check(write_node_list(base + "__core.txt", res.core, err), base + "__core.txt") ||
        !check(write_node_list(base + "__dead.txt", res.dead, err), base + "__dead.txt"))
        return fail(ExitCode::Input, err);

    // Minimal form (F6): skeleton and primitive links between atomic sets
    MinimalForm minimal;
    if (opt.output.minimal || opt.output.kernel)
        minimal = compute_minimal(n_nodes, atomic, res.requires_arcs, res.excludes_edges,
                                  opt.output.or_graph ? &res.atleastone_edges : nullptr, opt.run.max_matrix_memory_gb);
    if (opt.output.minimal) {
        std::vector<std::string> reps;
        for (int c = 0; c < atomic.count(); ++c) reps.push_back(res.node_names[atomic.representative(c)]);
        if (!check(write_pajek(base + "__requires_skeleton.net", reps, minimal.skeleton, true, err), base + "__requires_skeleton.net") ||
            !check(write_pajek(base + "__excludes_primitive.net", reps, minimal.excludes_primitive, false, err), base + "__excludes_primitive.net") ||
            (opt.output.or_graph &&
             !check(write_pajek(base + "__atleastone_primitive.net", reps, minimal.atleastone_primitive, false, err), base + "__atleastone_primitive.net")))
            return fail(ExitCode::Input, err);
    }

    // Kernel (F7)
    Kernel kernel;
    if (opt.output.kernel) {
        kernel = compute_kernel(atomic, res.requires_arcs, minimal.excludes_primitive);
        std::vector<std::string> knames;
        AtomicFile kf(base + "__kernel_classes.txt");
        for (size_t c = 0; c < kernel.classes.size(); ++c) {
            std::vector<int> members;
            for (int comp : kernel.classes[c])
                for (int u : atomic.members[comp]) members.push_back(u);
            std::sort(members.begin(), members.end());
            knames.push_back(res.node_names[members[0]]);
            for (size_t i = 0; i < members.size(); ++i) kf.out() << (i ? "\t" : "") << tsv_field(res.node_names[members[i]]);
            kf.out() << '\n';
        }
        if (!check(kf.commit(err), base + "__kernel_classes.txt") ||
            !check(write_pajek(base + "__kernel_requires.net", knames, kernel.requires_arcs, true, err), base + "__kernel_requires.net") ||
            !check(write_pajek(base + "__kernel_excludes.net", knames, kernel.excludes_edges, false, err), base + "__kernel_excludes.net"))
            return fail(ExitCode::Input, err);
        info(std::string("Kernel: ") + KERNEL_LIMIT);
    }

    // __atomic.txt is part of the minimal form, so it is also written with --minimal on
    if (opt.output.atomic || opt.output.minimal) {
        AtomicFile af(base + "__atomic.txt");
        for (const auto& l : atomic_lines) af.out() << l << '\n';
        if (!check(af.commit(err), base + "__atomic.txt")) return fail(ExitCode::Input, err);
    }

    // __variables.csv (R-OUT-05)
    {
        AtomicFile vf(base + "__variables.csv");
        std::ostream& o = vf.out();
        o << "dimacs_var,name,output_name,node_id,class,status,decision,rule\n";
        for (int v = 1; v <= f.num_vars; ++v) {
            const VarInfo& vi = cls.vars[v];
            std::string decision = vi.decision == Decision::Merged
                                       ? "merged_into:" + cls.vars[vi.merged_into].output_name
                                       : kept(v) ? "kept" : "dropped";
            res.variable_rows.push_back({std::to_string(v), f.names[v], kept(v) ? vi.output_name : "",
                                         res.var_node[v] ? std::to_string(res.var_node[v]) : "", to_string(vi.cls),
                                         status_name(bb.status[v]), decision, vi.rule});
        }
        int id = static_cast<int>(res.node_names.size() - unconstrained.size());
        for (const auto& n : unconstrained)
            res.variable_rows.push_back({"", n, n, std::to_string(++id), "OPTION", "unconstrained", "kept", "R-FLT-18"});
        for (const auto& r : res.variable_rows) {
            for (size_t i = 0; i < r.size(); ++i) {
                if (i) o << ',';
                o << ((i == 1 || i == 2 || i == 6) ? csv_field(r[i]) : r[i]);
            }
            o << '\n';
        }
        if (!check(vf.commit(err), base + "__variables.csv")) return fail(ExitCode::Input, err);
    }
    timings["write"] = seconds_since(t0);

    // Summary (R-OUT-06)
    Json& counts = summary["counts"];
    std::map<std::string, long> by_class;
    std::map<std::string, std::map<std::string, long>> by_rule;
    long n_kept = 0, n_dropped = 0, n_merged = 0;
    for (int v = 1; v <= f.num_vars; ++v) {
        const VarInfo& vi = cls.vars[v];
        ++by_class[to_string(vi.cls)];
        const char* d = vi.decision == Decision::Merged ? "merged" : kept(v) ? "kept" : "dropped";
        ++by_rule[vi.rule][d];
        if (vi.decision == Decision::Merged) ++n_merged;
        else if (kept(v)) ++n_kept;
        else ++n_dropped;
    }
    Json& jc = counts["variables_by_class"];
    jc = Json::object();
    for (const auto& kv : by_class) jc[kv.first] = kv.second;
    Json& jr = counts["by_rule"];
    jr = Json::object();
    for (const auto& kv : by_rule) {
        Json& r = jr[kv.first];
        for (const char* d : {"kept", "dropped", "merged"}) r[d] = kv.second.count(d) ? kv.second.at(d) : 0L;
    }
    long variable_options = 0;
    for (int v = 1; v <= f.num_vars; ++v)
        if (kept(v) && bb.status[v] == VarStatus::Variable) ++variable_options;
    counts["formula_variables"] = original_vars;
    counts["fresh_variables"] = fresh;
    counts["kept"] = n_kept;
    counts["dropped"] = n_dropped;
    counts["merged"] = n_merged;
    counts["core"] = static_cast<long long>(res.core.size());
    counts["dead"] = static_cast<long long>(res.dead.size());
    counts["variable_options"] = variable_options;
    counts["unconstrained"] = static_cast<long long>(unconstrained.size());
    counts["nodes"] = static_cast<long long>(res.node_names.size());
    counts["arcs"] = static_cast<long long>(res.requires_arcs.size());
    counts["edges"] = static_cast<long long>(res.excludes_edges.size());
    if (opt.output.or_graph) counts["atleastone_edges"] = static_cast<long long>(res.atleastone_edges.size());
    counts["atomic_sets"] = static_cast<long long>(atomic_lines.size());
    if (opt.output.kernel) {
        counts["kernel_nodes"] = static_cast<long long>(kernel.classes.size());
        counts["kernel_arcs"] = static_cast<long long>(kernel.requires_arcs.size());
        counts["kernel_conflicts"] = static_cast<long long>(kernel.excludes_edges.size());
        summary["kernel"]["limit"] = KERNEL_LIMIT;
        summary["kernel"]["always_class_size"] = 0;
        if (kernel.always_class >= 0) {
            long long size = 0;
            for (int comp : kernel.classes[kernel.always_class]) size += static_cast<long long>(atomic.members[comp].size());
            summary["kernel"]["always_class_size"] = size;
        }
    }
    if (opt.output.minimal) {
        counts["skeleton_arcs"] = static_cast<long long>(minimal.skeleton.size());
        counts["primitive_conflicts"] = static_cast<long long>(minimal.excludes_primitive.size());
        if (opt.output.or_graph) counts["primitive_atleastone"] = static_cast<long long>(minimal.atleastone_primitive.size());
    }
    counts["largest_atomic_set"] = static_cast<long long>(atomic_lines.empty() ? 0 : largest);
    counts["tristate_merged_pairs"] = cls.tristate_merged;
    counts["nonbool_merged_options"] = cls.nonbool_merged;
    counts["nonbool_without_not_set"] = Json::array_of(cls.nonbool_without_n);
    counts["unknown_kept"] = cls.unknown_kept;
    counts["queried_variables"] = static_cast<long long>(query.size());
    counts["solver_calls"] = g.solver_calls;
    counts["solver_instances"] = g.solver_instances;
    counts["threads_used"] = g.threads_used;
    if (g.mig.used) {
        Json& m = summary["mig"];
        m["clauses"] = g.mig.clauses;
        m["strong_edges"] = g.mig.strong_edges;
        m["weak_edges"] = g.mig.weak_edges;
        m["jobs"] = g.mig.jobs;
        m["jobs_without_solver"] = g.mig.jobs_without_solver;
        m["possible_candidates"] = g.mig.possible_candidates;
        m["forced_by_propagation"] = g.mig.forced_by_propagation;
        m["literals_in_reach"] = g.mig.literals_in_reach;
        m["refuted_by_witness"] = g.mig.refuted_by_witness;
        m["candidates_to_solver"] = g.mig.candidates_to_solver;
        m["solver_solutions"] = g.mig.solver_solutions;
        m["graph_work"] = g.mig.graph_work;
        Json& mt = m["timings"];
        mt["build"] = g.mig.build_seconds;
        mt["setup"] = g.mig.setup_seconds;
        mt["jobs"] = g.mig.jobs_seconds;
        mt["graph_thread_seconds"] = g.mig.graph_seconds;
        mt["filter_thread_seconds"] = g.mig.filter_seconds;
        mt["solver_thread_seconds"] = g.mig.solver_seconds;
    }
    if (cls.decls_given) {
        Json& d = summary["decls"];
        d["declared_not_found"] = Json::array_of(cls.declared_not_found);
        d["declared_encoded_by_values"] = Json::array_of(cls.declared_encoded);
        d["undeclared_nonbool_options"] = Json::array_of(cls.undeclared_nonbool);
        d["dropped_only_by_decls"] = cls.dropped_only_by_decls;
    }
    if (req.uvl.present) {
        Json& u = summary["uvl"];
        u["mode"] = req.uvl.mode;
        u["features"] = req.uvl.features;
        u["skipped_constraints"] = req.uvl.skipped_constraints;
        u["typed_features"] = req.uvl.typed_features;
        u["abstract_features"] = req.uvl.abstract_features;
        u["feature_cardinalities"] = req.uvl.feature_cardinalities;
    }
    if (profile == Translator::KMax)
        summary["notes"].push("KMax represents a non-Boolean option as a single variable with the option's own name; "
                              "it is kept as an option (K6). KConfigReader uses one variable per value (R-FLT-10).");
    // Consistency checks (F8) and the cross-check of the third graph (R-OR-02)
    t0 = Clock::now();
    Json& checks = summary["checks"];
    checks = Json::object();
    std::vector<std::string> failed_checks;
    if (opt.output.or_graph) {
        std::vector<Link> implied = to_nodes(g.or_implied_arcs);
        implied.erase(std::unique(implied.begin(), implied.end()), implied.end());
        std::vector<Link> diff;
        std::set_symmetric_difference(res.requires_arcs.begin(), res.requires_arcs.end(), implied.begin(), implied.end(),
                                      std::back_inserter(diff));
        Json& x = checks["or_graph_crosscheck"];
        x["passed"] = diff.empty();
        x["mismatches"] = static_cast<long long>(diff.size());
        if (!diff.empty()) failed_checks.push_back("R-OR-02 cross-check");
    }
    // Merge check (R-CLS-01, applied after solving): every node added by --tristate merge or
    // --nonbool merge must behave as its definition says, as far as the computed statuses show
    // (and the computed graphs, when the merged variables were queried: --filter-at output).
    if (fresh > 0) {
        long violations = 0;
        std::vector<std::string> examples;
        auto bad = [&](const std::string& m) {
            ++violations;
            if (examples.size() < 10) examples.push_back(m);
        };
        auto is = [&](int v, VarStatus s) { return bb.status[v] == s; };
        const bool all_queried = opt.filter.filter_at == FilterAt::Output;
        for (const auto& p : cls.tristate_pairs) {
            const int x = p.first, xm = p.second, e = cls.vars[x].merged_into;
            if (!e || cls.vars[x].decision != Decision::Merged) continue;
            const std::string n = "'" + cls.vars[e].output_name + "'";
            // E ↔ (X ∨ X_MODULE)
            if (is(e, VarStatus::Dead) != (is(x, VarStatus::Dead) && is(xm, VarStatus::Dead)))
                bad(n + " is dead exactly when X and X_MODULE are both dead: violated");
            if ((is(x, VarStatus::Core) || is(xm, VarStatus::Core)) && !is(e, VarStatus::Core))
                bad(n + " must be core when X or X_MODULE is core");
            if (is(e, VarStatus::Core) && is(x, VarStatus::Dead) && !is(xm, VarStatus::Core))
                bad(n + " is core and X is dead, so X_MODULE must be core");
            if (is(e, VarStatus::Core) && is(xm, VarStatus::Dead) && !is(x, VarStatus::Core))
                bad(n + " is core and X_MODULE is dead, so X must be core");
            if (all_queried && is(e, VarStatus::Variable))
                for (int m : {x, xm})
                    if (is(m, VarStatus::Variable) &&
                        !std::binary_search(g.requires_arcs.begin(), g.requires_arcs.end(), Link{m, e}))
                        bad("'" + f.names[m] + "' must require the merged node " + n);
        }
        for (const auto& nb : cls.nonbool_options) {
            const int pn = nb.not_set_var, s = cls.vars[pn].merged_into;
            if (!s || cls.vars[pn].decision != Decision::Merged) continue;
            const std::string n = "'" + cls.vars[s].output_name + "'";
            // S ↔ ¬P_n
            if (is(s, VarStatus::Core) != is(pn, VarStatus::Dead)) bad(n + " is core exactly when P_n is dead: violated");
            if (is(s, VarStatus::Dead) != is(pn, VarStatus::Core)) bad(n + " is dead exactly when P_n is core: violated");
            if (all_queried && is(s, VarStatus::Variable) && is(pn, VarStatus::Variable) &&
                !std::binary_search(g.excludes_edges.begin(), g.excludes_edges.end(), Link{std::min(pn, s), std::max(pn, s)}))
                bad(n + " must exclude its P_n variable");
        }
        Json& m = checks["merge_check"];
        m["passed"] = violations == 0;
        m["merged_nodes"] = fresh;
        m["violations"] = violations;
        m["examples"] = Json::array_of(examples);
        if (violations) failed_checks.push_back("merge check (R-CLS-01)");
    }
    if (opt.output.check) {
        CheckInput ci;
        ci.names = res.node_names;
        ci.requires_arcs = res.requires_arcs;
        ci.excludes_edges = res.excludes_edges;
        ci.has_atleastone = opt.output.or_graph;
        ci.atleastone_edges = res.atleastone_edges;
        ci.fixed_nodes_dropped = opt.filter.drop_fixed_nodes;
        ci.core = res.core;
        ci.dead = res.dead;
        ci.max_matrix_memory_gb = opt.run.max_matrix_memory_gb;
        Json r = run_checks(ci);
        for (const auto& m : r.members()) checks[m.first] = m.second;
        for (const auto& c : r.find("results")->items())
            if (c.find("passed") && !c.find("passed")->as_bool()) failed_checks.push_back(c.find("id")->as_string());
    }
    if (opt.output.check || opt.output.or_graph || fresh > 0) checks["passed"] = failed_checks.empty();
    timings["checks"] = seconds_since(t0);
    if (opt.run.verbose && !quiet) {
        detail("Queried " + std::to_string(query.size()) + " variables with " + std::to_string(g.solver_calls) +
               " solver calls on " + std::to_string(g.threads_used) + " thread(s)");
        detail("Options: " + std::to_string(variable_options) + " variable, " + std::to_string(res.core.size()) + " core, " +
               std::to_string(res.dead.size()) + " dead; " + std::to_string(n_dropped) + " variables dropped, " +
               std::to_string(n_merged) + " merged");
        detail("Atomic sets: " + std::to_string(atomic_lines.size()) +
               (opt.output.minimal ? "; skeleton arcs: " + std::to_string(minimal.skeleton.size()) + "; primitive conflicts: " +
                                         std::to_string(minimal.excludes_primitive.size())
                                   : std::string()));
        if (opt.output.check) detail(std::string("Consistency checks: ") + (failed_checks.empty() ? "all passed" : "FAILED"));
        for (const auto& t : timings.members()) {
            char buf[64];
            std::snprintf(buf, sizeof buf, "%.3f s", t.second.as_real());
            detail("time " + t.first + ": " + buf);
        }
    }
    if (!failed_checks.empty()) {
        std::string list;
        for (size_t i = 0; i < failed_checks.size(); ++i) list += (i ? ", " : "") + failed_checks[i];
        warn("consistency check failed: " + list + " (details in " + base + "__summary.json, section \"checks\")");
    }

    // 10. What the graphs leave out (--representativeness): GANAK counts the configurations of the formula over the dots
    // and the choices of the same features that the graphs let pass
    std::string count_error;
    if (opt.output.representativeness) {
        t0 = Clock::now();
        Representativeness rep;
        Json& r = summary["representativeness"];
        r["counter"] = opt.run.ganak;
        const bool counted = measure_representativeness(f, res.node_var, res.core, res.dead, res.requires_arcs,
                                                        res.excludes_edges, res.atleastone_edges, base, opt.run.ganak, rep,
                                                        count_error);
        for (const auto& file : rep.files) { res.files.push_back(file); info("Saved " + file); }
        if (counted) {
            r["configurations"] = rep.configurations;
            r["graph_choices"] = rep.graph_choices;
            r["share"] = rep.share;
            r["left_out"] = 1.0 - rep.share;
            char pct[32];
            std::snprintf(pct, sizeof pct, "%.1f", 100.0 * rep.share);
            info("Representativeness: " + rep.configurations + " products among the " + rep.graph_choices +
                 " choices that the graphs let pass (" + pct + " %)");
        } else {
            r["error"] = count_error;
        }
        timings["representativeness"] = seconds_since(t0);
    }

    std::string werr = write_summary();
    if (!werr.empty()) return fail(ExitCode::Input, werr);
    info("Saved " + base + "__summary.json");

    // With the modal implication graph: where the time went
    if (g.mig.used && !quiet) {
        const double total = seconds_since(run_start);
        const double main_loop = timings.find("main_loop")->as_real();
        const double busy = g.mig.graph_seconds + g.mig.filter_seconds + g.mig.solver_seconds;
        auto line = [&](const std::string& label, double sec, const std::string& note) {
            char buf[160];
            std::snprintf(buf, sizeof buf, "  %-34s %10.3f s%s", label.c_str(), sec, note.c_str());
            vp::out() << buf << std::endl;
        };
        auto share = [](double part, double whole) {
            char buf[48];
            std::snprintf(buf, sizeof buf, "  (%.1f %%)", whole > 0 ? 100.0 * part / whole : 0.0);
            return std::string(buf);
        };
        vp::out() << "Time with the modal implication graph (MIG):" << std::endl;
        line("total run", total, "");
        line("before the main loop", timings.find("parse")->as_real() + timings.find("classify")->as_real() +
                                         timings.find("backbone")->as_real(), "  (read, classify, global backbone)");
        line("main loop", main_loop, share(main_loop, total));
        line("  create the MIG", g.mig.build_seconds, share(g.mig.build_seconds, main_loop));
        line("  create the solvers", g.mig.setup_seconds, share(g.mig.setup_seconds, main_loop));
        line("  jobs (wall time)", g.mig.jobs_seconds, share(g.mig.jobs_seconds, main_loop) + ", " +
                                                           std::to_string(g.threads_used) + " thread(s)");
        vp::out() << "    thread time of the jobs, summed over the threads:" << std::endl;
        line("    propagation and weak reach", g.mig.graph_seconds, share(g.mig.graph_seconds, busy));
        line("    candidates and witnesses", g.mig.filter_seconds, share(g.mig.filter_seconds, busy));
        line("    calling the backbone solver", g.mig.solver_seconds, share(g.mig.solver_seconds, busy));
        line("after the main loop", total - main_loop - timings.find("parse")->as_real() -
                                        timings.find("classify")->as_real() - timings.find("backbone")->as_real(),
             "  (atomic sets, products, checks, files)");
        vp::out() << "  MIG: " << g.mig.clauses << " clauses, " << g.mig.strong_edges << " strong and "
                  << g.mig.weak_edges << " weak edges" << std::endl;
        vp::out() << "  jobs: " << g.mig.jobs << ", " << g.mig.jobs_without_solver << " without the solver; "
                  << g.solver_calls << " backbone calls" << std::endl;
        vp::out() << "  literals: " << g.mig.forced_by_propagation << " forced by propagation, "
                  << g.mig.literals_in_reach << " in reach, " << g.mig.refuted_by_witness << " refuted by witnesses, "
                  << g.mig.candidates_to_solver << " sent to the solver (of " << g.mig.possible_candidates
                  << " without the MIG)" << std::endl;
    }
    if (!count_error.empty())
        return fail(ExitCode::Solver, "the graphs were written, but what they leave out could not be measured: " + count_error + ".");
    if (!failed_checks.empty() && opt.output.fail_on_check) {
        std::string list;
        for (size_t i = 0; i < failed_checks.size(); ++i) list += (i ? ", " : "") + failed_checks[i];
        return fail(ExitCode::CheckFailed, "consistency check failed for '" + req.dimacs_path + "': " + list +
                    ". The files were written; see the section \"checks\" of " + base +
                    "__summary.json. Use --no-fail-on-check to accept the output anyway.");
    }
    return res;
}

}  // namespace

} // namespace dimacs2graphs
