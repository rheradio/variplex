/**
 * @file OutputFiles.cc
 * @brief Pajek and node-list writers/readers (see OutputFiles.hh)
 */

#include "OutputFiles.hh"
#include "DimacsFormula.hh"

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstdlib>

namespace dimacs2graphs {

AtomicFile::AtomicFile(const std::string& path) : path_(path), tmp_(path + ".tmp") {
    out_.open(tmp_, std::ios::binary | std::ios::trunc);
}

AtomicFile::~AtomicFile() {
    if (!committed_) {
        if (out_.is_open()) out_.close();
        std::remove(tmp_.c_str());
    }
}

bool AtomicFile::commit(std::string& error) {
    if (!out_.is_open()) {
        error = "cannot create output file '" + tmp_ + "'. Check that the output directory exists and is writable.";
        return false;
    }
    out_.flush();
    bool ok = static_cast<bool>(out_);
    out_.close();
    if (!ok) {
        error = "error while writing '" + tmp_ + "' (disk full?). Free some space or choose another output directory with -o.";
        return false;
    }
    std::remove(path_.c_str());
    if (std::rename(tmp_.c_str(), path_.c_str()) != 0) {
        error = "cannot rename '" + tmp_ + "' to '" + path_ + "'. Check the permissions of the output directory.";
        return false;
    }
    committed_ = true;
    return true;
}

std::string pajek_quote(const std::string& name) {
    std::string q;
    q.reserve(name.size() + 2);
    q += '"';
    for (char c : name) {
        if (c == '"') q += '\\';
        q += c;
    }
    q += '"';
    return q;
}

bool write_pajek(const std::string& path, const std::vector<std::string>& names,
                 std::vector<Link> links, bool directed, std::string& error) {
    const int n = static_cast<int>(names.size());
    if (!directed) {
        for (auto& l : links)
            if (l.first > l.second) std::swap(l.first, l.second);
    }
    std::sort(links.begin(), links.end());
    links.erase(std::unique(links.begin(), links.end()), links.end());

    AtomicFile f(path);
    std::ostream& o = f.out();
    o << "*Vertices " << n << '\n';
    for (int i = 0; i < n; ++i) o << (i + 1) << ' ' << pajek_quote(names[i]) << '\n';
    o << (directed ? "*Arcs" : "*Edges") << '\n';
    for (const auto& l : links) {
        if (l.first < 1 || l.first > n || l.second < 1 || l.second > n) {
            error = "internal error: link " + std::to_string(l.first) + " " + std::to_string(l.second) +
                    " outside 1.." + std::to_string(n) + " while writing " + path + ". Please report it with the input file.";
            return false;
        }
        o << l.first << ' ' << l.second << '\n';
    }
    return f.commit(error);
}

namespace {

// Splits `body` at every occurrence of: quote, `between`, one or more blanks, quote.
std::vector<std::string> split_words_1x(const std::string& body, const std::string& between) {
    std::vector<std::string> words;
    std::string cur;
    size_t i = 0;
    while (i < body.size()) {
        if (body[i] == '"' && body.compare(i + 1, between.size(), between) == 0) {
            size_t j = i + 1 + between.size(), blanks = 0;
            while (j < body.size() && (body[j] == ' ' || body[j] == '\t')) { ++j; ++blanks; }
            if (blanks && j < body.size() && body[j] == '"') {
                words.push_back(cur);
                cur.clear();
                i = j + 1;
                continue;
            }
        }
        cur += body[i++];
    }
    words.push_back(cur);
    return words;
}

bool ends_with(const std::string& s, const std::string& k) {
    return s.size() >= k.size() && s.compare(s.size() - k.size(), k.size(), k) == 0;
}

const char* const ATOMIC_MARKERS[] = {"[abstract-group]", "[tristate]", "[abstract]"};

}  // namespace

std::string parse_quoted_name(const std::string& s, size_t pos, long ident) {
    const size_t a = pos < s.size() ? s.find('"', pos) : std::string::npos;
    const size_t b = s.rfind('"');
    if (a == std::string::npos || b == a) {
        // no label in quotes: the first word (a label of one word needs no quotes in Pajek)
        size_t p = pos < s.size() ? s.find_first_not_of(" \t", pos) : std::string::npos;
        if (p == std::string::npos || a != std::string::npos) return "";
        size_t e = s.find_first_of(" \t", p);
        return s.substr(p, e == std::string::npos ? std::string::npos : e - p);
    }
    const std::string body = s.substr(a + 1, b - a - 1);
    bool escaped = true;   // 2.x: every quote of the name is preceded by a backslash
    for (size_t i = 0; i < body.size() && escaped; ++i)
        if (body[i] == '"' && (i == 0 || body[i - 1] != '\\')) escaped = false;
    if (escaped) {
        std::string name;
        name.reserve(body.size());
        for (size_t i = 0; i < body.size(); ++i) {
            if (body[i] == '\\' && i + 1 < body.size() && body[i + 1] == '"') continue;  // the backslash of an escaped quote
            name += body[i];
        }
        return name;
    }
    // 1.x: one quoted string per word; the lists repeat the identifier before every word
    std::vector<std::string> words;
    if (ident >= 0) words = split_words_1x(body, std::to_string(ident));
    if (words.size() < 2) words = split_words_1x(body, "");
    std::string name;
    for (size_t i = 0; i < words.size(); ++i) name += (i ? " " : "") + words[i];
    return name;
}

std::string tsv_field(const std::string& name, bool protect_marker) {
    std::string f;
    f.reserve(name.size() + 2);
    for (char c : name) {
        if (c == '\\') f += "\\\\";
        else if (c == '\t') f += "\\t";
        else f += c;
    }
    if (protect_marker && tsv_marked(f)) f.insert(f.size() - 1, "\\");
    return f;
}

std::string tsv_unfield(const std::string& field) {
    std::string name;
    name.reserve(field.size());
    for (size_t i = 0; i < field.size(); ++i) {
        if (field[i] == '\\' && i + 1 < field.size()) {
            const char d = field[i + 1];
            if (d == '\\' || d == ']') { name += d; ++i; continue; }
            if (d == 't') { name += '\t'; ++i; continue; }
        }
        name += field[i];
    }
    return name;
}

bool tsv_marked(const std::string& field) {
    for (const char* m : ATOMIC_MARKERS)
        if (field.size() > std::string(m).size() && ends_with(field, m)) return true;
    return false;
}

namespace {
bool ieq_prefix(const std::string& s, const char* p) {
    for (size_t i = 0; p[i]; ++i)
        if (i >= s.size() || std::tolower(static_cast<unsigned char>(s[i])) != std::tolower(static_cast<unsigned char>(p[i])))
            return false;
    return true;
}
}  // namespace

bool read_pajek(const std::string& path, PajekGraph& g, std::string& error) {
    g = PajekGraph();
    std::ifstream in(path);
    if (!in.is_open()) {
        error = "cannot open '" + path + "'. Check that the file exists and is readable.";
        return false;
    }
    enum { NONE, VERT, LINKS } sec = NONE;
    std::string line;
    long line_no = 0;
    std::vector<std::pair<long, std::string>> vertices;
    std::vector<std::pair<long, long>> raw_links;
    while (std::getline(in, line)) {
        ++line_no;
        if (!line.empty() && line.back() == '\r') line.pop_back();
        size_t p = line.find_first_not_of(" \t");
        if (p == std::string::npos) continue;
        if (line[p] == '*') {
            std::string h = line.substr(p);
            if (ieq_prefix(h, "*vertices")) { sec = VERT; g.declared = std::atoi(h.c_str() + 9); }
            else if (ieq_prefix(h, "*arcs")) { sec = LINKS; g.directed = true; }
            else if (ieq_prefix(h, "*edges")) { sec = LINKS; g.directed = false; }
            else {
                error = path + ":" + std::to_string(line_no) + ": unknown section '" + h +
                        "'. Expected '*Vertices N', '*Arcs' or '*Edges' (Pajek format).";
                return false;
            }
            continue;
        }
        char* end;
        long a = std::strtol(line.c_str() + p, &end, 10);
        if (end == line.c_str() + p) {
            error = path + ":" + std::to_string(line_no) + ": expected a vertex ('<id> \"<name>\"') or a link ('<id> <id>'). "
                    "The file is not a Pajek graph written by Strong4VM.";
            return false;
        }
        if (sec == VERT) {
            vertices.push_back({a, parse_quoted_name(line, static_cast<size_t>(end - line.c_str()))});
        } else if (sec == LINKS) {
            long b = std::strtol(end, &end, 10);
            raw_links.push_back({a, b});
        } else {
            error = path + ":" + std::to_string(line_no) + ": data before '*Vertices'. A Pajek file starts with '*Vertices N'.";
            return false;
        }
    }
    if (in.bad()) {   // a read error ends the loop as the end of the file would
        error = read_error(path, line_no);
        return false;
    }
    std::sort(vertices.begin(), vertices.end(), [](const auto& x, const auto& y) { return x.first < y.first; });
    std::vector<std::pair<long, int>> index;  // file id → compact id
    for (const auto& v : vertices) {
        if (!index.empty() && index.back().first == v.first) {
            g.issues.push_back("vertex id " + std::to_string(v.first) + " appears twice");
            continue;
        }
        if (v.first < 1 || v.first > g.declared)
            g.issues.push_back("vertex id " + std::to_string(v.first) + " outside 1.." + std::to_string(g.declared));
        g.names.push_back(v.second);
        g.original_ids.push_back(static_cast<int>(v.first));
        index.push_back({v.first, static_cast<int>(g.names.size())});
    }
    if (static_cast<int>(g.names.size()) != g.declared)
        g.issues.push_back("*Vertices " + std::to_string(g.declared) + " but " + std::to_string(g.names.size()) + " vertices listed");
    auto find = [&](long id) {
        auto it = std::lower_bound(index.begin(), index.end(), std::make_pair(id, 0),
                                   [](const auto& x, const auto& y) { return x.first < y.first; });
        return (it != index.end() && it->first == id) ? it->second : 0;
    };
    long unknown = 0;
    for (const auto& l : raw_links) {
        int a = find(l.first), b = find(l.second);
        if (!a || !b) { ++unknown; continue; }
        g.links.push_back({a, b});
    }
    if (unknown) g.issues.push_back(std::to_string(unknown) + " links reference unknown vertices");
    return true;
}

bool write_node_list(const std::string& path, const std::vector<ListedNode>& nodes, std::string& error) {
    AtomicFile f(path);
    for (const auto& n : nodes) f.out() << n.id << ' ' << pajek_quote(n.name) << '\n';
    return f.commit(error);
}

bool read_node_list(const std::string& path, std::vector<ListedNode>& nodes, std::string& error) {
    nodes.clear();
    std::ifstream in(path);
    if (!in.is_open()) {
        error = "cannot open '" + path + "'. Check that the file exists and is readable.";
        return false;
    }
    std::string line;
    long n = 0;
    while (std::getline(in, line)) {
        ++n;
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.find_first_not_of(" \t") == std::string::npos) continue;
        char* end;
        long id = std::strtol(line.c_str(), &end, 10);
        nodes.push_back({static_cast<int>(id), parse_quoted_name(line, static_cast<size_t>(end - line.c_str()), id)});
    }
    if (in.bad()) {   // a read error ends the loop as the end of the file would
        error = read_error(path, n);
        return false;
    }
    return true;
}

} // namespace dimacs2graphs
