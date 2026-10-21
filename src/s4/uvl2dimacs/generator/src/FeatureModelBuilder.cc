#include "vp_io.h"  // added by variplex (tools/sync_cpp.R)
/**
 * @file FeatureModelBuilder.cc
 * @brief Implementation of ANTLR listener for building feature models from UVL
 *
 * This file implements the FeatureModelBuilder class which is an ANTLR4 parse
 * tree listener that constructs a FeatureModel from UVL source code during parsing.
 *
 * The builder uses two primary data structures:
 * - **feature_stack**: Stack of features being constructed (for hierarchy)
 * - **ast_stack**: Stack of AST nodes for constraint expressions
 *
 * The listener pattern works as follows:
 * 1. Parser invokes enter/exit methods for each grammar rule
 * 2. Builder accumulates features and relations during tree traversal
 * 3. After parsing completes, get_feature_model() returns the complete model
 *
 * Key responsibilities:
 * - Building feature tree hierarchy with parent-child relations
 * - Parsing cardinality specifications ([min..max])
 * - Converting constraint expressions to AST nodes
 * - Handling all relation types (MANDATORY, OPTIONAL, OR, ALTERNATIVE, CARDINALITY)
 *
 * @author UVL2Dimacs Team
 * @date 2024
 */

#include "FeatureModelBuilder.hh"
#include <iostream>
#include <stdexcept>
#include <algorithm>

namespace {
/// Why a constraint that the parser could not turn into an expression is left out (R-UVL-03)
const char* const NOT_PARSED = "it could not be parsed (it likely contains unsupported constructs such as aggregate functions, "
                               "attribute access, or typed feature references)";

/// The text of a constraint as written in the file, with its original spacing, and its line
std::pair<std::string, int> source_of(antlr4::ParserRuleContext* c) {
    std::string text = c->getText();
    int line = 0;
    if (c->getStart()) {
        line = static_cast<int>(c->getStart()->getLine());
        if (c->getStop() && c->getStart()->getInputStream())
            text = c->getStart()->getInputStream()->getText(
                antlr4::misc::Interval(c->getStart()->getStartIndex(), c->getStop()->getStopIndex()));
    }
    return {text, line};
}
}  // namespace

/**
 * @brief Constructs a new feature model builder
 *
 * Initializes the builder with empty stacks and counters.
 * The feature model will be built during ANTLR parsing.
 */
FeatureModelBuilder::FeatureModelBuilder()
    : feature_model(nullptr), current_feature(nullptr), constraint_counter(0) {
}

/**
 * @brief Called when exiting the features section
 *
 * Finalizes the feature tree by popping the root feature from the stack
 * and creating the FeatureModel object.
 *
 * @param ctx Parse tree context for the features section
 */
void FeatureModelBuilder::exitFeatures(UVLCppParser::FeaturesContext *ctx) {
    // The root feature should be on the stack
    if (!feature_stack.empty()) {
        auto root = feature_stack.top();
        feature_model = std::make_shared<FeatureModel>(root);
        feature_stack.pop();
    }
    if (feature_model) {   // what was read with the features: constraints written as attributes, feature cardinalities
        for (auto& c : attribute_constraints) feature_model->add_constraint(c);
        for (const auto& sc : attribute_skipped) feature_model->add_skipped_constraint(sc.text, sc.line, sc.reason);
        for (const auto& fc : feature_cardinalities) feature_model->add_feature_cardinality(fc.feature, fc.bounds, fc.line);
    }
    attribute_constraints.clear();
    attribute_skipped.clear();
    feature_cardinalities.clear();
}

void FeatureModelBuilder::exitSingleConstraintAttribute(UVLCppParser::SingleConstraintAttributeContext *ctx) {
    collect_attribute_constraints({ctx->constraint()});
}

void FeatureModelBuilder::exitListConstraintAttribute(UVLCppParser::ListConstraintAttributeContext *ctx) {
    if (ctx->constraintList()) collect_attribute_constraints(ctx->constraintList()->constraint());
}

void FeatureModelBuilder::collect_attribute_constraints(const std::vector<UVLCppParser::ConstraintContext*>& constraints) {
    // The walk of the model has already passed through these constraints and left their expressions on the stack:
    // nothing else is on it while the features are read. Each constraint is read again on its own, so that one that
    // cannot be parsed does not take the others of a list with it.
    while (!ast_stack.empty()) ast_stack.pop();
    current_constraint_failed = false;
    for (auto* c : constraints) {
        if (!c) continue;
        FeatureModelBuilder one;
        antlr4::tree::ParseTreeWalker::DEFAULT.walk(&one, c);
        auto [text, line] = source_of(c);
        if (one.current_constraint_failed || one.ast_stack.size() != 1) {
            attribute_skipped.push_back({text, line, NOT_PARSED});
            vp::err() << "Warning: line " << line << ": constraint \"" << text << "\" was skipped: " << NOT_PARSED << "."
                      << std::endl;
            continue;
        }
        auto constraint = std::make_shared<Constraint>("Constraint_" + std::to_string(constraint_counter++), one.ast_stack.top());
        constraint->set_source(text, line);
        attribute_constraints.push_back(constraint);
    }
}

