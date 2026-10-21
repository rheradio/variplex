/**
 * @file OutputSet.cc
 * @brief Reader of a run's output files (see OutputSet.hh)
 */

#include "OutputSet.hh"
#include "DimacsFormula.hh"

#include <cstdlib>
#include <fstream>
#include <unordered_map>

namespace dimacs2graphs {

int OutputSet::id_of(const std::string& name) const {
    for (size_t i = 0; i < names.size(); ++i)
        if (names[i] == name) return static_cast<int>(i + 1);
    return 0;
}

bool read_csv(const std::string& path, std::vector<std::vector<std::string>>& rows, std::string& error) {
    rows.clear();
    std::ifstream in(path, std::ios::binary);
    if (!in.is_open()) {
        error = "cannot open '" + path + "'. Check that the file exists and is readable.";
        return false;
    }
    std::string t;
    if (!read_text(in, path, t, error)) return false;
    std::vector<std::string> row;
    std::string field;
    bool quoted = false, any = false;
    for (size_t i = 0; i < t.size(); ++i) {
        char c = t[i];
        if (quoted) {
            if (c == '"') {
                if (i + 1 < t.size() && t[i + 1] == '"') { field += '"'; ++i; }
                else quoted = false;
            } else field += c;
            continue;
        }
        if (c == '"') { quoted = true; any = true; }
        else if (c == ',') { row.push_back(field); field.clear(); any = true; }
        else if (c == '\n' || c == '\r') {
            if (c == '\r' && i + 1 < t.size() && t[i + 1] == '\n') ++i;
            if (any || !field.empty()) { row.push_back(field); rows.push_back(row); }
            row.clear(); field.clear(); any = false;
        } else { field += c; any = true; }
    }
    if (any || !field.empty()) { row.push_back(field); rows.push_back(row); }
    return true;
}

bool read_node_names(const std::string& prefix, std::vector<std::string>& names, std::string& error) {
    std::vector<std::vector<std::string>> rows;
    const std::string p = output_path(prefix, "variables.csv");
    if (!read_csv(p, rows, error)) {
        error = "cannot read '" + p + "', which lists the vertices: " + error + " It is written by every run of Strong4VM 2.0.";
        return false;
    }
    names.clear();
    if (rows.empty() || rows[0].size() < 4 || rows[0][2] != "output_name" || rows[0][3] != "node_id") {
        error = "'" + p + "' does not have the expected header "
                "'dimacs_var,name,output_name,node_id,class,status,decision,rule'. Regenerate it with Strong4VM 2.0.";
        return false;
    }
    for (size_t r = 1; r < rows.size(); ++r) {
        if (rows[r].size() < 4 || rows[r][3].empty()) continue;
        int id = std::atoi(rows[r][3].c_str());
        if (id < 1) continue;
        if (static_cast<int>(names.size()) < id) names.resize(id);
        names[id - 1] = rows[r][2];
    }
    return true;
}

bool read_atomic_lines(const std::string& prefix, std::vector<std::vector<std::string>>& sets, std::string& error) {
    sets.clear();
    const std::string p = output_path(prefix, "atomic.txt");
    std::ifstream in(p);
    if (!in.is_open()) {
        error = "cannot open '" + p + "'. It is written by generate with --atomic on or --minimal on (both default).";
        return false;
    }
    std::string line;
    long n = 0;
    while (std::getline(in, line)) {
        ++n;
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.empty()) continue;
        std::vector<std::string> members;
        size_t start = 0;
        for (;;) {
            size_t tab = line.find('\t', start);
            std::string m = line.substr(start, tab == std::string::npos ? std::string::npos : tab - start);
            if (!tsv_marked(m)) members.push_back(tsv_unfield(m));   // a marked entry is a merged variable, not a vertex
            if (tab == std::string::npos) break;
            start = tab + 1;
        }
        sets.push_back(members);
    }
    if (in.bad()) {   // a read error ends the loop as the end of the file would
        error = read_error(p, n);
        return false;
    }
    return true;
}

bool read_output_set(const std::string& prefix, OutputSet& o, std::string& error) {
    o = OutputSet();
    o.prefix = prefix;
    const std::string rq = output_path(prefix, "requires.net"), ex = output_path(prefix, "excludes.net");
    for (const auto& p : {rq, ex}) {
        if (!path_exists(p, error)) {
            if (error.empty())
                error = "file not found: '" + p + "'. A <prefix> is the path of the output files without their suffix, e.g. out/model.";
            return false;
        }
    }
    PajekGraph r, e;
    if (!read_pajek(rq, r, error) || !read_pajek(ex, e, error)) return false;
    o.names = r.names;
    for (const auto& i : r.issues) o.issues.push_back("requires.net: " + i);
    for (const auto& i : e.issues) o.issues.push_back("excludes.net: " + i);
    if (!r.directed) o.issues.push_back("requires.net: links section is *Edges instead of *Arcs");
    o.requires_arcs = r.links;
    o.excludes_directed = e.directed;

    std::unordered_map<std::string, int> id;
    for (size_t i = 0; i < o.names.size(); ++i) id.emplace(o.names[i], static_cast<int>(i + 1));
    // Links of another graph with the same vertex list; remapped by name if the lists differ
    auto remap = [&](const PajekGraph& g, const char* file, std::vector<Link>& out) {
        if (g.names == o.names) { out = g.links; return; }
        o.issues.push_back(std::string(file) + ": vertex list differs from requires.net");
        for (const auto& l : g.links) {
            auto a = id.find(g.names[l.first - 1]), b = id.find(g.names[l.second - 1]);
            if (a != id.end() && b != id.end()) out.push_back({a->second, b->second});
        }
    };
    remap(e, "excludes.net", o.excludes_edges);

    // The other files are optional: one that does not exist is skipped, one that cannot be examined is an error
    const std::string al = output_path(prefix, "atleastone.net");
    if (path_exists(al, error)) {
        PajekGraph a;
        if (!read_pajek(al, a, error)) return false;
        for (const auto& i : a.issues) o.issues.push_back("atleastone.net: " + i);
        o.has_atleastone = true;
        remap(a, "atleastone.net", o.atleastone_edges);
    } else if (!error.empty()) {
        return false;
    }
    for (auto* list : {&o.core, &o.dead}) {
        const std::string p = output_path(prefix, list == &o.core ? "core.txt" : "dead.txt");
        if (!path_exists(p, error)) {
            if (!error.empty()) return false;
            continue;
        }
        if (!read_node_list(p, *list, error)) return false;
        for (auto& n : *list) {
            auto it = id.find(n.name);
            n.id = it == id.end() ? 0 : it->second;
        }
    }
    const std::string sp = output_path(prefix, "summary.json");
    if (path_exists(sp, error)) {
        std::ifstream in(sp, std::ios::binary);
        std::string text, jerr;
        if (!read_text(in, sp, text, error)) return false;
        if (Json::parse(text, o.summary, jerr)) o.has_summary = true;
        else o.issues.push_back("summary.json cannot be read (" + jerr + "): the file is damaged, regenerate the output files");
    } else if (!error.empty()) {
        return false;
    }
    return true;
}

} // namespace dimacs2graphs
