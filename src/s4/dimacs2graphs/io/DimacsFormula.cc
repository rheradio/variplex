/**
 * @file DimacsFormula.cc
 * @brief DIMACS reader with full name-table support (see DimacsFormula.hh)
 */

#include "DimacsFormula.hh"

#include <new>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <system_error>
#include <unordered_map>

namespace dimacs2graphs {

namespace {

const char* const LEGACY_AUX_SUFFIX = " (auxiliary)";

std::string trim(const std::string& s) {
    size_t b = 0, e = s.size();
    while (b < e && std::isspace(static_cast<unsigned char>(s[b]))) ++b;
    while (e > b && std::isspace(static_cast<unsigned char>(s[e - 1]))) --e;
    return s.substr(b, e - b);
}

bool starts_with(const std::string& s, const std::string& p) {
    return s.size() >= p.size() && s.compare(0, p.size(), p) == 0;
}

bool ends_with(const std::string& s, const std::string& p) {
    return s.size() >= p.size() && s.compare(s.size() - p.size(), p.size(), p) == 0;
}

/// Parses a non-negative integer at s[pos..]; requires whitespace or end after it.
bool parse_uint(const std::string& s, size_t& pos, long& value) {
    size_t p = pos;
    if (p >= s.size() || !std::isdigit(static_cast<unsigned char>(s[p]))) return false;
    long v = 0;
    while (p < s.size() && std::isdigit(static_cast<unsigned char>(s[p]))) {
        v = v * 10 + (s[p] - '0');
        if (v > 2000000000L) return false;
        ++p;
    }
    if (p < s.size() && !std::isspace(static_cast<unsigned char>(s[p]))) return false;
    pos = p;
    value = v;
    return true;
}

/// `^aux_[0-9]+(_.*)?$`
bool is_legacy_aux_name(const std::string& n) {
    if (!starts_with(n, "aux_")) return false;
    size_t i = 4;
    if (i >= n.size() || !std::isdigit(static_cast<unsigned char>(n[i]))) return false;
    while (i < n.size() && std::isdigit(static_cast<unsigned char>(n[i]))) ++i;
    return i == n.size() || n[i] == '_';
}

} // namespace

void DimacsFormula::resize(int n) {
    num_vars = n;
    names.resize(n + 1);
    aux.resize(n + 1, AuxKind::None);
    is_root.resize(n + 1, 0);
    is_abstract.resize(n + 1, 0);
}

int DimacsFormula::add_variable(const std::string& name) {
    resize(num_vars + 1);
    names[num_vars] = name;
    return num_vars;
}

std::string path_stem(const std::string& path) {
    size_t slash = path.find_last_of("/\\");
    std::string file = (slash == std::string::npos) ? path : path.substr(slash + 1);
    size_t dot = file.find_last_of('.');
    if (dot != std::string::npos && dot > 0) file = file.substr(0, dot);
    return file;
}

std::string path_dir(const std::string& path) {
    size_t slash = path.find_last_of("/\\");
    if (slash == std::string::npos) return ".";
    if (slash == 0) return "/";
    return path.substr(0, slash);
}

bool path_exists(const std::string& path, std::string& error) {
    error.clear();
    std::error_code ec;
    const bool found = std::filesystem::exists(path, ec);
    if (ec) {
        error = "cannot access '" + path + "': " + ec.message() +
                ". Check the path, and that the directories on it exist and may be read.";
        return false;
    }
    return found;
}

std::string read_error(const std::string& path, long lines_read) {
    return "error while reading '" + path + "'" + (lines_read > 0 ? " after line " + std::to_string(lines_read) : std::string()) +
           ": the file could not be read to its end (an error of the system, or not enough memory). Check the disk or the "
           "network share that holds it, and run again.";
}

bool read_text(std::istream& in, const std::string& path, std::string& text, std::string& error) {
    text.clear();
    char buffer[65536];
    while (in.read(buffer, sizeof buffer) || in.gcount() > 0) text.append(buffer, static_cast<size_t>(in.gcount()));
    if (in.bad()) {
        error = read_error(path, 0);
        return false;
    }
    return true;
}

bool read_dimacs(const std::string& path, DimacsFormula& f, std::string& error) {
    f = DimacsFormula();
    f.path = path;

    std::ifstream in(path, std::ios::binary);
    if (!in.is_open()) {
        error = "cannot open input file '" + path + "'. Check that the path is correct and readable.";
        return false;
    }

    struct Named { long var; std::string name; long line; };
    std::vector<Named> named;
    std::vector<std::pair<long, AuxKind>> aux_marks;
    std::vector<long> roots, abstracts;
    bool seen_p = false;
    long max_var = 0;
    std::vector<int> current;

    std::string line;
    long line_no = 0;
    while (std::getline(in, line)) {
        ++line_no;
        if (!line.empty() && line.back() == '\r') line.pop_back();
        size_t pos = 0;
        while (pos < line.size() && std::isspace(static_cast<unsigned char>(line[pos]))) ++pos;
        if (pos >= line.size()) continue;
        const char c0 = line[pos];

        if (c0 == 'c') {
            std::string rest = line.substr(pos + 1);
            if (!rest.empty() && !std::isspace(static_cast<unsigned char>(rest[0]))) continue;  // e.g. "cnf"
            std::string body = trim(rest);
            if (body.empty()) continue;

            if (starts_with(body, "generated-by uvl2dimacs")) {
                f.uvl_header = true;
                std::string tail = trim(body.substr(23));
                size_t sp = tail.find(' ');
                f.uvl_version = tail.substr(0, sp);
                size_t m = tail.find("mode=");
                if (m != std::string::npos) {
                    std::string mode = tail.substr(m + 5);
                    f.uvl_mode = mode.substr(0, mode.find(' '));
                }
                continue;
            }
            if (starts_with(body, "Generated by UVL2Dimacs")) { f.legacy_uvl_header = true; continue; }

            // Reserved keyword lines: "aux <n> <kind>", "root <n>", "abstract <n>"
            for (const char* kw : {"aux ", "root ", "abstract "}) {
                std::string k(kw);
                if (!starts_with(body, k)) continue;
                size_t p = k.size();
                while (p < body.size() && body[p] == ' ') ++p;
                long v;
                if (!parse_uint(body, p, v) || v == 0) break;  // not a reserved line: fall through
                if (k == "aux ") {
                    std::string kind = trim(body.substr(p));
                    aux_marks.push_back({v, kind == "chain" ? AuxKind::Chain : AuxKind::Tseitin});
                } else if (k == "root ") {
                    roots.push_back(v);
                } else {
                    abstracts.push_back(v);
                }
                if (v > max_var) max_var = v;
                body.clear();
                break;
            }
            if (body.empty()) continue;

            // "c <n> <name…>"
            size_t p = 0;
            long v;
            if (!parse_uint(body, p, v) || v == 0) continue;  // free-text comment
            std::string name = trim(body.substr(p));
            if (name.empty()) continue;
            named.push_back({v, name, line_no});
            if (v > max_var) max_var = v;
            continue;
        }

        if (c0 == 'p') {
            if (seen_p) {
                error = path + ":" + std::to_string(line_no) + ": second problem line. A DIMACS file must have exactly one 'p cnf' line.";
                return false;
            }
            seen_p = true;
            char p;
            long nv = -1, nc = -1;
            std::string s = line.substr(pos);
            const char* cs = s.c_str();
            char fmt[16];
            if (std::sscanf(cs, "%c %15s %ld %ld", &p, fmt, &nv, &nc) != 4 || std::string(fmt) != "cnf" || nv < 0 || nc < 0) {
                error = path + ":" + std::to_string(line_no) + ": malformed problem line '" + line + "'. Expected 'p cnf <variables> <clauses>'.";
                return false;
            }
            if (nv > 2000000000L || nc > 2000000000L) {
                error = path + ":" + std::to_string(line_no) + ": the problem line '" + line + "' declares more than "
                        "2,000,000,000 variables or clauses, which is beyond what Strong4VM can handle. Check the line: "
                        "it must be 'p cnf <variables> <clauses>' with the real numbers of the formula.";
                return false;
            }
            f.declared_vars = static_cast<int>(nv);
            f.declared_clauses = static_cast<int>(nc);
            if (nv > max_var) max_var = nv;
            continue;
        }

        if (c0 == '%') break;  // SATLIB end marker

        // Clause literals (a clause may span several lines; it ends with 0)
        const char* s = line.c_str() + pos;
        while (*s) {
            while (*s && std::isspace(static_cast<unsigned char>(*s))) ++s;
            if (!*s) break;
            char* end;
            long lit = std::strtol(s, &end, 10);
            if (end == s || (*end && !std::isspace(static_cast<unsigned char>(*end)))) {
                error = path + ":" + std::to_string(line_no) + ": unexpected text '" + std::string(s).substr(0, 20) +
                        "' where a literal was expected. Check that the file is in DIMACS CNF format.";
                return false;
            }
            s = end;
            if (lit == 0) {
                f.clauses.push_back(current);
                current.clear();
            } else {
                long a = lit < 0 ? -lit : lit;
                if (a > 2000000000L) {
                    error = path + ":" + std::to_string(line_no) + ": literal " + std::to_string(lit) +
                            " is out of range. Variable numbers must be below 2,000,000,000.";
                    return false;
                }
                if (a > max_var) max_var = a;
                current.push_back(static_cast<int>(lit));
            }
        }
    }
    if (in.bad()) {   // a read error ends the loop as the end of the file would (see read_error)
        error = read_error(path, line_no);
        return false;
    }
    if (!current.empty()) f.clauses.push_back(current);  // last clause without terminating 0

    if (!seen_p) {
        error = path + ": no 'p cnf <variables> <clauses>' line found. Check that the file is in DIMACS CNF format.";
        return false;
    }

    try {
        f.resize(static_cast<int>(max_var));
    } catch (const std::bad_alloc&) {
        error = path + ": the formula uses variable number " + std::to_string(max_var) +
                ", and there is not enough memory for that many variables. Check the 'p cnf' line and the variable "
                "numbers in the clauses and in the 'c <n> <name>' comments.";
        return false;
    }

    std::unordered_map<std::string, long> first_line;
    std::unordered_map<std::string, long> first_var;
    for (auto& n : named) {
        std::string name = n.name;
        // 1.x uvl2dimacs: "c <n> aux_<k>… (auxiliary)"
        if (ends_with(name, LEGACY_AUX_SUFFIX) && is_legacy_aux_name(name.substr(0, name.size() - 12))) {
            name = name.substr(0, name.size() - 12);
            f.aux[n.var] = name.find("_chain_") != std::string::npos ? AuxKind::Chain : AuxKind::Tseitin;
        }
        if (!f.names[n.var].empty()) {
            if (f.names[n.var] == name) continue;
            error = path + ":" + std::to_string(n.line) + ": variable " + std::to_string(n.var) +
                    " has two names ('" + f.names[n.var] + "' and '" + name + "'). Each variable may be named once.";
            return false;
        }
        auto it = first_var.find(name);
        if (it != first_var.end()) {
            error = path + ":" + std::to_string(n.line) + ": duplicate name '" + name + "' for variables " +
                    std::to_string(it->second) + " (line " + std::to_string(first_line[name]) + ") and " +
                    std::to_string(n.var) + ". Names must be unique.";
            return false;
        }
        first_var[name] = n.var;
        first_line[name] = n.line;
        f.names[n.var] = name;
    }
    for (auto& a : aux_marks) f.aux[a.first] = a.second;
    for (long r : roots) f.is_root[r] = 1;
    for (long a : abstracts) f.is_abstract[a] = 1;
    return true;
}

} // namespace dimacs2graphs
