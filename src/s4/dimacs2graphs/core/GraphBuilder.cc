#include "vp_io.h"  // added by variplex (tools/sync_cpp.R)
/**
 * @file GraphBuilder.cc
 * @brief Global backbone and main loop of graph generation (see GraphBuilder.hh)
 */

#include "GraphBuilder.hh"
#include "Mig.hh"
#include "../../uvl2dimacs/backbone_solver/src/api/BoneDiggerAPI.hh"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdio>
#include <iostream>
#include <memory>
#include <mutex>
#include <thread>

namespace dimacs2graphs {

using bonedigger::BoneDiggerAPI;
using Solve = BoneDiggerAPI::SolveStatus;

int hardware_threads() {
    unsigned n = std::thread::hardware_concurrency();
    return n == 0 ? 1 : static_cast<int>(n);
}

ExitCode compute_global_backbone(const DimacsFormula& f, const std::string& detector,
                                 GlobalBackbone& bb, std::string& error) {
    bb = GlobalBackbone();
    bb.status.assign(f.num_vars + 1, VarStatus::Variable);
    // Whatever the detector of the main loop, the global backbone is computed by BoneDigger's rush-and-pray
    // detector on Glucose 3.0 with attention weight 1 (`bonedigger -r -a 1 -s 'glucose 3.0'`). The name is still
    // checked, so that an unknown detector is reported here as before.
    BoneDiggerAPI api;
    if (!api.load_formula(f.num_vars, f.clauses) || !api.create_backbone_detector(detector) ||
        !api.create_backbone_detector("rush")) {
        error = "the solver could not load the formula '" + f.path + "' with the detector '" + detector +
                "'. Use the detector 'one' (default) or 'rush'.";
        return ExitCode::Solver;
    }
    Solve s = api.compute_backbone(bb.literals);
    if (s == Solve::Error) {
        error = "the solver failed while computing the global backbone of '" + f.path +
                "'. This is an internal error: please report it with the input file.";
        return ExitCode::Solver;
    }
    if (s == Solve::Unsat) {
        bb.satisfiable = false;
        return ExitCode::VoidModel;
    }
    bb.satisfiable = true;
    for (int lit : bb.literals) bb.status[std::abs(lit)] = lit > 0 ? VarStatus::Core : VarStatus::Dead;
    return ExitCode::Success;
}

namespace {

struct Worker {
    std::unique_ptr<BoneDiggerAPI> api;
    std::vector<Link> req, exc, alo, implied;
    long long calls = 0;
    // With the modal implication graph
    std::unique_ptr<MigScratch> scratch;
    std::unique_ptr<WitnessPool> pool;
    MigJob job;
    std::vector<int> candidates, found;
    std::vector<char> flags;
    std::vector<std::vector<char>> models;
    MigStats stats;
};

using Clock = std::chrono::steady_clock;

double seconds_between(Clock::time_point a, Clock::time_point b) {
    return std::chrono::duration<double>(b - a).count();
}

std::string var_label(const DimacsFormula& f, int v) {
    return f.has_name(v) ? "'" + f.names[v] + "' (variable " + std::to_string(v) + ")"
                         : "variable " + std::to_string(v);
}

}  // namespace

GraphBuildResult build_graphs(const DimacsFormula& f, const GlobalBackbone& bb,
                              const std::vector<int>& query_in, const GraphBuildOptions& opts) {
    GraphBuildResult r;
    std::vector<int> query = query_in;
    std::sort(query.begin(), query.end());

    const int n = f.num_vars;
    std::vector<char> in_query(n + 1, 0);
    for (int v : query) in_query[v] = 1;

    int hw = hardware_threads();
    int threads = std::max(1, opts.threads);
    if (threads > hw) {
        r.warnings.push_back("requested " + std::to_string(threads) + " threads but only " + std::to_string(hw) +
                             " cores are available; using " + std::to_string(hw) + " threads.");
        threads = hw;
    }
    threads = std::max(1, std::min<int>(threads, static_cast<int>(query.size())));
    r.threads_used = query.empty() ? 0 : threads;
    if (query.empty()) return r;

    // The global backbone is given to every worker (R-PERF-03) in two ways. As unit clauses, which leave the
    // set of configurations unchanged and let the solver propagate the fixed values at once. And through the
    // set of candidates: only the queried variables are candidates of the backbone under an assumption, so
    // the variables that are already fixed, and the dropped ones, which are never reported (R-PIPE-02), cost
    // no solver call.
    std::vector<std::vector<int>> clauses = f.clauses;
    for (int lit : bb.literals) clauses.push_back({lit});

    // With the default detector, each worker keeps one solver (Glucose 3.0) for all its calls (R-OR-04): the two
    // calls for a variable, and the calls for the following variables, reuse it and what it has learned. The
    // detector "rush" (and "flatland", now an alias of it) adds clauses of its own to the solver, so it gets a new
    // one for every call.
    const bool incremental = opts.detector == "one" || opts.detector == "simple";
    auto backbone_under = [&](Worker& w, int literal, std::vector<int>& lits) {
        return incremental ? w.api->compute_backbone_incremental({literal}, lits, in_query)
                           : w.api->compute_backbone_with_assumptions({literal}, lits, in_query);
    };

    // The modal implication graph, built once and shared by the workers (read only)
    std::unique_ptr<Mig> mig;
    auto t_build = Clock::now();
    if (opts.mig && incremental) {
        std::vector<int> fixed(n + 1, 0);
        for (int lit : bb.literals) fixed[std::abs(lit)] = lit > 0 ? 1 : -1;
        mig = std::make_unique<Mig>(n, f.clauses, fixed);
        r.mig.used = true;
        r.mig.clauses = mig->num_clauses();
        r.mig.strong_edges = mig->strong_edges();
        r.mig.weak_edges = mig->weak_edges();
        r.mig.build_seconds = seconds_between(t_build, Clock::now());
    }

    // Which query literals a job reports (see the recording below): the job of v reports every positive literal
    // and the negative literals of the variables after v (an excludes edge {v, i} is recorded by the smaller
    // variable); the job of ¬v the positive literals of the variables after v and every negative literal.
    auto reported = [](int a, int l) {
        const int v = std::abs(a), i = std::abs(l);
        return (a > 0) == (l > 0) || i > v;
    };

    // The backbone under a among the query literals that the job reports, with the modal implication graph:
    // what unit propagation derives is forced; only the literals in the weak reach of a can be forced; a stored
    // solution with a true and l false shows that a does not force l. The solver checks what is left.
    auto mig_backbone = [&](Worker& w, int a, std::vector<int>& lits) {
        const int v = std::abs(a);
        lits.clear();
        const auto t_start = Clock::now();
        w.scratch->run(a, w.job);
        w.stats.graph_work = w.scratch->work();
        const auto t_graph = Clock::now();
        w.stats.graph_seconds += seconds_between(t_start, t_graph);
        if (w.job.conflict) {   // a is impossible: let the solver report it as before
            ++w.calls;
            Solve s = backbone_under(w, a, lits);
            w.stats.solver_seconds += seconds_between(t_graph, Clock::now());
            return s;
        }
        ++w.stats.jobs;
        for (int l : w.job.forced) {
            const int i = std::abs(l);
            if (i == v || !in_query[i]) continue;
            lits.push_back(l);
            if (reported(a, l)) ++w.stats.forced_by_propagation;
        }
        w.candidates.clear();
        for (int l : w.job.reach) {
            const int i = std::abs(l);
            if (i == v || !in_query[i] || w.scratch->value(i) != 0 || !reported(a, l)) continue;
            ++w.stats.literals_in_reach;
            if (w.pool->refutes(a, l)) { ++w.stats.refuted_by_witness; continue; }
            w.candidates.push_back(l);
        }
        if (w.candidates.empty()) {
            ++w.stats.jobs_without_solver;
            w.stats.filter_seconds += seconds_between(t_graph, Clock::now());
            return Solve::Sat;
        }
        for (int l : w.candidates) w.flags[std::abs(l)] |= l > 0 ? 1 : 2;
        w.models.clear();
        ++w.calls;
        w.stats.candidates_to_solver += static_cast<long long>(w.candidates.size());
        const auto t_solver = Clock::now();
        w.stats.filter_seconds += seconds_between(t_graph, t_solver);
        Solve s = w.api->compute_backbone_incremental_literals({a}, w.found, w.flags, &w.models);
        const auto t_back = Clock::now();
        w.stats.solver_seconds += seconds_between(t_solver, t_back);
        for (int l : w.candidates) w.flags[std::abs(l)] = 0;
        w.stats.solver_solutions += static_cast<long long>(w.models.size());
        for (const auto& m : w.models) w.pool->add(m);
        if (s == Solve::Sat) lits.insert(lits.end(), w.found.begin(), w.found.end());
        w.stats.filter_seconds += seconds_between(t_back, Clock::now());
        return s;
    };
    auto job = [&](Worker& w, int literal, std::vector<int>& lits) {
        if (mig) return mig_backbone(w, literal, lits);
        ++w.calls;
        return backbone_under(w, literal, lits);
    };

    // Pre-create every solver in this thread: BoneDiggerAPI is not thread-safe
    // during initialisation (R-IMP-03).
    const auto t_setup = Clock::now();
    std::vector<Worker> workers(threads);
    for (auto& w : workers) {
        if (mig) {
            w.scratch = std::make_unique<MigScratch>(*mig);
            w.pool = std::make_unique<WitnessPool>(n);
            w.flags.assign(n + 1, 0);
        }
        w.api = std::make_unique<BoneDiggerAPI>();
        if (!w.api->load_formula(n, clauses) || !w.api->create_backbone_detector(opts.detector) ||
            (incremental && !w.api->prepare_incremental())) {
            r.code = ExitCode::Solver;
            r.error = "the solver could not be initialised for '" + f.path + "' with the detector '" + opts.detector +
                      "'. Use the detector 'one' (default) or 'rush'.";
            return r;
        }
    }

    if (mig) r.mig.setup_seconds = seconds_between(t_setup, Clock::now());

    std::atomic<size_t> next(0), done(0);
    std::atomic<bool> abort(false);
    std::mutex err_mutex;

    auto fail = [&](ExitCode code, const std::string& msg) {
        std::lock_guard<std::mutex> lock(err_mutex);
        if (!abort.exchange(true)) {
            r.code = code;
            r.error = msg;
        }
    };

    auto run = [&](Worker& w) {
        std::vector<int> lits;
        try {
            for (;;) {
                if (abort.load()) return;
                size_t idx = next.fetch_add(1);
                if (idx >= query.size()) return;
                const int v = query[idx];

                Solve s = job(w, v, lits);
                if (s != Solve::Sat) {
                    fail(ExitCode::Solver,
                         s == Solve::Unsat
                             ? "the solver reports " + var_label(f, v) + " as impossible although it is not dead. "
                               "This indicates a solver bug; please report it."
                             : "the solver failed while assuming " + var_label(f, v) + " = true.");
                    return;
                }
                for (int lit : lits) {
                    const int i = std::abs(lit);
                    if (i == v || !in_query[i]) continue;
                    if (lit > 0) w.req.push_back({v, i});
                    else if (v < i) w.exc.push_back({v, i});
                }

                if (opts.or_graph) {
                    s = job(w, -v, lits);
                    if (s != Solve::Sat) {
                        fail(ExitCode::Solver,
                             s == Solve::Unsat
                                 ? "the solver reports " + var_label(f, v) + " = false as impossible although it is not core. "
                                   "This indicates a solver bug; please report it."
                                 : "the solver failed while assuming " + var_label(f, v) + " = false.");
                        return;
                    }
                    for (int lit : lits) {
                        const int i = std::abs(lit);
                        if (i == v || !in_query[i]) continue;
                        if (lit > 0) { if (v < i) w.alo.push_back({v, i}); }
                        else w.implied.push_back({i, v});
                    }
                }
                done.fetch_add(1);
            }
        } catch (const std::bad_alloc&) {   // as in the calling thread (run_generate): exit code 2
            fail(ExitCode::Input, "not enough memory to analyse '" + f.path + "' with " + std::to_string(threads) +
                                  " threads. Each thread keeps a solver with its own copy of the formula: use fewer threads "
                                  "with -t, or a machine with more memory.");
        } catch (const std::exception& e) {
            fail(ExitCode::Solver, std::string("a worker thread stopped with the exception '") + e.what() +
                                   "' while analysing '" + f.path + "'. This is an internal error: please report it with the input file.");
        } catch (...) {
            fail(ExitCode::Solver, "a worker thread stopped with an unknown exception while analysing '" + f.path +
                                   "'. This is an internal error: please report it with the input file.");
        }
    };

    // A thread that has started must be joined whatever happens: a std::thread destroyed while it runs ends the
    // program. If anything below throws, the workers are told to stop and are joined before the exception leaves.
    std::vector<std::thread> pool;
    struct JoinAll {
        std::vector<std::thread>& started;
        std::atomic<bool>& stop;
        ~JoinAll() {
            for (auto& t : started)
                if (t.joinable()) {
                    stop = true;
                    t.join();
                }
        }
    } join_all{pool, abort};
    // The system may refuse a thread (a limit on the number of processes, such as ulimit -u or the limits of a
    // container, or no memory for its stack). That is not an error: the run goes on with the threads that
    // started, or in this thread if none did, and gives the same files (R-TST-18). A single worker always runs in
    // this thread: starting a thread for it gains nothing.
    pool.reserve(threads);
    const auto t_jobs = Clock::now();
    std::string refused;
    if (workers.size() > 1) {
        for (auto& w : workers) {
            try {
                pool.emplace_back(run, std::ref(w));
            } catch (const std::exception& e) {
                refused = e.what();
                break;
            }
        }
    }
    if (workers.size() == 1) {
        run(workers[0]);
    } else if (pool.size() < workers.size()) {
        r.threads_used = std::max<int>(1, static_cast<int>(pool.size()));
        r.warnings.push_back("the system started " + std::to_string(pool.size()) + " of " + std::to_string(threads) +
                             " threads (" + refused + "); the run goes on with " +
                             (pool.empty() ? std::string("the calling thread only")
                                           : std::to_string(pool.size()) + (pool.size() == 1 ? " thread" : " threads")) +
                             ". A limit on the number of processes (ulimit -u, or the limits of a container) can cause this; "
                             "give fewer threads with -t.");
        if (pool.empty()) run(workers[0]);
    }

    bool show = opts.progress == ProgressMode::On ||
                false;
    const size_t total = query.size();
    if (show) {
        while (done.load() < total && !abort.load()) {
            vp::out() << "\rProgress: " << done.load() << " of " << total << " variables" << std::flush;
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            bool all_finished = next.load() >= total + pool.size();
            if (all_finished) break;
        }
    }
    for (auto& t : pool) t.join();
    if (mig) r.mig.jobs_seconds = seconds_between(t_jobs, Clock::now());
    if (show) vp::out() << "\rProgress: " << done.load() << " of " << total << " variables" << std::endl;

    if (r.code != ExitCode::Success) return r;

    for (auto& w : workers) {
        r.solver_calls += w.calls;
        r.solver_instances += w.api->solver_instances();
        r.mig.jobs += w.stats.jobs;
        r.mig.jobs_without_solver += w.stats.jobs_without_solver;
        r.mig.forced_by_propagation += w.stats.forced_by_propagation;
        r.mig.literals_in_reach += w.stats.literals_in_reach;
        r.mig.refuted_by_witness += w.stats.refuted_by_witness;
        r.mig.candidates_to_solver += w.stats.candidates_to_solver;
        r.mig.solver_solutions += w.stats.solver_solutions;
        r.mig.graph_work += w.stats.graph_work;
        r.mig.graph_seconds += w.stats.graph_seconds;
        r.mig.filter_seconds += w.stats.filter_seconds;
        r.mig.solver_seconds += w.stats.solver_seconds;
        r.requires_arcs.insert(r.requires_arcs.end(), w.req.begin(), w.req.end());
        r.excludes_edges.insert(r.excludes_edges.end(), w.exc.begin(), w.exc.end());
        r.atleastone_edges.insert(r.atleastone_edges.end(), w.alo.begin(), w.alo.end());
        r.or_implied_arcs.insert(r.or_implied_arcs.end(), w.implied.begin(), w.implied.end());
    }
    if (r.mig.used) {
        const long long q = static_cast<long long>(query.size());
        r.mig.possible_candidates = (opts.or_graph ? 2 : 1) * ((q - 1) * q + q * (q - 1) / 2);
    }
    std::sort(r.requires_arcs.begin(), r.requires_arcs.end());
    std::sort(r.excludes_edges.begin(), r.excludes_edges.end());
    std::sort(r.atleastone_edges.begin(), r.atleastone_edges.end());
    std::sort(r.or_implied_arcs.begin(), r.or_implied_arcs.end());
    return r;
}

} // namespace dimacs2graphs
