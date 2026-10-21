/**
 * @file FeatureModel.hh
 * @brief Complete feature model representation
 *
 * This file defines the FeatureModel class which represents a complete UVL feature model
 * including the feature tree hierarchy, relations, and cross-tree constraints.
 *
 * @author UVL2Dimacs Team
 * @date 2024
 */

#ifndef FEATUREMODEL_H
#define FEATUREMODEL_H

#include "Feature.hh"
#include "Constraint.hh"
#include <string>
#include <vector>
#include <memory>
#include <map>

/**
 * @class FeatureModel
 * @brief Represents a complete UVL feature model
 *
 * A FeatureModel contains all elements of a UVL variability model:
 *
 * - **Feature Tree**: Hierarchical tree of features starting from a root
 * - **Relations**: Parent-child relationships with cardinality constraints
 * - **Cross-tree Constraints**: Propositional constraints spanning multiple features
 *
 * The feature model represents the variability space of a software product line,
 * where each valid configuration corresponds to a selection of features that
 * satisfies all relations and constraints.
 *
 * **Key Components**:
 * - Root feature: The top-level feature (always selected)
 * - Feature tree: Hierarchical structure of features
 * - Constraints: Additional logical constraints between features
 * - Feature map: Fast lookup cache for finding features by name
 *
 * @see Feature for individual feature nodes
 * @see Relation for parent-child relationships
 * @see Constraint for cross-tree constraints
 * @see FMToCNF for converting to CNF
 *
 * Example:
 * @code
 * auto root = std::make_shared<Feature>("Car");
 * auto model = std::make_shared<FeatureModel>(root);
 * auto engine = std::make_shared<Feature>("Engine");
 * root->add_relation({engine}, 1, 1);  // Mandatory
 * model->build_feature_map();
 * @endcode
 */
class FeatureModel {
public:
    /// @brief A constraint that was not translated (R-UVL-03)
    struct SkippedConstraint {
        std::string text;    ///< Source text
        int line;            ///< Line in the UVL file
        std::string reason;  ///< Why it was skipped
    };

    /// @brief A feature declared with a feature cardinality (`Strap cardinality [1..2]`): it is encoded as one feature,
    /// mandatory or optional as its group says, and the number of its copies is not represented
    struct FeatureCardinality {
        std::string feature;  ///< Name of the feature
        std::string bounds;   ///< The cardinality as written, e.g. "[1..2]"
        int line;             ///< Line in the UVL file
    };

private:
    std::shared_ptr<Feature> root;                            ///< Root feature of the tree
    std::vector<std::shared_ptr<Constraint>> constraints;     ///< Cross-tree constraints
    std::vector<SkippedConstraint> skipped_constraints;       ///< Constraints not translated
    std::vector<FeatureCardinality> feature_cardinalities;    ///< Features with a feature cardinality

    std::map<std::string, std::shared_ptr<Feature>> feature_map;  ///< Feature name lookup cache

public:
    /**
     * @brief Constructs a feature model with the given root feature
     *
     * @param root_feature The root feature of the feature tree
     */
    explicit FeatureModel(std::shared_ptr<Feature> root_feature);

    /**
     * @brief Destructor
     */
    ~FeatureModel() = default;

    /**
     * @brief Gets the root feature
     * @return Shared pointer to the root feature
     */
    std::shared_ptr<Feature> get_root() const { return root; }

    /**
     * @brief Gets all cross-tree constraints
     * @return Constant reference to the constraints vector
     */
    const std::vector<std::shared_ptr<Constraint>>& get_constraints() const { return constraints; }

    /**
     * @brief Adds a cross-tree constraint to the model
     *
     * @param constraint Shared pointer to the constraint to add
     */
    void add_constraint(std::shared_ptr<Constraint> constraint);

    /// @brief Records a skipped constraint
    void add_skipped_constraint(const std::string& text, int line, const std::string& reason) {
        skipped_constraints.push_back({text, line, reason});
    }

    /// @brief Constraints that were skipped (not parsed, or not purely Boolean)
    const std::vector<SkippedConstraint>& get_skipped_constraints() const { return skipped_constraints; }

    /// @brief Records a feature declared with a feature cardinality
    void add_feature_cardinality(const std::string& feature, const std::string& bounds, int line) {
        feature_cardinalities.push_back({feature, bounds, line});
    }

    /// @brief Features declared with a feature cardinality, in the order of the file
    const std::vector<FeatureCardinality>& get_feature_cardinalities() const { return feature_cardinalities; }

    /**
     * @brief Gets all features in the model
     *
     * Performs a depth-first traversal of the feature tree to collect
     * all features.
     *
     * @return Vector of all features in the tree
     */
    std::vector<std::shared_ptr<Feature>> get_features() const;

    /**
     * @brief Breaks the ownership cycles between features and relations
     *
     * Features and relations hold shared pointers to each other, so a model was never freed when its
     * owner went away: every conversion leaked its whole model. Call this when the model is no longer
     * needed; afterwards only the root and the name table remain usable.
     */
    void release_links() {
        std::vector<std::shared_ptr<Feature>> all = get_features();   // keeps them alive while the links go
        for (auto& f : all) f->release_links();
    }

    /**
     * @brief Gets all relations in the model
     *
     * Collects all parent-child relations from all features in the tree.
     *
     * @return Vector of all relations
     */
    std::vector<std::shared_ptr<Relation>> get_relations() const;

    /**
     * @brief Finds a feature by name
     *
     * Uses the feature map cache for fast lookup. If the feature map hasn't
     * been built, this method will build it first.
     *
     * @param name The name of the feature to find
     * @return Shared pointer to the feature, or nullptr if not found
     *
     * @see build_feature_map()
     */
    std::shared_ptr<Feature> find_feature(const std::string& name);

    /**
     * @brief Builds the feature name lookup cache
     *
     * Traverses the feature tree and creates a map from feature names to
     * feature objects for fast lookup. Should be called after the model
     * construction is complete.
     *
     * @note This is automatically called by find_feature() if needed
     */
    void build_feature_map();

    /**
     * @brief Creates a string representation of the feature model
     *
     * Includes the feature tree structure and all constraints.
     *
     * @return String representation for debugging
     */
    std::string to_string() const;

private:
    /**
     * @brief Helper method to recursively collect features
     *
     * Performs depth-first traversal to collect all features in the tree.
     *
     * @param feature Current feature being processed
     * @param features Output vector to append features to
     */
    void collect_features(std::shared_ptr<Feature> feature,
                         std::vector<std::shared_ptr<Feature>>& features) const;

    /**
     * @brief Helper method to recursively build feature map
     *
     * Traverses the tree and adds each feature to the feature map.
     *
     * @param feature Current feature being processed
     */
    void build_feature_map_recursive(std::shared_ptr<Feature> feature);
};

#endif // FEATUREMODEL_H
