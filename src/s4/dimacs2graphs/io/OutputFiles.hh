/**
 * @file OutputFiles.hh
 * @brief Writers and readers of Strong4VM output files
 *
 * - Pajek `.net` files (R-OUT-01 to R-OUT-04): vertices numbered 1..N
 *   consecutively, names written as one quoted string with `"` escaped as
 *   `\"`, headers exactly `*Vertices N`, `*Arcs`, `*Edges`, arcs sorted by
 *   (source, target), edges written once with source < target.
 * - Node lists (`__core.txt`, `__dead.txt`): one line per option, the vertex id (0 if the
 *   option is not a vertex) and the quoted name.
 * - Every file is written under a temporary name and renamed when complete
 *   (R-OUT-08).
 */

#ifndef DIMACS2GRAPHS_OUTPUT_FILES_HH
#define DIMACS2GRAPHS_OUTPUT_FILES_HH

#include <fstream>
#include <string>
#include <utility>
#include <vector>

namespace dimacs2graphs {

using Link = std::pair<int, int>;

/**
 * @brief Output file written atomically: data goes to `<path>.tmp`, which is
 * renamed to `<path>` by commit(). If commit() is not called (error or
 * exception) the temporary file is removed.
 */
class AtomicFile {
public:
    explicit AtomicFile(const std::string& path);
    ~AtomicFile();
    AtomicFile(const AtomicFile&) = delete;
    AtomicFile& operator=(const AtomicFile&) = delete;

    bool is_open() const { return out_.is_open(); }
    std::ostream& out() { return out_; }
    /// Flushes, closes and renames. Returns false (with message) on failure.
    bool commit(std::string& error);

private:
    std::string path_, tmp_;
    std::ofstream out_;
    bool committed_ = false;
};

/// `name` as a Pajek quoted string: `"…"` with every `"` escaped as `\"`.
std::string pajek_quote(const std::string& name);

/**
 * @brief Writes a Pajek graph.
 * @param path     File to write
 * @param names    Vertex names; vertex i + 1 is names[i]
 * @param links    Links between vertex ids (1-based). For undirected graphs each
 *                 edge is normalised to (min, max); duplicates are removed.
 * @param directed true → `*Arcs`, false → `*Edges`
 * @param error    Message if the file cannot be written
 */
bool write_pajek(const std::string& path, const std::vector<std::string>& names,
                 std::vector<Link> links, bool directed, std::string& error);

/// Graph read from a Pajek file.
struct PajekGraph {
    std::vector<std::string> names;  ///< names[i] is vertex i + 1 (compact numbering)
    bool directed = false;           ///< true if the links section was `*Arcs`
    std::vector<Link> links;         ///< Links in compact numbering
    int declared = 0;                ///< N of `*Vertices N`
    std::vector<int> original_ids;   ///< Id in the file of each compact vertex
    /// Format problems (R-CHK-07): ids outside 1..N, wrong vertex count, links to unknown vertices
    std::vector<std::string> issues;
};

/**
 * @brief Reads a Pajek file written by Strong4VM 1.x or 2.x.
 *
 * Names are read with parse_quoted_name (the label of 2.x, or the quoted
 * words of 1.x joined with single spaces). Vertices are renumbered
 * 1..N in the order of their ids in the file (identity for 2.x files); ids
 * outside 1..N (1.x defect D5) and links to unknown ids are reported in
 * `issues` instead of failing, so that `strong4vm check` can report them.
 */
bool read_pajek(const std::string& path, PajekGraph& g, std::string& error);

/// Entry of a core/dead list: vertex id (0 if not a vertex) and name.
struct ListedNode { int id; std::string name; };

bool write_node_list(const std::string& path, const std::vector<ListedNode>& nodes, std::string& error);
bool read_node_list(const std::string& path, std::vector<ListedNode>& nodes, std::string& error);

/**
 * @brief Name written on a vertex line of a graph, or on a line of a core or dead list.
 *
 * The label is what lies between the first quote at or after `pos` and the last
 * quote of the line.
 *  - 2.x writes one quoted string in which every quote of the name is preceded
 *    by a backslash (R-OUT-02). When all the quotes inside the label are
 *    escaped this way, the name is the label without those backslashes: the
 *    exact inverse of pajek_quote, also for a name that ends in a backslash.
 *  - 1.x wrote one quoted string per word of the name and escaped nothing (D6):
 *    `12 "Fuel" "Type"` in the graphs and `12 "Fuel"12 "Type"` in the lists,
 *    where the identifier is repeated. The name is the words joined by single
 *    spaces; `ident` is the identifier of the line of a list (-1 for a graph).
 * A label without quotes is its first word.
 */
std::string parse_quoted_name(const std::string& line, size_t pos = 0, long ident = -1);

/**
 * @brief A name as a field of a tab-separated file (`__atomic.txt`, `__kernel_classes.txt`).
 *
 * A tab inside the name is written as `\t` and a backslash as `\\`, so that the
 * fields of a line can always be told apart. With `protect_marker`, a name
 * that itself ends in `[tristate]`, `[abstract-group]` or `[abstract]` gets its last bracket
 * written as `\]`, so that it cannot be taken for a marked entry of
 * `__atomic.txt`. Names without these characters are written unchanged.
 */
std::string tsv_field(const std::string& name, bool protect_marker = false);
/// Inverse of tsv_field.
std::string tsv_unfield(const std::string& field);
/// True if a field of `__atomic.txt` carries a marker (`X_MODULE[tristate]`, `G_xor[abstract-group]`, `BLE[abstract]`).
bool tsv_marked(const std::string& field);

} // namespace dimacs2graphs

#endif
