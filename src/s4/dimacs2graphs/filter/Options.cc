/**
 * @file Options.cc
 * @brief Option helpers (see Options.hh)
 */

#include "Options.hh"

#include <sstream>

namespace dimacs2graphs {

void apply_legacy(GenerateOptions& o) {
    apply_legacy(o.filter, o.output, o.run);
}

void apply_legacy(FilterOptions& f, OutputOptions& output, RunOptions& run) {
    f.translator = Translator::Generic;
    f.tristate = TristateMode::Both;
    f.nonbool = NonBoolMode::Keep;
    f.drop_visibility = false;
    f.abstract_groups = AbstractGroupMode::Keep;
    f.drop_synthetic_root = false;
    f.abstract_features = AbstractMode::Keep;
    f.drop_fixed_nodes = false;
    f.drop_unnamed = false;
    f.unknown_names = UnknownNames::Keep;
    f.decls_file.reset();
    f.add_unconstrained = false;
    f.keep_type_prefix = true;
    f.strip_config_prefix = false;
    f.filter_at = FilterAt::Output;
    output.or_graph = false;
    output.minimal = false;
    output.kernel = false;
    output.atomic = false;
    output.check = false;
    run.strict_uvl = false;
    run.legacy = true;
}

std::string validate_options(const GenerateOptions& o) {
    if (o.run.threads < 1)
        return "the number of threads must be at least 1 (got " + std::to_string(o.run.threads) +
               "). Give a positive number of threads (run.threads, option --threads).";
    if (!(o.run.max_matrix_memory_gb > 0)) {   // also NaN
        std::ostringstream v;
        v << o.run.max_matrix_memory_gb;
        return "the memory limit of the dense algorithms must be a positive number of GB (got " + v.str() +
               "). Give a positive value (run.max_matrix_memory_gb, option --max-matrix-memory), for example 2.";
    }
    // "simple" and "rushandpray" are the names that 1.x also accepted
    const std::string& d = o.run.detector;
    if (d != "one" && d != "flatland" && d != "rush" && d != "simple" && d != "rushandpray")
        return "unknown backbone detector '" + d + "' (run.detector). Give \"one\" (the default) or \"rush\".";
    if (o.filter.decls_file && o.filter.decls_file->empty())
        return "the file of declared names is an empty name (filter.decls_file, option --decls). Give the path of the "
               "file, or leave it unset.";
    if (o.filter.drop_names_file && o.filter.drop_names_file->empty())
        return "the file of names to drop is an empty name (filter.drop_names_file, option --drop-names). Give the path "
               "of the file, or leave it unset.";
    if (o.output.representativeness && !o.output.or_graph)
        return "the measure of what the graphs leave out needs the third graph (output.representativeness needs "
               "output.or_graph = true; on the command line, --representativeness turns on --or-graph).";
    if (o.output.representativeness && o.run.ganak.empty())
        return "the model counter is an empty name (run.ganak, option --ganak). Give the path of GANAK, or \"ganak\" to "
               "find it on the PATH.";
    return "";
}

const char* to_string(Translator t) {
    switch (t) {
        case Translator::Auto: return "auto";
        case Translator::KMax: return "kmax";
        case Translator::KConfigReader: return "kconfigreader";
        case Translator::KconfigSampler: return "kconfigsampler";
        case Translator::TraVarT: return "travart";
        case Translator::Uvl: return "uvl";
        case Translator::Generic: return "generic";
    }
    return "?";
}

const char* to_string(TristateMode m) {
    switch (m) {
        case TristateMode::Merge: return "merge";
        case TristateMode::Builtin: return "builtin";
        case TristateMode::Both: return "both";
    }
    return "?";
}

const char* to_string(NonBoolMode m) {
    switch (m) {
        case NonBoolMode::Merge: return "merge";
        case NonBoolMode::Drop: return "drop";
        case NonBoolMode::Keep: return "keep";
    }
    return "?";
}

const char* to_string(AbstractGroupMode m) { return m == AbstractGroupMode::Merge ? "merge" : "keep"; }

const char* to_string(AbstractMode m) {
    switch (m) {
        case AbstractMode::Keep: return "keep";
        case AbstractMode::Drop: return "drop";
        case AbstractMode::Merge: return "merge";
    }
    return "?";
}

const char* to_string(UnknownNames u) {
    switch (u) {
        case UnknownNames::ProfileDefault: return "profile-default";
        case UnknownNames::Keep: return "keep";
        case UnknownNames::Drop: return "drop";
        case UnknownNames::Error: return "error";
    }
    return "?";
}

const char* to_string(FilterAt f) { return f == FilterAt::Input ? "input" : "output"; }

const char* to_string(Progress p) {
    switch (p) {
        case Progress::Auto: return "auto";
        case Progress::On: return "on";
        case Progress::Off: return "off";
    }
    return "?";
}

bool parse_translator(const std::string& s, Translator& t) {
    for (Translator x : {Translator::Auto, Translator::KMax, Translator::KConfigReader, Translator::KconfigSampler,
                         Translator::TraVarT, Translator::Uvl, Translator::Generic}) {
        if (s == to_string(x)) { t = x; return true; }
    }
    return false;
}

} // namespace dimacs2graphs
