/**
 * @file Checks.cc
 * @brief Consistency checks (see Checks.hh)
 */

#include "Checks.hh"
#include "Graph.hh"

#include <algorithm>
#include <memory>
#include <set>
#include <unordered_map>

namespace dimacs2graphs {

namespace {

/// Membership test on a graph: bit matrix when it fits in memory, binary search otherwise.
class Relation {
public:
    Relation(const Csr& g, bool use_matrix) : g_(g) {
        if (use_matrix) m_ = std::make_unique<BitMatrix>(BitMatrix::from_csr(g));
    }
    bool has(int u, int v) const { return m_ ? m_->test(u, v) : g_.has(u, v); }

private:
    const Csr& g_;
    std::unique_ptr<BitMatrix> m_;
};

struct Result {
    Result(const char* i, const char* d) : id(i), description(d) {}
    std::string id, description;
    long violations = 0;
    std::vector<std::string> examples;
    bool applicable = true;

    void add(const std::string& ex) {
        ++violations;
        if (examples.size() < 10) examples.push_back(ex);
    }
};

}  // namespace

Json run_checks(const CheckInput& in) {
    const int n = static_cast<int>(in.names.size());
    std::vector<Result> results;
    auto nm = [&](int u) { return u >= 0 && u < n ? in.names[u] : "#" + std::to_string(u + 1); };
    auto pair = [&](int a, int b, const char* rel) { return nm(a) + " " + rel + " " + nm(b); };

    // R-CHK-07 first: links must be inside 1..N before any other check can use them
    Result r7{"R-CHK-07", "vertex identifiers in 1..N and unique names"};
    auto in_range = [&](const std::vector<Link>& links, const char* what) {
        std::vector<Link> ok;
        for (const auto& l : links) {
            if (l.first < 1 || l.first > n || l.second < 1 || l.second > n)
                r7.add(std::string(what) + " link " + std::to_string(l.first) + " " + std::to_string(l.second) + " outside 1.." + std::to_string(n));
            else ok.push_back(l);
        }
        return ok;
    };
    std::vector<Link> D = in_range(in.requires_arcs, "requires");
    std::vector<Link> C = in_range(in.excludes_edges, "excludes");
    std::vector<Link> A = in_range(in.atleastone_edges, "atleastone");
    std::vector<Link> X = in_range(in.or_implied_arcs, "implied");
    {
        std::unordered_map<std::string, int> seen;
        for (int u = 0; u < n; ++u)
            if (!seen.emplace(in.names[u], u).second) r7.add("duplicate name '" + in.names[u] + "'");
    }

    const bool matrix = BitMatrix::bytes(n) * 3 <= in.max_matrix_memory_gb * 1e9;
    Csr gd = Csr::from_links(n, D, false);
    Csr gc = Csr::from_links(n, C, true);
    Csr ga = Csr::from_links(n, A, true);
    Relation rd(gd, matrix), rc(gc, matrix);

    // R-CHK-01: D·D ⊆ D ∪ I
    Result r1{"R-CHK-01", "requires is transitive (D·D ⊆ D ∪ I)"};
    for (int u = 0; u < n; ++u)
        for (const int* x = gd.begin(u); x != gd.end(u); ++x)
            for (const int* w = gd.begin(*x); w != gd.end(*x); ++w)
                if (*w != u && !rd.has(u, *w)) r1.add(pair(u, *w, "->") + " missing (via " + nm(*x) + ")");

    // R-CHK-02: D·C ⊆ C ; R-CHK-06: no option requires two mutually exclusive options
    Result r2{"R-CHK-02", "conflicts are inherited (D·C ⊆ C)"};
    Result r6{"R-CHK-06", "no option requires two options that exclude each other"};
    for (int u = 0; u < n; ++u)
        for (const int* x = gd.begin(u); x != gd.end(u); ++x)
            for (const int* w = gc.begin(*x); w != gc.end(*x); ++w) {
                if (*w == u) { r6.add(nm(u) + " requires " + nm(*x) + ", which excludes " + nm(u)); continue; }
                if (!rc.has(u, *w)) r2.add(pair(u, *w, "#") + " missing (" + nm(u) + " -> " + nm(*x) + ")");
                if (*w > *x && rd.has(u, *w)) r6.add(nm(u) + " requires " + nm(*x) + " and " + nm(*w) + ", which exclude each other");
            }

    // R-CHK-03: symmetric (an *Edges section) and no loops
    Result r3{"R-CHK-03", "excludes is symmetric and has no loops"};
    if (in.excludes_directed) r3.add("the excludes file has an *Arcs section instead of *Edges");
    for (const auto& l : C)
        if (l.first == l.second) r3.add(nm(l.first - 1) + " excludes itself");

    // R-CHK-04: no core or dead vertex
    Result r4{"R-CHK-04", "no vertex is core or dead (--fixed-nodes drop)"};
    r4.applicable = in.fixed_nodes_dropped;
    if (r4.applicable) {
        for (const auto& c : in.core) if (c.id != 0) r4.add("core option '" + c.name + "' is vertex " + std::to_string(c.id));
        for (const auto& d : in.dead) if (d.id != 0) r4.add("dead option '" + d.name + "' is vertex " + std::to_string(d.id));
    }

    // R-CHK-05: C·A ⊆ D, A·D ⊆ A, cross-check (R-OR-02)
    Result r5{"R-CHK-05", "consistency of the three graphs (C·A ⊆ D, A·D ⊆ A, R-OR-02 cross-check)"};
    r5.applicable = in.has_atleastone;
    if (r5.applicable) {
        Relation ra(ga, matrix);
        for (int u = 0; u < n; ++u) {
            for (const int* x = gc.begin(u); x != gc.end(u); ++x)
                for (const int* w = ga.begin(*x); w != ga.end(*x); ++w)
                    if (*w != u && !rd.has(u, *w)) r5.add(pair(u, *w, "->") + " missing (C·A: " + nm(u) + " # " + nm(*x) + ", " + nm(*x) + " v " + nm(*w) + ")");
            for (const int* x = ga.begin(u); x != ga.end(u); ++x)
                for (const int* w = gd.begin(*x); w != gd.end(*x); ++w)
                    if (*w != u && !ra.has(u, *w)) r5.add(pair(u, *w, "v") + " missing (A·D via " + nm(*x) + ")");
        }
        if (in.has_crosscheck) {
            std::vector<Link> d = D, x = X;
            std::sort(d.begin(), d.end());
            std::sort(x.begin(), x.end());
            x.erase(std::unique(x.begin(), x.end()), x.end());
            std::vector<Link> diff;
            std::set_symmetric_difference(d.begin(), d.end(), x.begin(), x.end(), std::back_inserter(diff));
            for (const auto& l : diff)
                r5.add("cross-check (R-OR-02): " + pair(l.first - 1, l.second - 1, "->") +
                       (std::binary_search(d.begin(), d.end(), l) ? " is in requires but not implied under v = false"
                                                                   : " is implied under v = false but not in requires"));
        }
    }

    results = {r1, r2, r3, r4, r5, r6, r7};
    Json out = Json::object();
    bool passed = true;
    Json& list = out["results"];
    list = Json::array();
    for (const auto& r : results) {
        Json j = Json::object();
        j["id"] = r.id;
        j["description"] = r.description;
        if (!r.applicable) {
            j["applicable"] = false;
        } else {
            j["passed"] = r.violations == 0;
            j["violations"] = r.violations;
            j["examples"] = Json::array_of(r.examples);
            passed = passed && r.violations == 0;
        }
        list.push(j);
    }
    out["passed"] = passed;
    out["method"] = matrix ? "bit matrix" : "sparse";
    // Put "passed" first for readability
    Json ordered = Json::object();
    ordered["passed"] = passed;
    ordered["method"] = out["method"];
    ordered["results"] = list;
    return ordered;
}

} // namespace dimacs2graphs
