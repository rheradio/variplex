/**
 * @file Classifier.hh
 * @brief Classification of every variable of a formula (Sections 5–6 of the 2.0 requirements)
 *
 * Every variable receives exactly one class (VarClass) and one decision
 * (keep, drop, merge candidate, merged) together with the identifier of the
 * rule that decided (R-PRI-03). Classification uses only names (and the set of
 * all names), so it is done once, before solving (R-CLS-01); the abstract
 * group features of TraVarT (rule T2), and with `--abstract merge` the abstract
 * features of a UVL model (rule U4, the root included when it is abstract), are
 * merge candidates that are resolved after solving, with the atomic sets.
 *
 * Order of evaluation (R-FLT-04); the first rule that applies decides:
 *  1. C5, `--keep-pattern`;
 *  2. C6, `--decls`: a declared name is an option; an undeclared variable is
 *     kept only if it encodes a declared option (the module variable of a
 *     tristate, the value variables of a non-Boolean option), in which case
 *     `--tristate` / `--nonbool` decide how that option is represented;
 *  3. the rules of the profile for artificial and special variables;
 *  4. C1–C4;
 *  5. the rules of the profile that keep a name as an option (the "everything
 *     else" rows K6, R6, T3, U5 and the prefix rules S2, S6): they are the
 *     residual, so the common rules C1–C4 hold in every profile and
 *     `--drop-names` / `--drop-pattern` can drop any option;
 *  6. `--unknown-names`.
 *
 * The rules of each profile are kept in tables (see rule_tables()), which
 * also generate docs/filters.md.
 */

#ifndef DIMACS2GRAPHS_CLASSIFIER_HH
#define DIMACS2GRAPHS_CLASSIFIER_HH

#include "../core/Status.hh"
#include "../io/DimacsFormula.hh"
#include "Options.hh"

#include <map>
#include <ostream>
#include <string>
#include <vector>

namespace dimacs2graphs {

/// Classes of variables (Section 5).
enum class VarClass {
    Option, Tseitin, Chain, Visibility, SelectHelper, Placeholder, Module, Choice, Value,
    Bitvector, Environment, AbstractGroup, Root, Abstract, Unnamed, DeclaredOut
};
const char* to_string(VarClass c);

/// What happens to a variable.
enum class Decision {
    Keep,             ///< Is an option: queried and written
    Drop,             ///< Not an option: never queried nor written (remains in the formula)
    MergeCandidate,   ///< Queried; merged after solving if it is equivalent to an option (T2)
    Merged            ///< Represented by another node (merged_into)
};

struct VarInfo {
    VarClass cls = VarClass::Option;
    Decision decision = Decision::Keep;
    std::string rule;             ///< Rule identifier, e.g. "K3" or "R-FLT-11"
    std::string output_name;      ///< Name after normalisation (R-FLT-19)
    int merged_into = 0;          ///< Variable that represents this one (Decision::Merged)
    std::string marker;           ///< Marker in __atomic.txt: "abstract-group", "abstract", "tristate", "nonbool"
    bool synthetic = false;       ///< Fresh variable added by a formula transformation
    bool unknown = false;         ///< Decided by --unknown-names
};

/// How the profile was chosen (R-FLT-02, R-FLT-03).
struct ProfileDetection {
    Translator profile = Translator::Generic;
    std::string how;        ///< "option", "extension", "header", "file-name", "content", "default"
    std::string evidence;   ///< Human-readable evidence
    bool weak = false;      ///< Weak evidence (R-ERR-04: warning)
};

/// Result of classification.
struct Classification {
    ProfileDetection detection;
    UnknownNames unknown_policy = UnknownNames::Keep;   ///< Effective --unknown-names
    std::vector<VarInfo> vars;                          ///< Index 1..num_vars (grows with merges)
    std::vector<std::string> warnings;

    // Formula transformations requested by the classification (R-FLT-10, R-FLT-11)
    std::vector<std::pair<int, int>> tristate_pairs;    ///< (X, X_MODULE)
    struct NonBool { std::string option; int not_set_var = 0; std::vector<int> values; };
    std::vector<NonBool> nonbool_options;               ///< Detected non-Boolean options (R-FLT-10)
    std::vector<std::string> nonbool_without_n;         ///< NB options without P_n (no node under merge)
    long tristate_merged = 0;                           ///< Tristate pairs merged by apply_merges
    long nonbool_merged = 0;                            ///< Non-Boolean options that got a node in apply_merges

    // --decls (R-FLT-18)
    bool decls_given = false;
    std::vector<std::string> declared_not_found;        ///< Declared names absent from the formula
    std::vector<std::string> declared_encoded;          ///< Declared non-Boolean options present only as value/bit variables
    std::vector<std::string> undeclared_nonbool;        ///< Non-Boolean options of the formula that are not declared
    long dropped_only_by_decls = 0;                     ///< Variables that are DECLARED_OUT and would otherwise be kept

    // --unknown-names keep (R-ERR-04)
    long unknown_kept = 0;
    std::vector<std::string> unknown_examples;

    ExitCode code = ExitCode::Success;
    std::string error;
};

/// Inputs of the classification besides the formula.
struct ClassifyContext {
    bool input_is_uvl = false;     ///< The user's input was a .uvl file
    std::string input_path;        ///< The user's input path (for detection by file name)
};

/// Detects the translator profile (R-FLT-02).
ProfileDetection detect_profile(const DimacsFormula& f, const ClassifyContext& ctx);

/**
 * @brief Classifies every variable and normalises names (R-FLT-04, R-FLT-19).
 * Does not modify the formula; merges are applied by apply_merges().
 */
Classification classify(const DimacsFormula& f, const FilterOptions& o, const ClassifyContext& ctx);

/**
 * @brief Applies the formula transformations of --tristate merge (R-FLT-11)
 * and --nonbool merge (R-FLT-10): adds one fresh defined variable (and its
 * clauses) per tristate pair / non-Boolean option with a "not set" variable,
 * and marks the original variables as merged into it. The set of
 * configurations is unchanged.
 * @return number of fresh variables added
 */
int apply_merges(DimacsFormula& f, Classification& c, const FilterOptions& o);

/**
 * @brief Normalised output name of a variable name (R-FLT-19), without collision handling.
 * The type prefixes `boolean_` and `tristate_` are stripped only in the profile
 * kconfigsampler (unless keep_type_prefix); `CONFIG_` only with strip_config_prefix.
 */
std::string normalise_name(const std::string& name, const FilterOptions& o, Translator profile);

/// One row of the documentation of a rule.
struct RuleDoc {
    std::string profile;     ///< "common", "kmax", …
    std::string id;          ///< "K3"
    std::string condition;   ///< Pattern or condition
    std::string cls;         ///< Class
    std::string action;      ///< Default action and governing option
};

/// Every rule of every profile, in evaluation order (source of docs/filters.md).
std::vector<RuleDoc> rule_tables();

/// One row of the documentation of a class (Section 5).
struct ClassDoc {
    VarClass cls;
    std::string meaning;
    std::string kept;        ///< Kept by default, and the governing option
};

/// Every class of variable, in the order of Section 5 (source of docs/filters.md).
std::vector<ClassDoc> class_tables();

/// Writes docs/filters.md (R-IMP-05).
void write_rules_markdown(std::ostream& out);

} // namespace dimacs2graphs

#endif
