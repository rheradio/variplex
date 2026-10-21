#include "vp_io.h"  // added by variplex (tools/sync_cpp.R)
#include "BackboneSimplifier.hh"
#include "api/BoneDiggerAPI.hh"
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <iostream>
#include <cstdlib>
#include <regex>
#include <array>
#include <memory>

namespace uvl2dimacs {

BackboneSimplifier::BackboneSimplifier()
    : backbone_size_(0), removed_clauses_(0), shortened_clauses_(0),
      num_vars_(0), num_clauses_(0), verbose_(false) {}

BackboneSimplifier::~BackboneSimplifier() {}

bool BackboneSimplifier::simplify(const std::string& input_dimacs_path,
                                   const std::string& output_dimacs_path,
                                   const std::string& backbone_solver_path,
                                   bool verbose) {
    verbose_ = verbose;

    if (verbose_) {
        vp::out() << "Backbone simplification started..." << std::endl;
    }

    // First pass: read the header to get num_vars
    std::ifstream input_file(input_dimacs_path);
    if (!input_file.is_open()) {
        vp::err() << "Error: Cannot open input DIMACS file: " << input_dimacs_path << std::endl;
        return false;
    }

    std::string line;
    while (std::getline(input_file, line)) {
        if (line.empty() || line[0] == 'c') {
            continue;
        }
        if (line[0] == 'p') {
            std::istringstream iss(line);
            std::string p, cnf;
            iss >> p >> cnf >> num_vars_ >> num_clauses_;
            break;
        }
    }
    input_file.close();

    if (num_vars_ == 0) {
        vp::err() << "Error: Invalid DIMACS file (no problem line found)" << std::endl;
        return false;
    }

    if (verbose_) {
        vp::out() << "Input formula: " << num_vars_ << " variables, " << num_clauses_ << " clauses" << std::endl;
    }

    // Compute backbone using backbone_solver
    if (!compute_backbone(input_dimacs_path, backbone_solver_path, num_vars_)) {
        vp::err() << "Error: Backbone computation failed" << std::endl;
        return false;
    }

    if (verbose_) {
        vp::out() << "Backbone size: " << backbone_size_ << std::endl;
    }

    // Simplify clauses
    if (!simplify_clauses(input_dimacs_path, output_dimacs_path)) {
        vp::err() << "Error: Clause simplification failed" << std::endl;
        return false;
    }

    if (verbose_) {
        vp::out() << "Simplification complete:" << std::endl;
        vp::out() << "  Removed clauses: " << removed_clauses_ << std::endl;
        vp::out() << "  Shortened clauses: " << shortened_clauses_ << std::endl;
        vp::out() << "  Output: " << num_vars_ << " variables, " << num_clauses_ << " clauses" << std::endl;
    }

    return true;
}

bool BackboneSimplifier::compute_backbone(const std::string& dimacs_path,
                                          const std::string& /* backbone_solver_path: unused in variplex */,
                                          int num_vars) {
    // variplex: BoneDigger is called as a library, not run as a program
    backbone_.clear();
    backbone_.resize(num_vars + 1, BackboneState::NONE);
    bonedigger::BoneDiggerAPI api;
    if (!api.set_solver("glucose-3.0") || !api.read_dimacs(dimacs_path) || !api.create_backbone_detector("rush"))
        return false;
    api.set_attention_weight(1);
    for (int literal : api.compute_backbone()) {
        int var_id = std::abs(literal);
        if (var_id > 0 && var_id <= num_vars) {
            backbone_[var_id] = literal > 0 ? BackboneState::TRUE : BackboneState::FALSE;
            backbone_size_++;
        }
    }
    return true;
}

bool BackboneSimplifier::parse_backbone_output(const std::string& output, int num_vars) {
    // Remove ANSI escape codes
    std::regex ansi_regex(R"(\x1b\[[0-9;]*m)");
    std::string clean_output = std::regex_replace(output, ansi_regex, "");

    // Find the backbone line (starts with 'v ')
    std::istringstream iss(clean_output);
    std::string line;
    bool found_backbone = false;

    while (std::getline(iss, line)) {
        if (line.length() >= 2 && line[0] == 'v' && line[1] == ' ') {
            found_backbone = true;

            // Parse literals
            std::istringstream literal_stream(line.substr(2));
            int literal;

            while (literal_stream >> literal) {
                if (literal == 0) break;

                int var_id = std::abs(literal);
                if (var_id > 0 && var_id <= num_vars) {
                    if (literal > 0) {
                        backbone_[var_id] = BackboneState::TRUE;
                    } else {
                        backbone_[var_id] = BackboneState::FALSE;
                    }
                    backbone_size_++;
                }
            }
            break;
        }
    }

    if (!found_backbone) {
        // Empty backbone is valid (no backbone literals)
        if (verbose_) {
            vp::out() << "No backbone found (formula has flexible variables)" << std::endl;
        }
        return true;
    }

    return true;
}

bool BackboneSimplifier::simplify_clauses(const std::string& input_dimacs_path,
                                          const std::string& output_dimacs_path) {
    std::ifstream input_file(input_dimacs_path);
    if (!input_file.is_open()) {
        vp::err() << "Error: Cannot open input DIMACS file" << std::endl;
        return false;
    }

    // Create temporary file
    std::string temp_path = output_dimacs_path + ".tmp";
    std::ofstream temp_file(temp_path);
    if (!temp_file.is_open()) {
        vp::err() << "Error: Cannot create temporary file" << std::endl;
        return false;
    }

    // Reset counters
    int new_num_clauses = backbone_size_;  // Start with backbone clauses
    removed_clauses_ = 0;
    shortened_clauses_ = 0;

    // First pass: collect comments and process clauses
    std::string line;
    bool in_clauses = false;
    std::vector<std::string> comments;
    std::vector<std::string> processed_clauses;

    while (std::getline(input_file, line)) {
        // Skip empty lines
        if (line.empty()) continue;

        // Collect comment lines
        if (line[0] == 'c') {
            comments.push_back(line);
            continue;
        }

        // Skip problem line (we'll write it later)
        if (line[0] == 'p') {
            in_clauses = true;
            continue;
        }

        // Process clause
        if (in_clauses) {
            std::istringstream iss(line);
            std::vector<int> clause;
            int literal;

            while (iss >> literal) {
                clause.push_back(literal);
            }

            // Process the clause
            if (clause.size() >= 2 && clause.back() == 0) {  // Valid clause with terminating 0
                if (process_clause(clause)) {
                    // Keep the clause - collect it
                    new_num_clauses++;
                    std::string clause_str;
                    for (int lit : clause) {
                        clause_str += std::to_string(lit) + " ";
                    }
                    processed_clauses.push_back(clause_str);
                } else {
                    // Clause was removed
                    removed_clauses_++;
                }
            }
        }
    }

    input_file.close();

    // Now write everything in the correct order:
    // 1. Comments
    // 2. Backbone clauses
    // 3. Remaining clauses

    // Write comments
    for (const auto& comment : comments) {
        temp_file << comment << "\n";
    }

    // Write backbone clauses
    for (size_t i = 1; i < backbone_.size(); ++i) {
        if (backbone_[i] == BackboneState::TRUE) {
            temp_file << i << " 0\n";
        } else if (backbone_[i] == BackboneState::FALSE) {
            temp_file << "-" << i << " 0\n";
        }
    }

    // Write remaining clauses
    for (const auto& clause_str : processed_clauses) {
        temp_file << clause_str << "\n";
    }

    temp_file.close();

    // Now create the final output file with correct header
    std::ofstream output_file(output_dimacs_path);
    if (!output_file.is_open()) {
        vp::err() << "Error: Cannot create output file" << std::endl;
        return false;
    }

    // Write header
    output_file << "p cnf " << num_vars_ << " " << new_num_clauses << "\n";

    // Copy temporary file content
    std::ifstream temp_input(temp_path);
    std::string temp_line;
    while (std::getline(temp_input, temp_line)) {
        output_file << temp_line << "\n";
    }
    temp_input.close();
    output_file.close();

    // Remove temporary file
    std::remove(temp_path.c_str());

    // Update clause count
    num_clauses_ = new_num_clauses;

    return true;
}

bool BackboneSimplifier::process_clause(std::vector<int>& clause) {
    if (clause.empty() || clause.back() != 0) {
        return true;  // Keep malformed clauses as-is
    }

    std::vector<int> literals_to_remove;
    bool clause_shortened = false;

    // Check each literal (except the terminating 0)
    for (size_t i = 0; i < clause.size() - 1; ++i) {
        int literal = clause[i];
        int var_id = std::abs(literal);

        if (var_id <= 0 || var_id >= (int)backbone_.size()) {
            continue;  // Invalid variable ID
        }

        if (literal > 0) {
            // Positive literal
            if (backbone_[var_id] == BackboneState::TRUE) {
                // Clause is satisfied, remove it
                return false;
            } else if (backbone_[var_id] == BackboneState::FALSE) {
                // Literal is false, remove it from clause
                literals_to_remove.push_back(i);
                clause_shortened = true;
            }
        } else {
            // Negative literal
            if (backbone_[var_id] == BackboneState::FALSE) {
                // Clause is satisfied, remove it
                return false;
            } else if (backbone_[var_id] == BackboneState::TRUE) {
                // Literal is false, remove it from clause
                literals_to_remove.push_back(i);
                clause_shortened = true;
            }
        }
    }

    // Remove literals in reverse order to maintain indices
    for (auto it = literals_to_remove.rbegin(); it != literals_to_remove.rend(); ++it) {
        clause.erase(clause.begin() + *it);
    }

    // Increment counter if clause was shortened
    if (clause_shortened) {
        shortened_clauses_++;
    }

    // Keep the clause
    return true;
}

} // namespace uvl2dimacs