/**
 * @brief Called when entering a feature definition
 *
 * Creates a new Feature object and pushes it onto the stack for processing.
 * The feature will be linked to its parent when the parent's relation is processed.
 *
 * @param ctx Parse tree context containing feature name
 */
void FeatureModelBuilder::enterFeature(UVLCppParser::FeatureContext *ctx) {
    // Get feature name
    std::string feature_name = get_reference_name(ctx->reference());

    // Create new feature
    auto feature = std::make_shared<Feature>(feature_name);

    // Feature cardinality (`Strap cardinality [1..2]`): encoded as one feature, as its group says; reported
    if (auto* fc = ctx->featureCardinality()) {
        feature_cardinalities.push_back({feature_name, fc->CARDINALITY() ? fc->CARDINALITY()->getText() : fc->getText(),
                                         ctx->getStart() ? static_cast<int>(ctx->getStart()->getLine()) : 0});
    }

    // Type (R-UVL-06): Integer, String and Real features are encoded by their presence only
    if (auto* t = ctx->featureType()) {
        if (t->INTEGER_KEY()) feature->set_type("Integer");
        else if (t->STRING_KEY()) feature->set_type("String");
        else if (t->REAL_KEY()) feature->set_type("Real");
    }

    // Attribute abstract (R-UVL-05): {abstract} or {abstract true}
    if (auto* attrs = ctx->attributes()) {
        for (auto* a : attrs->attribute()) {
            auto* va = a->valueAttribute();
            if (!va || !va->key()) continue;
            std::string key = va->key()->getText();
            if (key.size() >= 2 && key.front() == '"' && key.back() == '"') key = key.substr(1, key.size() - 2);
            if (key != "abstract") continue;
            bool value = true;
            if (va->value()) value = va->value()->BOOLEAN() && va->value()->getText() == "true";
            feature->set_abstract(value);
        }
    }

    // Push to stack for processing
    feature_stack.push(feature);
    current_feature = feature;
}

/**
 * @brief Called when exiting a feature definition
 *
 * Marks the current feature as complete. The feature remains on the stack
 * until its parent's relation processing collects it as a child.
 *
 * @param ctx Parse tree context for the feature
 */
void FeatureModelBuilder::exitFeature(UVLCppParser::FeatureContext *ctx) {
    // Current feature is complete
    // Keep it on stack until parent processes it
    current_feature = nullptr;
}

/**
 * @brief Processes OR group: parent → (at least one child)
 * @param ctx Parse tree context for the OR group
 */
void FeatureModelBuilder::exitOrGroup(UVLCppParser::OrGroupContext *ctx) {
    auto children = collect_children(ctx->groupSpec());

    if (!children.empty() && !feature_stack.empty()) {
        // Get the parent feature (should be on top of stack)
        auto parent = feature_stack.top();

        // Create Or relation: [1..N]
        int num_children = children.size();
        parent->add_relation(children, 1, num_children);
    }
}

/**
 * @brief Processes ALTERNATIVE group: parent → (exactly one child)
 * @param ctx Parse tree context for the alternative group
 */
void FeatureModelBuilder::exitAlternativeGroup(UVLCppParser::AlternativeGroupContext *ctx) {
    auto children = collect_children(ctx->groupSpec());

    if (!children.empty() && !feature_stack.empty()) {
        auto parent = feature_stack.top();

        // Create Alternative relation: [1..1]
        parent->add_relation(children, 1, 1);
    }
}

/**
 * @brief Processes OPTIONAL group: each child → parent (optional selection)
 * @param ctx Parse tree context for the optional group
 */
void FeatureModelBuilder::exitOptionalGroup(UVLCppParser::OptionalGroupContext *ctx) {
    auto children = collect_children(ctx->groupSpec());

    if (!feature_stack.empty()) {
        auto parent = feature_stack.top();

        // Create Optional relations: [0..1] for each child
        for (auto& child : children) {
            parent->add_relation({child}, 0, 1);
        }
    }
}

/**
 * @brief Processes MANDATORY group: each child ⟺ parent (required selection)
 * @param ctx Parse tree context for the mandatory group
 */
