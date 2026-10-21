/**
 * @file Pipeline.hh
 * @brief The `generate` pipeline of Strong4VM 2.0 (R-PIPE-01)
 *
 *  1. Read the formula and the name table.
 *  2. Detect or read the translator profile.
 *  3. Classify every variable; apply --tristate merge / --nonbool merge.
 *  4. Check satisfiability; an unsatisfiable formula is a void model.
 *  5. Global backbone: status of every variable.
 *  6. Main loop over the queried variables (kept and neither core nor dead).
 *  7. Atomic sets and abstract group features (T2).
 *  8. Apply --fixed-nodes and --synthetic-root, renumber nodes 1..N.
 *  9. Write graphs, lists, reports and optional products.
 */

#ifndef DIMACS2GRAPHS_PIPELINE_HH
#define DIMACS2GRAPHS_PIPELINE_HH

#include "../filter/Classifier.hh"
#include "../filter/Options.hh"
#include "../io/Json.hh"
#include "../io/OutputFiles.hh"
#include "GraphBuilder.hh"
#include "Status.hh"

#include <string>
#include <vector>

namespace dimacs2graphs {

/// Information about a UVL conversion (R-UVL-03, R-UVL-06, R-OUT-06 `uvl`).
struct UvlInfo {
    bool present = false;
    std::string mode;
    int skipped_constraints = 0;     ///< Constraints left out: not Boolean, or naming a feature that the model does not declare
    int typed_features = 0;          ///< Features declared Integer, String or Real: encoded by presence only
    int abstract_features = 0;       ///< Features marked {abstract}, the root included
    int feature_cardinalities = 0;   ///< Features with a feature cardinality: encoded as one feature, copies not represented
    int features = 0;
    std::vector<std::string> warnings;
};

struct GenerateRequest {
    std::string dimacs_path;     ///< Formula to analyse
    std::string input_path;      ///< The user's input (.uvl or DIMACS)
    std::string output_dir;      ///< Directory of the output files
    std::string stem;            ///< Base name of the output files
    bool input_is_uvl = false;
    UvlInfo uvl;
    GenerateOptions options;
    std::string command_line;
};

/// Status of a node or variable as written in the reports.
const char* status_name(VarStatus s);

struct GenerateResult {
    ExitCode code = ExitCode::Success;
    std::string error;
    Json summary;
    std::vector<std::string> warnings;

    // In-memory products (node ids are 1-based)
    std::vector<std::string> node_names;
    std::vector<int> node_var;               ///< DIMACS variable of each node (0 for unconstrained)
    std::vector<Link> requires_arcs;
    std::vector<Link> excludes_edges;
    std::vector<Link> atleastone_edges;
    std::vector<ListedNode> core, dead;
    Classification classification;
    std::vector<VarStatus> status;           ///< Index 1..num_vars
    std::vector<int> var_node;               ///< Node id of each variable (0 = none)
    std::vector<std::string> files;          ///< Files written
    /// Rows of __variables.csv (without header): dimacs_var, name, output_name, node_id, class, status, decision, rule
    std::vector<std::vector<std::string>> variable_rows;
};

/// Runs the pipeline and writes every output file.
GenerateResult run_generate(const GenerateRequest& req);

/// Quotes a CSV field as in RFC 4180 when needed.
std::string csv_field(const std::string& s);

} // namespace dimacs2graphs

#endif
