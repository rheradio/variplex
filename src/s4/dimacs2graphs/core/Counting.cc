/**
 * @file Counting.cc
 * @brief How much of the formula the graphs leave out, measured with GANAK (see Counting.hh)
 */

#include "Counting.hh"

#include <cmath>
#include <cstdio>
#include <string>

namespace dimacs2graphs {

namespace {

std::string shell_quote(const std::string& s) {
#ifdef _WIN32
    return "\"" + s + "\"";
#endif
    std::string q = "'";
    for (char c : s) q += (c == '\'') ? std::string("'\\''") : std::string(1, c);
    return q + "'";
}

/// Runs the counter on `file`; the count it prints, or "" with `error`.
std::string run_counter(const std::string& counter, const std::string& file, std::string& error) {
    const std::string command = shell_quote(counter) + " " + shell_quote(file) + " 2>&1";
    #ifdef _WIN32
    FILE* p = _popen(command.c_str(), "r");
#else
    FILE* p = popen(command.c_str(), "r");
#endif
    if (!p) {
        error = "could not start the model counter '" + counter + "'";
        return "";
    }
    std::string out;
    char buf[4096];
    size_t n;
    while ((n = std::fread(buf, 1, sizeof buf, p)) > 0) out.append(buf, n);
    #ifdef _WIN32
    const int status = _pclose(p);
#else
    const int status = pclose(p);
#endif
    std::string count;
    size_t pos = 0;
    while (pos < out.size()) {
        size_t end = out.find('\n', pos);
        if (end == std::string::npos) end = out.size();
        const std::string line = out.substr(pos, end - pos);
        const std::string key = "c s exact arb int ";
        if (line.compare(0, key.size(), key) == 0) count = line.substr(key.size());
        if (line == "s UNSATISFIABLE") count = "0";
        pos = end + 1;
    }
    while (!count.empty() && (count.back() == ' ' || count.back() == '\r')) count.pop_back();
    if (count.empty() || count.find_first_not_of("0123456789") != std::string::npos) {
        std::string tail = out.size() > 400 ? out.substr(out.size() - 400) : out;
        if (status != 0 && out.find("not found") != std::string::npos)
            error = "the model counter '" + counter + "' was not found. Install GANAK (release programs for Linux, macOS and "
                    "Windows at https://github.com/meelgroup/ganak/releases) and put it on the PATH, or give it with --ganak PATH";
        else
            error = "the model counter '" + counter + "' gave no count for '" + file + "'. It printed: " + tail;
        return "";
    }
    return count;
}

double log10_of(const std::string& digits) {
    size_t i = digits.find_first_not_of('0');
    if (i == std::string::npos) return -INFINITY;
    const std::string d = digits.substr(i);
    const size_t k = std::min<size_t>(d.size(), 17);
    return std::log10(std::stod(d.substr(0, k))) + static_cast<double>(d.size() - k);
}

}  // namespace

double decimal_ratio(const std::string& numerator, const std::string& denominator) {
    const double a = log10_of(numerator), b = log10_of(denominator);
    if (std::isinf(a)) return 0;
    if (std::isinf(b)) return INFINITY;
    return std::pow(10.0, a - b);
}

bool measure_representativeness(const DimacsFormula& f, const std::vector<int>& node_var, const std::vector<ListedNode>& core,
                                const std::vector<ListedNode>& dead, const std::vector<Link>& arcs,
                                const std::vector<Link>& excludes, const std::vector<Link>& atleastone,
                                const std::string& base, const std::string& counter, Representativeness& r, std::string& error) {
    const int n = static_cast<int>(node_var.size());
    // The results as a formula over the dots 1..n. Core and dead features are clauses of one literal when they are dots
    // (--fixed-nodes keep); otherwise they are fixed in the formula and are not counted on either side.
    {
        const std::string path = base + "__count_graphs.cnf";
        long clauses = static_cast<long>(arcs.size() + excludes.size() + atleastone.size());
        for (const auto& c : core) clauses += c.id ? 1 : 0;
        for (const auto& d : dead) clauses += d.id ? 1 : 0;
        AtomicFile out(path);
        out.out() << "c the results of Strong4VM as a formula: one variable per dot of the graphs, one clause per link\n";
        out.out() << "p cnf " << n << ' ' << clauses << '\n';
        for (const auto& c : core) if (c.id) out.out() << c.id << " 0\n";
        for (const auto& d : dead) if (d.id) out.out() << -d.id << " 0\n";
        for (const auto& l : arcs) out.out() << -l.first << ' ' << l.second << " 0\n";
        for (const auto& l : excludes) out.out() << -l.first << ' ' << -l.second << " 0\n";
        for (const auto& l : atleastone) out.out() << l.first << ' ' << l.second << " 0\n";
        if (!out.commit(error)) return false;
        r.files.push_back(path);
    }
    // The formula, counted over the variables of the dots. A dot without a variable (a declared name that the formula
    // does not have, --decls-unconstrained add) gets a fresh, unconstrained one, as it is free in the graphs.
    {
        const std::string path = base + "__count_formula.cnf";
        int vars = f.num_vars;
        std::string show = "c p show";
        for (int v : node_var) show += " " + std::to_string(v ? v : ++vars);
        AtomicFile out(path);
        out.out() << show << " 0\n";
        out.out() << "p cnf " << vars << ' ' << f.clauses.size() << '\n';
        for (const auto& c : f.clauses) {
            for (int lit : c) out.out() << lit << ' ';
            out.out() << "0\n";
        }
        if (!out.commit(error)) return false;
        r.files.push_back(path);
    }
    r.configurations = run_counter(counter, base + "__count_formula.cnf", error);
    if (r.configurations.empty()) return false;
    r.graph_choices = run_counter(counter, base + "__count_graphs.cnf", error);
    if (r.graph_choices.empty()) return false;
    r.share = decimal_ratio(r.configurations, r.graph_choices);
    if (!(r.share >= 0 && r.share <= 1.0000001)) {
        error = "the model counter gave " + r.configurations + " configurations and " + r.graph_choices +
                " choices that the graphs let pass; there cannot be more configurations than such choices";
        return false;
    }
    return true;
}

} // namespace dimacs2graphs