void FeatureModelBuilder::exitMandatoryGroup(UVLCppParser::MandatoryGroupContext *ctx) {
    auto children = collect_children(ctx->groupSpec());

    if (!feature_stack.empty()) {
        auto parent = feature_stack.top();

        // Create Mandatory relations: [1..1] for each child
        for (auto& child : children) {
            parent->add_relation({child}, 1, 1);
        }
    }
}

/**
 * @brief Processes CARDINALITY group: parent → (min..max children selected)
 * @param ctx Parse tree context containing cardinality specification
 */
void FeatureModelBuilder::exitCardinalityGroup(UVLCppParser::CardinalityGroupContext *ctx) {
    auto children = collect_children(ctx->groupSpec());

    if (!children.empty() && !feature_stack.empty()) {
        auto parent = feature_stack.top();

        // Parse cardinality
        std::string cardinality_text = ctx->CARDINALITY()->getText();
        auto [card_min, card_max] = parse_cardinality(cardinality_text);

        // Create Cardinality relation
        parent->add_relation(children, card_min, card_max);
    }
}

/**
 * @brief Finalizes a constraint line by creating a Constraint object
 *
 * Pops the completed AST from ast_stack and creates a Constraint with a
 * unique name. The constraint is added to the feature model.
 *
 * @param ctx Parse tree context for the constraint line
 */
void FeatureModelBuilder::enterConstraintLine(UVLCppParser::ConstraintLineContext *ctx) {
    current_constraint_failed = false;
    while (!ast_stack.empty()) ast_stack.pop();
}

void FeatureModelBuilder::exitConstraintLine(UVLCppParser::ConstraintLineContext *ctx) {
    // Source text (with its original spacing) and line, for messages (R-UVL-03)
    auto [text, line] = ctx->constraint() ? source_of(ctx->constraint()) : source_of(ctx);
    if (ctx->getStart()) line = static_cast<int>(ctx->getStart()->getLine());
    if (current_constraint_failed || ast_stack.empty()) {
        while (!ast_stack.empty()) ast_stack.pop();
        if (current_constraint_failed) {
            if (feature_model) feature_model->add_skipped_constraint(text, line, NOT_PARSED);
            vp::err() << "Warning: line " << line << ": constraint \"" << text << "\" was skipped: " << NOT_PARSED << "."
                      << std::endl;
        }
        return;
    }

    if (feature_model) {
        auto ast = ast_stack.top();
        ast_stack.pop();

        std::string constraint_name = "Constraint_" + std::to_string(constraint_counter++);
        auto constraint = std::make_shared<Constraint>(constraint_name, ast);
        constraint->set_source(text, line);
        feature_model->add_constraint(constraint);
    }
}

/**
 * @brief Handles literal (feature name) in constraints
 * @param ctx Parse tree context containing the feature reference
 */
void FeatureModelBuilder::exitLiteralConstraint(UVLCppParser::LiteralConstraintContext *ctx) {
    std::string literal = get_reference_name(ctx->reference());
    ast_stack.push(std::make_shared<ASTNode>(literal));
}

/**
 * @brief Handles NOT operation in constraints
 * @param ctx Parse tree context for NOT operation
 * @throws std::runtime_error if AST stack is empty
 */
#define FAIL_CONSTRAINT(n) \
    do { current_constraint_failed = true; \
         while (!ast_stack.empty()) ast_stack.pop(); \
         return; } while(0)

#define REQUIRE_STACK(n) \
    if ((int)ast_stack.size() < (n)) { FAIL_CONSTRAINT(n); }

void FeatureModelBuilder::exitNotConstraint(UVLCppParser::NotConstraintContext *ctx) {
    REQUIRE_STACK(1);
    auto operand = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::NOT, operand));
}

void FeatureModelBuilder::exitAndConstraint(UVLCppParser::AndConstraintContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::AND, left, right));
}

void FeatureModelBuilder::exitOrConstraint(UVLCppParser::OrConstraintContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::OR, left, right));
}

void FeatureModelBuilder::exitImplicationConstraint(UVLCppParser::ImplicationConstraintContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::IMPLIES, left, right));
}

void FeatureModelBuilder::exitEquivalenceConstraint(UVLCppParser::EquivalenceConstraintContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::EQUIVALENCE, left, right));
}

void FeatureModelBuilder::exitParenthesisConstraint(UVLCppParser::ParenthesisConstraintContext *ctx) {
    // child is already on the stack
}

void FeatureModelBuilder::exitEquationConstraint(UVLCppParser::EquationConstraintContext *ctx) {
    // equation node is already on the stack from the exitXxxEquation handler
}

void FeatureModelBuilder::exitEqualEquation(UVLCppParser::EqualEquationContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::EQUALS, left, right));
}

