/**
 * @file DimacsWriter.cc
 * @brief Implementation of DIMACS CNF format writer
 *
 * This file implements the DimacsWriter class which outputs CNF formulas
 * in DIMACS format, the standard input format for SAT solvers.
 *
 * DIMACS CNF Format Specification:
 * - Comment lines start with 'c'
 * - Problem line: "p cnf <num_vars> <num_clauses>"
 * - Clauses: Space-separated literals terminated by '0'
 * - Literals: Positive integers (variable) or negative integers (negated variable)
 *
 * Example:
 * @code
 * c This is a comment
 * c 1 FeatureA
 * c 2 FeatureB
 * p cnf 2 3
 * 1 2 0
 * -1 0
 * 2 0
 * @endcode
 *
 * @author UVL2Dimacs Team
 * @date 2024
 */

#include "DimacsWriter.hh"
#include <fstream>
#include <sstream>
#include <stdexcept>

/**
 * @brief Constructs a DIMACS writer for the given CNF model
 *
 * @param model The CNF model to write
 */
DimacsWriter::DimacsWriter(const CNFModel& model)
    : cnf_model(model) {
}

/**
 * @brief Writes the CNF model to a file in DIMACS format
 *
 * Creates or overwrites the specified file with DIMACS CNF output.
 * Includes comment lines for variable mappings followed by all clauses.
 *
 * @param filepath Path to output file
 * @throws std::runtime_error if file cannot be opened for writing
 */
void DimacsWriter::write_to_file(const std::string& filepath) {
    std::ofstream file(filepath);
    if (!file.is_open()) {
        throw std::runtime_error("Failed to open file for writing: " + filepath);
    }

    write_to_stream(file);
    file.close();
}

/**
 * @brief Writes the CNF model to an output stream in DIMACS format
 *
 * Output format (uvl2dimacs 2.0):
 * 1. Header (first comment, R-UVL-04): "c generated-by uvl2dimacs 2.0 mode=<straightforward|tseitin>"
 * 2. Informational comments and the problem line "p cnf <variables> <clauses>"
 * 3. Feature names, verbatim up to the end of the line (R-UVL-07): "c <var_id> <feature name>"
 * 4. Reserved comments that no feature name can produce (R-UVL-01, R-UVL-05):
 *    "c root <var_id>", "c abstract <var_id>", "c aux <var_id> <tseitin|chain>"
 * 5. Clauses: "<lit1> <lit2> ... 0" (one per line)
 *
 * Auxiliary variables carry no name, so a feature called e.g. "aux_power" is
 * never mistaken for one (fixes D13). Other DIMACS readers ignore "c" lines.
 *
 * @param out Output stream to write to
 */
void DimacsWriter::write_to_stream(std::ostream& out) {
    const auto& features = cnf_model.get_features();
    const auto& aux_vars = cnf_model.get_auxiliary_variables();

    out << "c generated-by uvl2dimacs 2.0 mode=" << cnf_model.get_mode_name() << "\n";
    out << "c Original features: " << features.size() << "\n";
    out << "c Auxiliary variables: " << aux_vars.size() << "\n";
    out << "c Total variables: " << cnf_model.get_num_variables() << "\n";

    out << "p cnf " << cnf_model.get_num_variables() << " " << cnf_model.get_num_clauses() << "\n";

    for (const auto& [var_id, feature_name] : features) {
        out << "c " << var_id << " " << feature_name << "\n";
    }
    if (cnf_model.get_root_variable() > 0) {
        out << "c root " << cnf_model.get_root_variable() << "\n";
    }
    for (int v : cnf_model.get_abstract_variables()) {
        out << "c abstract " << v << "\n";
    }
    for (const auto& entry : aux_vars) {
        out << "c aux " << entry.first << " " << cnf_model.get_auxiliary_kind(entry.first) << "\n";
    }

    // Write clauses
    const auto& clauses = cnf_model.get_clauses();
    for (const auto& clause : clauses) {
        for (int literal : clause) {
            out << literal << " ";
        }
        out << "0\n";
    }
}

/**
 * @brief Converts the CNF model to a DIMACS format string
 *
 * Convenience method that writes to a string stream and returns the result.
 * Useful for in-memory representation or testing.
 *
 * @return String containing the complete DIMACS CNF representation
 */
std::string DimacsWriter::to_dimacs_string() {
    std::ostringstream oss;
    write_to_stream(oss);
    return oss.str();
}
