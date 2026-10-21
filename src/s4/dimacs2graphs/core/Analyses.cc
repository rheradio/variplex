/**
 * @file Analyses.cc
 * @brief check, expand, explain and diff on existing output files (see Analyses.hh)
 */

#include "Analyses.hh"
#include "Pipeline.hh"
#include "Version.hh"
#include "../graphs/Atomic.hh"
#include "../graphs/Checks.hh"
#include "../graphs/Minimal.hh"
#include "../io/DimacsFormula.hh"
#include "../io/OutputSet.hh"

#include <algorithm>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <functional>
#include <queue>
#include <set>
#include <unordered_map>

namespace dimacs2graphs {

namespace {

Json fail(AnalysisStatus& st, ExitCode c, const std::string& m) {
    st.code = c;
    st.error = m;
    return Json();
}

}  // namespace

// ---------------------------------------------------------------------------
// check (F8)
// ---------------------------------------------------------------------------

Json check_outputs(const std::string& prefix, double max_gb, AnalysisStatus& st) {
    OutputSet o;
    std::string err;
    if (!read_output_set(prefix, o, err)) return fail(st, ExitCode::Input, err);
    CheckInput ci;
    ci.names = o.names;
    ci.requires_arcs = o.requires_arcs;
    ci.excludes_edges = o.excludes_edges;
    ci.excludes_directed = o.excludes_directed;
    ci.has_atleastone = o.has_atleastone;
    ci.atleastone_edges = o.atleastone_edges;
    ci.core = o.core;
    ci.dead = o.dead;
    ci.max_matrix_memory_gb = max_gb;
    if (o.has_summary) {
        const Json* opts = o.summary.find("options");
        const Json* fixed = opts ? opts->find("fixed_nodes") : nullptr;
        ci.fixed_nodes_dropped = fixed && fixed->as_string() == "drop";
    }
    Json r = run_checks(ci);

    Json out = Json::object();
    out["prefix"] = prefix;
    out["vertices"] = static_cast<long long>(o.names.size());
    out["arcs"] = static_cast<long long>(o.requires_arcs.size());
    out["edges"] = static_cast<long long>(o.excludes_edges.size());
    if (o.has_atleastone) out["atleastone_edges"] = static_cast<long long>(o.atleastone_edges.size());
    out["passed"] = r.find("passed")->as_bool() && o.issues.empty();
    out["method"] = *r.find("method");
    Json list = Json::array();
    for (const auto& c : r.find("results")->items()) {
        Json c2 = c;
        if (!o.issues.empty() && c.find("id")->as_string() == "R-CHK-07") {
            // Format issues found while reading are R-CHK-07 violations
            c2["passed"] = false;
            c2["violations"] = c.find("violations")->as_int() + static_cast<long long>(o.issues.size());
            Json ex = Json::array_of(o.issues);
            for (const auto& e : c.find("examples")->items()) ex.push(e);
            c2["examples"] = ex;
        }
        list.push(c2);
    }
    out["results"] = list;
    return out;
}

// ---------------------------------------------------------------------------
// expand (R-MIN-05)
// ---------------------------------------------------------------------------

Json expand_outputs(const std::string& prefix, const std::string& output_dir, AnalysisStatus& st) {
    std::string err;
    std::vector<std::string> names;
    if (!read_node_names(prefix, names, err)) return fail(st, ExitCode::Input, err);
    const int n = static_cast<int>(names.size());
    std::unordered_map<std::string, int> id;
    for (int i = 0; i < n; ++i) id[names[i]] = i;

    std::vector<std::vector<std::string>> lines;
    AtomicSets a;
    if (!read_atomic_lines(prefix, lines, err) || !atomic_sets_from_lists(names, lines, a, err))
        return fail(st, ExitCode::Input, err);

    // Minimal form files: vertices are representatives, mapped to components by name
    auto read_minimal = [&](const std::string& suffix, bool required, std::vector<Link>& links, bool& present) {
        const std::string p = output_path(prefix, suffix);
        present = path_exists(p, err);
        if (!present) {
            if (!err.empty()) return false;   // the file cannot be examined
            if (required) err = "file not found: '" + p + "' (run generate with --minimal on).";
            return !required;
        }
        PajekGraph g;
        if (!read_pajek(p, g, err)) return false;
        std::vector<int> comp_of(g.names.size());
        for (size_t i = 0; i < g.names.size(); ++i) {
            auto it = id.find(g.names[i]);
            if (it == id.end()) {
                err = "'" + g.names[i] + "' in " + p + " is not a vertex of " + prefix +
                      ". The files of this prefix do not belong to the same run: regenerate them.";
                return false;
            }
            comp_of[i] = a.comp[it->second];
        }
        for (const auto& l : g.links) links.push_back({comp_of[l.first - 1] + 1, comp_of[l.second - 1] + 1});
        return true;
    };
    std::vector<Link> skeleton, pc, pa;
    bool has_sk, has_pc, has_pa;
    if (!read_minimal("requires_skeleton.net", true, skeleton, has_sk) ||
        !read_minimal("excludes_primitive.net", true, pc, has_pc) ||
        !read_minimal("atleastone_primitive.net", false, pa, has_pa))
        return fail(st, ExitCode::Input, err);

    ExpandedGraphs e = expand_minimal(n, a, skeleton, pc, has_pa ? &pa : nullptr);

    std::string dir = output_dir.empty() ? path_dir(prefix) : output_dir;
    try {
        std::filesystem::create_directories(dir);
    } catch (const std::exception& ex) {
        return fail(st, ExitCode::Input, "could not create output directory '" + dir + "': " + ex.what() +
                    ". Choose a writable directory with -o.");
    }
    const std::string base = dir + "/" + std::filesystem::path(prefix).filename().string();
    Json out = Json::object();
    Json files = Json::array();
    auto write = [&](const char* suffix, const std::vector<Link>& links, bool directed) {
        std::string p = base + "__" + suffix;
        if (!write_pajek(p, names, links, directed, err)) return false;
        files.push(p);
        return true;
    };
    if (!write("requires.net", e.requires_arcs, true) || !write("excludes.net", e.excludes_edges, false) ||
        (has_pa && !write("atleastone.net", e.atleastone_edges, false)))
        return fail(st, ExitCode::Input, err);
    out["vertices"] = n;
    out["arcs"] = static_cast<long long>(e.requires_arcs.size());
    out["edges"] = static_cast<long long>(e.excludes_edges.size());
    if (has_pa) out["atleastone_edges"] = static_cast<long long>(e.atleastone_edges.size());
    out["files"] = files;
    return out;
}

// ---------------------------------------------------------------------------
// explain (F9)
// ---------------------------------------------------------------------------

namespace {

/// Shortest path from s to t in g (0-based), or empty if none. Ties: smallest ids first.
std::vector<int> bfs_path(const Csr& g, int s, int t) {
    if (s == t) return {s};
    std::vector<int> parent(g.n, -1);
    std::queue<int> q;
    q.push(s);
    parent[s] = s;
    while (!q.empty()) {
        int u = q.front();
        q.pop();
        for (const int* v = g.begin(u); v != g.end(u); ++v) {
            if (parent[*v] >= 0) continue;
            parent[*v] = u;
            if (*v == t) {
                std::vector<int> path{t};
                for (int x = t; x != s; x = parent[x]) path.push_back(parent[x]);
                std::reverse(path.begin(), path.end());
                return path;
            }
            q.push(*v);
        }
    }
    return {};
}

}  // namespace

Json explain_relation(const std::string& prefix, ExplainKind kind, const std::string& A, const std::string& B,
                      AnalysisStatus& st) {
    OutputSet o;
    std::string err;
    if (!read_output_set(prefix, o, err)) return fail(st, ExitCode::Input, err);
    const int n = static_cast<int>(o.names.size());
    int ia = o.id_of(A), ib = o.id_of(B);
    for (const auto& p : {std::make_pair(ia, A), std::make_pair(ib, B)}) {
        if (p.first) continue;
        std::string why;
        for (const auto& c : o.core) if (c.name == p.second) why = " It is a core option (always selected).";
        for (const auto& d : o.dead) if (d.name == p.second) why = " It is a dead option (never selected).";
        return fail(st, ExitCode::Input, "'" + p.second + "' is not a vertex of " + prefix + "." + why +
                    " The vertex names are listed in " + output_path(prefix, "requires.net") + ".");
    }
    --ia;
    --ib;

    // Atomic sets and minimal form, recomputed with the algorithms of generate
    AtomicSets at = strongly_connected_components(Csr::from_links(n, o.requires_arcs, false));
    MinimalForm mf = compute_minimal(n, at, o.requires_arcs, o.excludes_edges,
                                     o.has_atleastone ? &o.atleastone_edges : nullptr, 2.0);
    const int k = at.count();
    const Csr skel = Csr::from_links(k, mf.skeleton, false);
    auto rep = [&](int c) { return o.names[at.representative(c)]; };
    auto chain_names = [&](int start_node, const std::vector<int>& path) {
        std::vector<std::string> names{o.names[start_node]};
        for (size_t i = 0; i < path.size(); ++i) {
            const std::string r = rep(path[i]);
            if (i == 0) {
                if (r != o.names[start_node]) names.back() += " (≡ " + r + ")";
                continue;
            }
            names.push_back(r);
        }
        return names;
    };

    Json out = Json::object();
    out["kind"] = kind == ExplainKind::Conflict ? "conflict" : "requires";
    out["a"] = A;
    out["b"] = B;
    const int ca = at.comp[ia], cb = at.comp[ib];

    if (kind == ExplainKind::Conflict) {
        const Csr cg = Csr::from_links(n, o.excludes_edges, true);
        const bool holds = cg.has(ia, ib);
        out["holds"] = holds;
        if (!holds) return out;
        const Csr pc = Csr::from_links(k, mf.excludes_primitive, true);
        out["primitive"] = pc.has(ca, cb);
        // up(c) = {c} ∪ what c requires (reachability on the skeleton)
        auto up = [&](int c) {
            std::vector<int> u{c};
            std::vector<char> seen(k, 0);
            seen[c] = 1;
            for (size_t i = 0; i < u.size(); ++i)
                for (const int* v = skel.begin(u[i]); v != skel.end(u[i]); ++v)
                    if (!seen[*v]) { seen[*v] = 1; u.push_back(*v); }
            std::sort(u.begin(), u.end());
            return u;
        };
        std::vector<int> ua = up(ca), ub = up(cb);
        std::vector<std::pair<int, int>> origins;
        for (int x : ua)
            for (const int* y = pc.begin(x); y != pc.end(x); ++y)
                if (std::binary_search(ub.begin(), ub.end(), *y)) origins.push_back({x, *y});
        std::sort(origins.begin(), origins.end());
        Json list = Json::array();
        for (const auto& og : origins) {
            Json j = Json::object();
            j["conflict"] = Json::array_of(std::vector<std::string>{rep(og.first), rep(og.second)});
            j["chain_a"] = Json::array_of(chain_names(ia, bfs_path(skel, ca, og.first)));
            j["chain_b"] = Json::array_of(chain_names(ib, bfs_path(skel, cb, og.second)));
            list.push(j);
        }
        out["origins"] = list;
        return out;
    }

    const Csr full = Csr::from_links(n, o.requires_arcs, false);
    const bool same = ca == cb;
    const bool holds = same || full.has(ia, ib);
    out["holds"] = holds;
    if (!holds) return out;
    out["same_atomic_set"] = same;
    if (!same) {
        out["in_skeleton"] = skel.has(ca, cb);
        out["chain"] = Json::array_of(chain_names(ia, bfs_path(skel, ca, cb)));
    }
    if (o.has_atleastone) {
        // x with A # x and x ∨ B (R-EXP-02)
        const Csr cg = Csr::from_links(n, o.excludes_edges, true);
        const Csr ag = Csr::from_links(n, o.atleastone_edges, true);
        std::vector<std::string> xs;
        for (const int* x = cg.begin(ia); x != cg.end(ia); ++x)
            if (ag.has(*x, ib)) xs.push_back(o.names[*x]);
        out["via_atleastone"] = Json::array_of(xs);
    }
    return out;
}

// ---------------------------------------------------------------------------
// diff (F10); the file of --rename is read by read_renames() of the API
// ---------------------------------------------------------------------------

namespace {

using NamePair = std::pair<std::string, std::string>;

std::set<NamePair> named_links(const OutputSet& o, const std::vector<Link>& links, bool undirected,
                               const std::function<std::string(const std::string&)>& map_name,
                               const std::set<std::string>& kept) {
    std::set<NamePair> out;
    for (const auto& l : links) {
        std::string a = map_name(o.names[l.first - 1]), b = map_name(o.names[l.second - 1]);
        if (!kept.count(a) || !kept.count(b)) continue;
        if (undirected && b < a) std::swap(a, b);
        out.insert({a, b});
    }
    return out;
}

/// Average ranks (1-based) with ties.
std::vector<double> ranks(const std::vector<double>& x) {
    std::vector<size_t> idx(x.size());
    for (size_t i = 0; i < idx.size(); ++i) idx[i] = i;
    std::sort(idx.begin(), idx.end(), [&](size_t a, size_t b) { return x[a] < x[b]; });
    std::vector<double> r(x.size());
    for (size_t i = 0; i < idx.size();) {
        size_t j = i;
        while (j + 1 < idx.size() && x[idx[j + 1]] == x[idx[i]]) ++j;
        double avg = (i + j) / 2.0 + 1.0;
        for (size_t q = i; q <= j; ++q) r[idx[q]] = avg;
        i = j + 1;
    }
    return r;
}

double pearson(const std::vector<double>& a, const std::vector<double>& b) {
    const size_t n = a.size();
    if (n < 2) return NAN;
    double ma = 0, mb = 0;
    for (size_t i = 0; i < n; ++i) { ma += a[i]; mb += b[i]; }
    ma /= n;
    mb /= n;
    double sab = 0, saa = 0, sbb = 0;
    for (size_t i = 0; i < n; ++i) {
        sab += (a[i] - ma) * (b[i] - mb);
        saa += (a[i] - ma) * (a[i] - ma);
        sbb += (b[i] - mb) * (b[i] - mb);
    }
    if (saa == 0 || sbb == 0) return NAN;
    return sab / std::sqrt(saa * sbb);
}

}  // namespace

Json diff_outputs(const std::string& old_prefix, const std::string& new_prefix,
                  const std::map<std::string, std::string>& renames, const std::string& output_dir,
                  AnalysisStatus& st) {
    struct Version {
        OutputSet o;
        std::map<std::string, std::string> state;  // option → variable | core | dead
    } v[2];
    std::string err;
    const std::string prefixes[2] = {old_prefix, new_prefix};
    for (int i = 0; i < 2; ++i) {
        if (!read_output_set(prefixes[i], v[i].o, err)) return fail(st, ExitCode::Input, err);
        for (const auto& n : v[i].o.names) v[i].state[n] = "variable";
        for (const auto& c : v[i].o.core) v[i].state[c.name] = "core";
        for (const auto& d : v[i].o.dead) v[i].state[d.name] = "dead";
    }
    auto old_to_new = [&](const std::string& n) {
        auto it = renames.find(n);
        return it == renames.end() ? n : it->second;
    };
    auto same = [](const std::string& n) { return n; };

    // Options compared are the vertices of the graphs (R-TST-20 counts vertices);
    // states (variable/core/dead) cover every option listed by either version.
    std::map<std::string, std::string> old_state;  // in new names
    for (const auto& s : v[0].state) old_state[old_to_new(s.first)] = s.second;
    std::set<std::string> old_vertices, new_vertices(v[1].o.names.begin(), v[1].o.names.end());
    for (const auto& n : v[0].o.names) old_vertices.insert(old_to_new(n));
    std::set<std::string> kept, added, removed;
    for (const auto& n : new_vertices) (old_vertices.count(n) ? kept : added).insert(n);
    for (const auto& n : old_vertices)
        if (!new_vertices.count(n)) removed.insert(n);

    const std::string dir = output_dir.empty() ? "." : output_dir;
    try {
        std::filesystem::create_directories(dir);
    } catch (const std::exception& ex) {
        return fail(st, ExitCode::Input, "could not create output directory '" + dir + "': " + ex.what() +
                    ". Choose a writable directory with -o.");
    }
    const std::string base = dir + "/" + std::filesystem::path(old_prefix).filename().string() + "__to__" +
                             std::filesystem::path(new_prefix).filename().string();
    Json summary = Json::object();
    summary["strong4vm_version"] = STRONG4VM_VERSION;
    summary["old"] = old_prefix;
    summary["new"] = new_prefix;
    summary["renames"] = static_cast<long long>(renames.size());
    // renames that changed nothing: the old name is not a feature of the old version (a typo, or a rename meant for
    // another pair of versions); the command line warns about each
    Json unused = Json::array();
    for (const auto& r : renames)
        if (!v[0].state.count(r.first)) unused.push(r.first);
    summary["renames_unused"] = unused;
    summary["options"]["kept"] = static_cast<long long>(kept.size());
    summary["options"]["added"] = static_cast<long long>(added.size());
    summary["options"]["removed"] = static_cast<long long>(removed.size());

    {
        AtomicFile f(base + "__diff_states.csv");
        f.out() << "name,old_state,new_state\n";
        std::map<std::string, long> moves;
        for (const auto& s : v[1].state) {
            auto it = old_state.find(s.first);
            if (it == old_state.end()) {
                f.out() << csv_field(s.first) << ",," << s.second << '\n';
                continue;
            }
            if (it->second == s.second) continue;
            ++moves[it->second + "->" + s.second];
            f.out() << csv_field(s.first) << ',' << it->second << ',' << s.second << '\n';
        }
        for (const auto& s : old_state)
            if (!v[1].state.count(s.first)) f.out() << csv_field(s.first) << ',' << s.second << ",\n";
        if (!f.commit(err)) return fail(st, ExitCode::Input, err);
        Json& jm = summary["state_moves"];
        jm = Json::object();
        for (const auto& m : moves) jm[m.first] = m.second;
    }

    struct G { const char* name; bool undirected; };
    for (const G& g : {G{"requires", false}, G{"excludes", true}, G{"atleastone", true}}) {
        const std::string gname = g.name;
        if (gname == "atleastone" && !(v[0].o.has_atleastone && v[1].o.has_atleastone)) continue;
        auto links_of = [&](int i) -> const std::vector<Link>& {
            return gname == "requires" ? v[i].o.requires_arcs : gname == "excludes" ? v[i].o.excludes_edges
                                                                                    : v[i].o.atleastone_edges;
        };
        std::set<NamePair> a = named_links(v[0].o, links_of(0), g.undirected, old_to_new, kept);
        std::set<NamePair> b = named_links(v[1].o, links_of(1), g.undirected, same, kept);
        std::vector<NamePair> gained, lost, common;
        std::set_difference(b.begin(), b.end(), a.begin(), a.end(), std::back_inserter(gained));
        std::set_difference(a.begin(), a.end(), b.begin(), b.end(), std::back_inserter(lost));
        std::set_intersection(a.begin(), a.end(), b.begin(), b.end(), std::back_inserter(common));
        AtomicFile f(base + "__diff_" + gname + ".csv");
        f.out() << (g.undirected ? "a,b,change\n" : "source,target,change\n");
        for (const auto& l : gained) f.out() << csv_field(l.first) << ',' << csv_field(l.second) << ",gained\n";
        for (const auto& l : lost) f.out() << csv_field(l.first) << ',' << csv_field(l.second) << ",lost\n";
        if (!f.commit(err)) return fail(st, ExitCode::Input, err);
        Json& j = summary["graphs"][gname];
        j["old_links"] = static_cast<long long>(a.size());
        j["new_links"] = static_cast<long long>(b.size());
        j["gained"] = static_cast<long long>(gained.size());
        j["lost"] = static_cast<long long>(lost.size());
        const size_t uni = a.size() + b.size() - common.size();
        j["jaccard"] = uni ? double(common.size()) / double(uni) : 1.0;
    }

    // Spearman correlation of the in-degree (requires) of kept options
    {
        std::unordered_map<std::string, double> indeg[2];
        for (int i = 0; i < 2; ++i) {
            for (const auto& nm : v[i].o.names) indeg[i][i == 0 ? old_to_new(nm) : nm] = 0;
            for (const auto& l : v[i].o.requires_arcs) {
                const std::string& t = v[i].o.names[l.second - 1];
                indeg[i][i == 0 ? old_to_new(t) : t] += 1;
            }
        }
        std::vector<double> x, y;
        for (const auto& nm : kept) {
            x.push_back(indeg[0][nm]);
            y.push_back(indeg[1][nm]);
        }
        double rho = pearson(ranks(x), ranks(y));
        summary["in_degree_spearman"] = std::isnan(rho) ? Json() : Json(rho);
    }

    AtomicFile sf(base + "__diff_summary.json");
    summary.dump(sf.out());
    if (!sf.commit(err)) return fail(st, ExitCode::Input, err);
    summary["report"] = base + "__diff_summary.json";
    return summary;
}

} // namespace dimacs2graphs