void FeatureModelBuilder::exitLowerEquation(UVLCppParser::LowerEquationContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::LOWER, left, right));
}

void FeatureModelBuilder::exitGreaterEquation(UVLCppParser::GreaterEquationContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::GREATER, left, right));
}

void FeatureModelBuilder::exitLowerEqualsEquation(UVLCppParser::LowerEqualsEquationContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::LOWER_EQUALS, left, right));
}

void FeatureModelBuilder::exitGreaterEqualsEquation(UVLCppParser::GreaterEqualsEquationContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::GREATER_EQUALS, left, right));
}

void FeatureModelBuilder::exitNotEqualsEquation(UVLCppParser::NotEqualsEquationContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::NOT_EQUALS, left, right));
}

void FeatureModelBuilder::exitAddExpression(UVLCppParser::AddExpressionContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::ADD, left, right));
}

void FeatureModelBuilder::exitSubExpression(UVLCppParser::SubExpressionContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::SUB, left, right));
}

void FeatureModelBuilder::exitMulExpression(UVLCppParser::MulExpressionContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::MUL, left, right));
}

void FeatureModelBuilder::exitDivExpression(UVLCppParser::DivExpressionContext *ctx) {
    REQUIRE_STACK(2);
    auto right = ast_stack.top(); ast_stack.pop();
    auto left  = ast_stack.top(); ast_stack.pop();
    ast_stack.push(std::make_shared<ASTNode>(ASTOperation::DIV, left, right));
}

#undef REQUIRE_STACK
#undef FAIL_CONSTRAINT

void FeatureModelBuilder::exitFloatLiteralExpression(UVLCppParser::FloatLiteralExpressionContext *ctx) {
    double value = std::stod(ctx->FLOAT()->getText());
    ast_stack.push(std::make_shared<ASTNode>(value));
}

void FeatureModelBuilder::exitIntegerLiteralExpression(UVLCppParser::IntegerLiteralExpressionContext *ctx) {
    int value = std::stoi(ctx->INTEGER()->getText());
    ast_stack.push(std::make_shared<ASTNode>(value));
}

void FeatureModelBuilder::exitStringLiteralExpression(UVLCppParser::StringLiteralExpressionContext *ctx) {
    std::string value = ctx->STRING()->getText();
    // Remove quotes
    if (value.length() >= 2 && value.front() == '\'' && value.back() == '\'') {
        value = value.substr(1, value.length() - 2);
    }
    ast_stack.push(std::make_shared<ASTNode>(value));
}

void FeatureModelBuilder::exitLiteralExpression(UVLCppParser::LiteralExpressionContext *ctx) {
    std::string literal = get_reference_name(ctx->reference());
    ast_stack.push(std::make_shared<ASTNode>(literal));
}

std::pair<int, int> FeatureModelBuilder::parse_cardinality(const std::string& cardinality_text) {
    // Remove brackets: "[1..3]" -> "1..3"
    std::string text = cardinality_text.substr(1, cardinality_text.length() - 2);

    int min_val, max_val;

    // Find ".."
    size_t dot_pos = text.find("..");
    if (dot_pos != std::string::npos) {
        // Range format: "1..3" or "1..*"
        std::string min_str = text.substr(0, dot_pos);
        std::string max_str = text.substr(dot_pos + 2);

        min_val = std::stoi(min_str);

        if (max_str == "*") {
            max_val = -1;  // Unbounded
        } else {
            max_val = std::stoi(max_str);
        }
    } else {
        // Single value: "[3]" means exactly 3
        min_val = std::stoi(text);
        max_val = min_val;
    }

    return {min_val, max_val};
}

std::string FeatureModelBuilder::get_reference_name(UVLCppParser::ReferenceContext *ctx) {
    std::string name = ctx->getText();

    // Remove quotes if present
    if (name.length() >= 2 && name.front() == '"' && name.back() == '"') {
        name = name.substr(1, name.length() - 2);
    }

    return name;
}

std::vector<std::shared_ptr<Feature>> FeatureModelBuilder::collect_children(
    UVLCppParser::GroupSpecContext *ctx) {

    std::vector<std::shared_ptr<Feature>> children;

    // Get all feature contexts from groupSpec
    auto feature_contexts = ctx->feature();

    // Pop children from stack (they were pushed in reverse order)
    std::vector<std::shared_ptr<Feature>> temp;
    for (size_t i = 0; i < feature_contexts.size(); ++i) {
        if (!feature_stack.empty()) {
            // Peek at top to see if it matches
            auto top = feature_stack.top();
            temp.push_back(top);
            feature_stack.pop();
        }
    }

    // Reverse to get correct order
    std::reverse(temp.begin(), temp.end());
    children = temp;

    return children;
}
