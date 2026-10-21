/**
 * @file RunResults.hh
 * @brief The products of a run in the form that the APIs return (internal)
 *
 * Dimacs2GraphsAPI::generate() and strong4vm::Strong4VMAPI::analyze() return the
 * products of the pipeline (core/Pipeline.hh) in the same structure,
 * dimacs2graphs::GraphsResult, and let no exception out. The conversion and the
 * handler of exceptions are written here, once, and compiled into the library:
 * a program that compiles Strong4VMAPI.cc with its own options (another
 * optimisation level, -flto) does not compile them again.
 *
 * An entry point of the API creates its result object, then does all its work
 * inside run_guarded(), then hands the result over with operations that cannot
 * throw. So the creation of the result is the only allocation outside the last
 * line of defence: the JSON value that a result holds allocates when it is
 * created, and if even that fails, std::bad_alloc leaves the call.
 */

#ifndef DIMACS2GRAPHS_RUN_RESULTS_HH
#define DIMACS2GRAPHS_RUN_RESULTS_HH

#include "Dimacs2GraphsAPI.hh"
#include "../core/Pipeline.hh"
#include "../core/Status.hh"

#include <memory>
#include <string>
#include <type_traits>
#include <vector>

namespace dimacs2graphs {

/// @addtogroup ParallelGraphs
/// @{

/**
 * @brief The products of a run of the pipeline as the APIs return them (R-API-02): exit code, message, summary,
 * warnings, files written, the names of the vertices, the three graphs in compressed sparse row form, the core and
 * dead options and the rows of `__variables.csv`.
 */
GraphsResult to_graphs_result(const GenerateResult& g);

/// The global backbone of the formula as signed DIMACS literals: v for a core variable, -v for a dead one.
std::vector<int> backbone_literals(const GenerateResult& g);

/**
 * @brief A reference to a callable that is made without allocating (std::function may allocate, and so throw,
 * before the guard that it is given to). It does not own the callable: it is meant for an argument.
 */
template <class Signature> class FunctionRef;

template <class R> class FunctionRef<R()> {
public:
    template <class F, class = std::enable_if_t<!std::is_same<std::decay_t<F>, FunctionRef>::value>>
    FunctionRef(F&& f) noexcept  // NOLINT: implicit, like std::function
        : object_(const_cast<void*>(static_cast<const void*>(std::addressof(f)))),
          call_([](void* o) -> R { return (*static_cast<std::remove_reference_t<F>*>(o))(); }) {}
    R operator()() const { return call_(object_); }

private:
    void* object_;
    R (*call_)(void*);
};

/**
 * @brief Runs body() and turns an exception that escapes it into an exit code and a message, as the command line
 * reports it: not enough memory is an input error (2), anything else an internal error (4). Every entry point of
 * both APIs runs its work through it, so no exception leaves the library; being compiled into the library, it also
 * spares the programs that compile Strong4VMAPI.cc a handler of their own. Nothing is allocated before body() runs:
 * the text that names the work is made only when an exception has to be reported (and if there is no memory left
 * for it, the message is "out of memory").
 * @param what  makes the text of what was being done, for the message (e.g. "analyse 'model.uvl'")
 * @param code  set when an exception escaped
 * @param error set when an exception escaped
 * @param body  the work
 * @return true if body() returned normally
 */
bool run_guarded(FunctionRef<std::string()> what, ExitCode& code, std::string& error, FunctionRef<void()> body) noexcept;

/// Copies a message without throwing: if there is no memory for the copy, `to` becomes "out of memory".
void copy_message(std::string& to, const std::string& from) noexcept;

/// @}

} // namespace dimacs2graphs

#endif
