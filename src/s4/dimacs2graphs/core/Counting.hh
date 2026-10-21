/**
 * @file Counting.hh
 * @brief How much of the formula the graphs leave out, measured with a model counter (`--representativeness`)
 *
 * The results of a run are a formula whose clauses have one or two literals (core and dead features, arrows, red and
 * green lines): every product satisfies it, and it lets pass some choices that are not products. The share of the
 * choices that the graphs let pass that are products is the number of configurations of the formula, counted over the
 * features that are dots of the graphs, divided by the number of choices of those features that the graphs let pass.
 * Both are counted with GANAK (https://github.com/meelgroup/ganak), a \#SAT solver run as a program; the first count is a
 * projected count, since the formula has other variables (helpers of a translation, abstract features).
 */

#ifndef DIMACS2GRAPHS_COUNTING_HH
#define DIMACS2GRAPHS_COUNTING_HH

#include "../io/DimacsFormula.hh"
#include "../io/OutputFiles.hh"

#include <string>
#include <vector>

namespace dimacs2graphs {

/// The two counts and their ratio.
struct Representativeness {
    std::string configurations;   ///< Configurations of the formula, over the dots of the graphs (decimal, may be very large)
    std::string graph_choices;    ///< Choices of the same features that the graphs let pass (decimal)
    double share = 0;             ///< configurations / graph_choices, between 0 and 1
    std::vector<std::string> files;  ///< The two formulas written for the counter
};

/**
 * @brief Writes `<base>__count_formula.cnf` (the formula, with a line `c p show` that names the variables of the dots)
 * and `<base>__count_graphs.cnf` (the results as a formula over the dots), runs the counter on each and divides.
 * @param f         the formula as it was solved (with the variables that merges add)
 * @param node_var  variable of each dot, by node id - 1 (0 for a declared name that the formula does not have)
 * @param core      core features (their node ids are 0 unless they are dots)
 * @param dead      dead features (their node ids are 0 unless they are dots)
 * @param arcs      arrows of the requires graph, in node ids
 * @param excludes  red lines of the excludes graph, in node ids
 * @param atleastone green lines of the at-least-one graph, in node ids
 * @param base      path prefix of the output files
 * @param counter   the GANAK program (a path, or a name looked up on the PATH)
 * @param r         receives the two counts, their ratio and the files written
 * @param error     receives the reason when the function returns false
 * @return false with `error` when a file cannot be written or the counter cannot be run or gives no count
 */
bool measure_representativeness(const DimacsFormula& f, const std::vector<int>& node_var, const std::vector<ListedNode>& core,
                                const std::vector<ListedNode>& dead, const std::vector<Link>& arcs,
                                const std::vector<Link>& excludes, const std::vector<Link>& atleastone,
                                const std::string& base, const std::string& counter, Representativeness& r, std::string& error);

/// The ratio of two non-negative integers written in decimal (accurate to about 15 digits).
double decimal_ratio(const std::string& numerator, const std::string& denominator);

} // namespace dimacs2graphs

#endif
