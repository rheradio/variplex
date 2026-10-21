#include "vp_io.h"  // added by variplex (tools/sync_cpp.R)
/*
 * MIT License
 *
 * Copyright (c) 2026 Rubén Heradio and David Fernández Amorós
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * @file UVL2Dimacs.cc
 * @brief Implementation of the UVL2Dimacs API
 */

#include "uvl2dimacs/UVL2Dimacs.hh"
#include "FeatureModelBuilder.hh"
#include "FMToCNF.hh"
#include "DimacsWriter.hh"
#include "BackboneSimplifier.hh"
#include "CNFMode.hh"
#include "UVLCppLexer.h"
#include "UVLCppParser.h"
#include "antlr4-runtime.h"

#include <iostream>
#include <fstream>
#include <sstream>
#include <cstdio>

using namespace antlr4;
using namespace antlr4::tree;

namespace uvl2dimacs {

/**
 * @brief Custom error listener for ANTLR parsing
 */
class CustomErrorListener : public BaseErrorListener {
private:
    std::string& error_msg_;

public:
    explicit CustomErrorListener(std::string& error_msg) : error_msg_(error_msg) {}

    void syntaxError(
        Recognizer *recognizer,
        Token *offendingSymbol,
        size_t line,
        size_t charPositionInLine,
        const std::string &msg,
        std::exception_ptr e) override {

        // Ignore tab-related warnings
        if (msg.find("\\t") != std::string::npos) {
            return;
        }

        // Store error message
        std::ostringstream oss;
        oss << "Syntax error at line " << line << ":" << charPositionInLine
            << " - " << msg;
        error_msg_ = oss.str();
    }
};

/**
 * @brief Parses the model and stops at the first syntax error
 *
 * ANTLR's default error strategy tries to go on after a syntax error by inventing or dropping tokens.
 * On some malformed files that recovery dereferenced a null pointer and the program crashed with a
 * segmentation fault (in 1.x too). A model with a syntax error is of no use, so the parser gives up at
 * the first one and the caller reports it.
 *
 * @return The parse tree, or nullptr after a syntax error (parse_error then says where)
 */
static ParseTree* parse_feature_model(UVLCppParser& parser, std::string& parse_error) {
    parser.setErrorHandler(std::make_shared<BailErrorStrategy>());
    try {
        ParseTree* tree = parser.featureModel();
        return parse_error.empty() ? tree : nullptr;
    } catch (const ParseCancellationException&) {
        if (parse_error.empty()) {
            std::ostringstream oss;
            oss << "Syntax error";
            Token* t = parser.getCurrentToken();
            if (t != nullptr) {
                oss << " at line " << t->getLine() << ":" << t->getCharPositionInLine();
                if (t->getType() == Token::EOF) oss << " - unexpected end of file";
                else oss << " - unexpected '" << t->getText() << "'";
            }
            parse_error = oss.str();
        }
        return nullptr;
    }
}

/**
 * @brief Copies skipped constraints, typed/abstract feature counts and feature cardinalities into the result
 */
static void fill_model_report(const FeatureModel& model, ConversionReport& result) {
    for (const auto& sc : model.get_skipped_constraints()) {
        result.skipped_constraints.push_back("line " + std::to_string(sc.line) + ": constraint \"" + sc.text +
                                             "\" was skipped: " + sc.reason);
    }
    for (const auto& f : model.get_features()) {
        if (f->get_type() != "Boolean") result.num_typed_features++;
        if (f->is_abstract()) result.num_abstract_features++;
    }
    if (result.num_typed_features > 0) {
        vp::err() << "Warning: " << result.num_typed_features
                  << " feature(s) are declared Integer, String or Real; they are encoded only by their presence,"
                     " their values are not represented." << std::endl;
    }
    for (const auto& fc : model.get_feature_cardinalities()) {
        result.feature_cardinalities.push_back(
            "line " + std::to_string(fc.line) + ": feature \"" + fc.feature + "\" has the feature cardinality " + fc.bounds +
            ": it is encoded as one feature, mandatory or optional as its group says; the number of its copies, and "
            "what each copy has, are not represented");
        vp::err() << "Warning: " << result.feature_cardinalities.back() << "." << std::endl;
    }
}

/**
 * @brief Convert ConversionMode to CNFMode
 */
static CNFMode to_cnf_mode(ConversionMode mode) {
    return (mode == ConversionMode::TSEITIN) ? CNFMode::TSEITIN : CNFMode::STRAIGHTFORWARD;
}

// Constructor
UVL2Dimacs::UVL2Dimacs(bool verbose)
    : verbose_(verbose)
    , mode_(ConversionMode::STRAIGHTFORWARD)
    , use_backbone_(false) {
}

// Destructor
UVL2Dimacs::~UVL2Dimacs() = default;

// Set verbose output mode
void UVL2Dimacs::set_verbose(bool verbose) {
    verbose_ = verbose;
}

// Set conversion mode
void UVL2Dimacs::set_mode(ConversionMode mode) {
    mode_ = mode;
}

// Get current conversion mode
ConversionMode UVL2Dimacs::get_mode() const {
    return mode_;
}

// Set backbone simplification
void UVL2Dimacs::set_backbone_simplification(bool use_backbone) {
    use_backbone_ = use_backbone;
}

// Get backbone simplification status
bool UVL2Dimacs::get_backbone_simplification() const {
    return use_backbone_;
}

// Convert with default mode
ConversionResult UVL2Dimacs::convert(const std::string& input_file,
                                     const std::string& output_file) {
    return convert(input_file, output_file, mode_);
}

// Convert with specified mode
ConversionResult UVL2Dimacs::convert(const std::string& input_file,
                                     const std::string& output_file,
                                     ConversionMode mode) {
    // The 1.x result is the base part of the 2.0 report
    return convert_report(input_file, output_file, mode);
}

ConversionReport UVL2Dimacs::convert_report(const std::string& input_file,
                                            const std::string& output_file,
                                            ConversionMode mode) {
    ConversionReport result;

    try {
        if (verbose_) {
            vp::out() << "Reading UVL file: " << input_file << std::endl;
        }

        // Open the UVL file
        std::ifstream stream(input_file);
        if (!stream.is_open()) {
            result.error_message = "Could not open file: " + input_file;
            return result;
        }

        // Create ANTLR input stream
        ANTLRInputStream input(stream);

        // Create lexer
        UVLCppLexer lexer(&input);

        // Add custom error listener to lexer
        std::string parse_error;
        CustomErrorListener errorListener(parse_error);
        lexer.removeErrorListeners();
        lexer.addErrorListener(&errorListener);

        // Create token stream
        CommonTokenStream tokens(&lexer);

        // Create parser
        UVLCppParser parser(&tokens);
        parser.removeErrorListeners();
        parser.addErrorListener(&errorListener);

        // Parse the feature model
        if (verbose_) {
            vp::out() << "Parsing UVL file..." << std::endl;
        }
        ParseTree* tree = parse_feature_model(parser, parse_error);

        // Check for parse errors
        if (tree == nullptr || !parse_error.empty()) {
            result.error_message = parse_error.empty() ? "Syntax error" : parse_error;
            return result;
        }

        // Build FeatureModel from parse tree
        if (verbose_) {
            vp::out() << "Building feature model..." << std::endl;
        }
        FeatureModelBuilder builder;
        ParseTreeWalker::DEFAULT.walk(&builder, tree);

        auto feature_model = builder.get_feature_model();
        if (!feature_model) {
            result.error_message = "Failed to build feature model";
            return result;
        }
        // The features and relations of a model own each other: release them when this function ends
        struct ModelGuard {
            std::shared_ptr<FeatureModel> model;
            ~ModelGuard() {   // must not throw: an exception from a destructor ends the program
                try { model->release_links(); } catch (...) {}   // out of memory: the model is not freed (as in 1.x)
            }
        } model_guard{feature_model};

        // Store feature model statistics
        result.num_features = feature_model->get_features().size();
        result.num_relations = feature_model->get_relations().size();
        result.num_constraints = feature_model->get_constraints().size();

        if (verbose_) {
            vp::out() << "Feature model built:" << std::endl;
            vp::out() << "  Features: " << result.num_features << std::endl;
            vp::out() << "  Relations: " << result.num_relations << std::endl;
            vp::out() << "  Constraints: " << result.num_constraints << std::endl;
        }

        // Transform to CNF
        if (verbose_) {
            vp::out() << "Transforming to CNF..." << std::endl;
        }
        FMToCNF transformer(feature_model);
        CNFModel cnf_model = transformer.transform(to_cnf_mode(mode));

        // Store CNF statistics
        result.num_variables = cnf_model.get_num_variables();
        result.num_clauses = cnf_model.get_num_clauses();
        result.num_skipped_constraints = transformer.get_skipped_constraints();
        fill_model_report(*feature_model, result);

        if (verbose_) {
            vp::out() << "CNF model created:" << std::endl;
            vp::out() << "  Variables: " << result.num_variables << std::endl;
            vp::out() << "  Clauses: " << result.num_clauses << std::endl;
        }

        // Write DIMACS file
        if (verbose_) {
            vp::out() << "Writing DIMACS file: " << output_file << std::endl;
        }
        DimacsWriter writer(cnf_model);
        writer.write_to_file(output_file);

        // Apply backbone simplification if requested
        if (use_backbone_) {
            if (verbose_) {
                vp::out() << "Applying backbone simplification..." << std::endl;
            }

            std::string backbone_solver_path;   // variplex: BoneDigger is linked in

            // Create temporary file for simplified output
            std::string temp_output = output_file + ".simplified";

            // Apply backbone simplification
            BackboneSimplifier simplifier;
            if (simplifier.simplify(output_file, temp_output, backbone_solver_path, verbose_)) {
                // Replace original file with simplified version
                if (std::rename(temp_output.c_str(), output_file.c_str()) != 0) {
                    if (verbose_) {
                        vp::err() << "Warning: Failed to replace original file with simplified version" << std::endl;
                    }
                    std::remove(temp_output.c_str());
                } else {
                    if (verbose_) {
                        vp::out() << "  Backbone size: " << simplifier.get_backbone_size() << std::endl;
                        vp::out() << "  Removed clauses: " << simplifier.get_removed_clauses() << std::endl;
                        vp::out() << "  Shortened clauses: " << simplifier.get_shortened_clauses() << std::endl;
                    }
                }
            } else {
                if (verbose_) {
                    vp::err() << "Warning: Backbone simplification failed, keeping original output" << std::endl;
                }
                std::remove(temp_output.c_str());
            }
        }

        // Success!
        result.success = true;

        return result;

    } catch (const std::exception& e) {
        result.error_message = e.what();
        return result;
    }
}

// Convert to string with default mode
std::string UVL2Dimacs::convert_to_string(const std::string& input_file,
                                          ConversionResult& result) {
    return convert_to_string(input_file, mode_, result);
}

// Convert to string with specified mode
std::string UVL2Dimacs::convert_to_string(const std::string& input_file,
                                          ConversionMode mode,
                                          ConversionResult& result) {
    try {
        if (verbose_) {
            vp::out() << "Reading UVL file: " << input_file << std::endl;
        }

        // Open the UVL file
        std::ifstream stream(input_file);
        if (!stream.is_open()) {
            result.error_message = "Could not open file: " + input_file;
            return "";
        }

        // Create ANTLR input stream
        ANTLRInputStream input(stream);

        // Create lexer
        UVLCppLexer lexer(&input);

        // Add custom error listener to lexer
        std::string parse_error;
        CustomErrorListener errorListener(parse_error);
        lexer.removeErrorListeners();
        lexer.addErrorListener(&errorListener);

        // Create token stream
        CommonTokenStream tokens(&lexer);

        // Create parser
        UVLCppParser parser(&tokens);
        parser.removeErrorListeners();
        parser.addErrorListener(&errorListener);

        // Parse the feature model
        if (verbose_) {
            vp::out() << "Parsing UVL file..." << std::endl;
        }
        ParseTree* tree = parse_feature_model(parser, parse_error);

        // Check for parse errors
        if (tree == nullptr || !parse_error.empty()) {
            result.error_message = parse_error.empty() ? "Syntax error" : parse_error;
            return "";
        }

        // Build FeatureModel from parse tree
        if (verbose_) {
            vp::out() << "Building feature model..." << std::endl;
        }
        FeatureModelBuilder builder;
        ParseTreeWalker::DEFAULT.walk(&builder, tree);

        auto feature_model = builder.get_feature_model();
        if (!feature_model) {
            result.error_message = "Failed to build feature model";
            return "";
        }
        // The features and relations of a model own each other: release them when this function ends
        struct ModelGuard {
            std::shared_ptr<FeatureModel> model;
            ~ModelGuard() {   // must not throw: an exception from a destructor ends the program
                try { model->release_links(); } catch (...) {}   // out of memory: the model is not freed (as in 1.x)
            }
        } model_guard{feature_model};

        // Store feature model statistics
        result.num_features = feature_model->get_features().size();
        result.num_relations = feature_model->get_relations().size();
        result.num_constraints = feature_model->get_constraints().size();

        // Transform to CNF
        if (verbose_) {
            vp::out() << "Transforming to CNF..." << std::endl;
        }
        FMToCNF transformer(feature_model);
        CNFModel cnf_model = transformer.transform(to_cnf_mode(mode));

        // Store CNF statistics
        result.num_variables = cnf_model.get_num_variables();
        result.num_clauses = cnf_model.get_num_clauses();
        result.num_skipped_constraints = transformer.get_skipped_constraints();
        {
            ConversionReport report;   // prints the typed-feature warning; the 1.x result has no room for the lists
            fill_model_report(*feature_model, report);
        }

        // Get DIMACS string
        DimacsWriter writer(cnf_model);
        std::string dimacs_str = writer.to_dimacs_string();

        // Success!
        result.success = true;

        return dimacs_str;

    } catch (const std::exception& e) {
        result.error_message = e.what();
        return "";
    }
}

} // namespace uvl2dimacs
