/**
 * @file Classifier.cc
 * @brief Profiles, rules, detection and formula merges (see Classifier.hh)
 *
 * Built-in rules use hand-written matchers (prefix, suffix and digit checks);
 * std::regex is used only for the user's --keep-pattern / --drop-pattern
 * (R-IMP-01).
 */

#include "Classifier.hh"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <regex>
#include <set>
#include <unordered_map>
#include <unordered_set>

namespace dimacs2graphs {

const char* to_string(VarClass c) {
    switch (c) {
        case VarClass::Option: return "OPTION";
        case VarClass::Tseitin: return "TSEITIN";
        case VarClass::Chain: return "CHAIN";
        case VarClass::Visibility: return "VISIBILITY";
        case VarClass::SelectHelper: return "SELECT_HELPER";
        case VarClass::Placeholder: return "PLACEHOLDER";
        case VarClass::Module: return "MODULE";
        case VarClass::Choice: return "CHOICE";
        case VarClass::Value: return "VALUE";
        case VarClass::Bitvector: return "BITVECTOR";
        case VarClass::Environment: return "ENVIRONMENT";
        case VarClass::AbstractGroup: return "ABSTRACT_GROUP";
        case VarClass::Root: return "ROOT";
        case VarClass::Abstract: return "ABSTRACT";
        case VarClass::Unnamed: return "UNNAMED";
        case VarClass::DeclaredOut: return "DECLARED_OUT";
    }
    return "?";
}

namespace {

// ---------------------------------------------------------------------------
// Hand-written matchers
// ---------------------------------------------------------------------------

bool starts_with(const std::string& s, const char* p) {
    size_t n = std::char_traits<char>::length(p);
    return s.size() >= n && s.compare(0, n, p) == 0;
}

bool ends_with(const std::string& s, const char* p) {
    size_t n = std::char_traits<char>::length(p);
    return s.size() >= n && s.compare(s.size() - n, n, p) == 0;
}

/// s[from..] is a non-empty run of digits up to the end.
bool digits_to_end(const std::string& s, size_t from) {
    if (from >= s.size()) return false;
    for (size_t i = from; i < s.size(); ++i)
        if (!std::isdigit(static_cast<unsigned char>(s[i]))) return false;
    return true;
}

/// `^k![0-9]+$`
bool is_k_tseitin(const std::string& n) { return starts_with(n, "k!") && digits_to_end(n, 2); }

/// `^aux_[0-9]+(_.*)?$`
bool is_aux_name(const std::string& n) {
    if (!starts_with(n, "aux_")) return false;
    size_t i = 4;
    if (i >= n.size() || !std::isdigit(static_cast<unsigned char>(n[i]))) return false;
    while (i < n.size() && std::isdigit(static_cast<unsigned char>(n[i]))) ++i;
    return i == n.size() || n[i] == '_';
}

/// `^[A-Za-z0-9_]+$`
bool is_plain(const std::string& n) {
    if (n.empty()) return false;
    for (unsigned char c : n)
        if (!(std::isalnum(c) || c == '_')) return false;
    return true;
}

/// `^(.+)_(xor|or|alt)$`
bool has_group_suffix(const std::string& n) {
    for (const char* s : {"_xor", "_or", "_alt"}) {
        size_t k = std::char_traits<char>::length(s);
        if (n.size() > k && ends_with(n, s)) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Rule tables
// ---------------------------------------------------------------------------

struct Ctx {
    const DimacsFormula& f;
    std::unordered_map<std::string, int> var_of;  ///< name → variable
    std::unordered_set<std::string> nb;           ///< non-Boolean prefixes (KConfigReader, R-FLT-10)

    bool exists(const std::string& n) const { return var_of.count(n) != 0; }

    /// R-FLT-10: option P of a value variable, or "" (longest prefix wins).
    std::string value_option(const std::string& n) const {
        for (size_t pos = n.size(); pos-- > 0;) {
            if (n[pos] != '_') continue;
            std::string p = n.substr(0, pos);
            if (p.empty() || !nb.count(p)) continue;
            std::string s = n.substr(pos + 1);
            if (s.empty() || !std::isupper(static_cast<unsigned char>(s[0]))) return p;
        }
        return "";
    }
};

using Matcher = bool (*)(const Ctx&, int v, const std::string& name);

struct Rule {
    const char* id;
    const char* condition;
    VarClass cls;
    const char* action;
    Matcher match;
};

// Reserved comments of uvl2dimacs 2.0 apply in every profile.
const Rule MARKER_RULES[] = {
    {"U1", "`c aux <n> tseitin` comment (uvl2dimacs 2.0)", VarClass::Tseitin, "drop",
     [](const Ctx& c, int v, const std::string&) { return c.f.aux[v] == AuxKind::Tseitin; }},
    {"U2", "`c aux <n> chain` comment (uvl2dimacs 2.0)", VarClass::Chain, "drop",
     [](const Ctx& c, int v, const std::string&) { return c.f.aux[v] == AuxKind::Chain; }},
};

const Rule KMAX_RULES[] = {
    {"K1", "`^k![0-9]+$`", VarClass::Tseitin, "drop",
     [](const Ctx&, int, const std::string& n) { return is_k_tseitin(n); }},
    {"K2", "`^__VISIBILITY__CONFIG_(.+)$`", VarClass::Visibility, "drop (`--visibility`)",
     [](const Ctx&, int, const std::string& n) { return starts_with(n, "__VISIBILITY__CONFIG_") && n.size() > 21; }},
    {"K3", "`^([A-Za-z0-9_]+)__CONFIG_([A-Za-z0-9_]+)$`, both captured names exist as variables, name does not start with `__`",
     VarClass::SelectHelper, "drop",
     [](const Ctx& c, int, const std::string& n) {
         if (starts_with(n, "__") || !is_plain(n)) return false;
         for (size_t p = n.find("__CONFIG_"); p != std::string::npos; p = n.find("__CONFIG_", p + 1)) {
             std::string a = n.substr(0, p), b = n.substr(p + 9);
             if (!a.empty() && !b.empty() && c.exists(a) && c.exists(b)) return true;
         }
         return false;
     }},
    {"K4", "`^PREDICATE_`", VarClass::Placeholder, "drop",
     [](const Ctx&, int, const std::string& n) { return starts_with(n, "PREDICATE_"); }},
    {"K5", "`<unsupported>`", VarClass::Placeholder, "drop",
     [](const Ctx&, int, const std::string& n) { return n == "<unsupported>"; }},
    {"K6", "everything else matching `^[A-Za-z0-9_]+$`", VarClass::Option, "keep",
     [](const Ctx&, int, const std::string& n) { return is_plain(n); }},
};

const Rule KCR_RULES[] = {
    {"R1", "`^k![0-9]+$`", VarClass::Tseitin, "drop",
     [](const Ctx&, int, const std::string& n) { return is_k_tseitin(n); }},
    {"R2", "`^CHOICE_[0-9]+$`", VarClass::Choice, "drop",
     [](const Ctx&, int, const std::string& n) { return starts_with(n, "CHOICE_") && digits_to_end(n, 7); }},
    {"R3", "`^(.+)_MODULE$` and the prefix exists as a variable (R-FLT-12)", VarClass::Module, "merge (`--tristate`, R-FLT-11)",
     [](const Ctx& c, int, const std::string& n) { return n.size() > 7 && ends_with(n, "_MODULE") && c.exists(n.substr(0, n.size() - 7)); }},
    {"R4", "value variable of a non-Boolean option: `P_n`, `P_nonempty`, `P_`, or `P_<s>` with `s` empty or not starting with an upper-case letter, for `P` in NB (R-FLT-10)",
     VarClass::Value, "merged into one node per option (`--nonbool merge`)",
     [](const Ctx& c, int, const std::string& n) { return !c.value_option(n).empty(); }},
    {"R5", "`^undef$`", VarClass::Placeholder, "drop",
     [](const Ctx&, int, const std::string& n) { return n == "undef"; }},
    {"R6", "everything else", VarClass::Option, "keep",
     [](const Ctx&, int, const std::string& n) { return !n.empty(); }},
};

const Rule KCS_RULES[] = {
    {"S1", "`^ART_[0-9]+$`", VarClass::Tseitin, "drop",
     [](const Ctx&, int, const std::string& n) { return starts_with(n, "ART_") && digits_to_end(n, 4); }},
    {"S2", "`^boolean_(.+)$`", VarClass::Option, "keep, renamed to the captured name (R-FLT-19)",
     [](const Ctx&, int, const std::string& n) { return starts_with(n, "boolean_") && n.size() > 8; }},
    {"S3", "`^(string|int|hex)_(.+)_EQ_(.*)$` (prefix match, any characters)", VarClass::Value, "drop (`--nonbool merge` or `drop`)",
     [](const Ctx&, int, const std::string& n) {
         size_t p = starts_with(n, "string_") ? 7 : starts_with(n, "int_") ? 4 : starts_with(n, "hex_") ? 4 : 0;
         if (!p) return false;
         size_t e = n.find("_EQ_", p);
         return e != std::string::npos && e > p;
     }},
    {"S4", "`^BIT_[0-9]+_BITMAP_(int|hex)_`, `^BITMAP_INT_MASTER_BITMAP_`, `^SIGN_BITMAP_(int|hex)_` (sign bit)", VarClass::Bitvector, "drop",
     [](const Ctx&, int, const std::string& n) {
         if (starts_with(n, "BITMAP_INT_MASTER_BITMAP_")) return true;
         if (starts_with(n, "SIGN_BITMAP_int_") || starts_with(n, "SIGN_BITMAP_hex_")) return true;
         if (!starts_with(n, "BIT_")) return false;
         size_t i = 4;
         if (i >= n.size() || !std::isdigit(static_cast<unsigned char>(n[i]))) return false;
         while (i < n.size() && std::isdigit(static_cast<unsigned char>(n[i]))) ++i;
         std::string rest = n.substr(i);
         return starts_with(rest, "_BITMAP_int_") || starts_with(rest, "_BITMAP_hex_");
     }},
    {"S5", "`^ENV_`", VarClass::Environment, "drop",
     [](const Ctx&, int, const std::string& n) { return starts_with(n, "ENV_"); }},
    {"S6", "`^tristate_(.+)$`", VarClass::Option, "keep, renamed (R-FLT-19)",
     [](const Ctx&, int, const std::string& n) { return starts_with(n, "tristate_") && n.size() > 9; }},
};

const Rule TRAVART_RULES[] = {
    {"T1", "`^__Root__$`", VarClass::Root, "synthetic root: dropped from nodes and core list (`--synthetic-root`)",
     [](const Ctx&, int, const std::string& n) { return n == "__Root__"; }},
    {"T2", "`^(.+)_(xor|or|alt)$` and, after solving, in an atomic set with a variable not matching T2",
     VarClass::AbstractGroup, "merged into its parent's atomic set (`--abstract-groups`)",
     [](const Ctx&, int, const std::string& n) { return has_group_suffix(n); }},
    {"T3", "everything else, including `root`", VarClass::Option, "keep",
     [](const Ctx&, int, const std::string& n) { return !n.empty(); }},
};

const Rule UVL_RULES[] = {
    {"U1", "1.x name `^aux_[0-9]+(_.*)?$` (not a chain variable) in a file without the 2.0 header", VarClass::Tseitin, "drop",
     [](const Ctx& c, int, const std::string& n) {
         return !c.f.uvl_header && is_aux_name(n) && n.find("_chain_") == std::string::npos;
     }},
    {"U2", "1.x name `^aux_[0-9]+_chain_[0-9]+$` in a file without the 2.0 header", VarClass::Chain, "drop",
     [](const Ctx& c, int, const std::string& n) {
         return !c.f.uvl_header && is_aux_name(n) && n.find("_chain_") != std::string::npos;
     }},
    {"U3", "root feature (`c root <n>`) that is not abstract", VarClass::Root, "keep (it is core)",
     [](const Ctx& c, int v, const std::string&) { return c.f.is_root[v] != 0 && c.f.is_abstract[v] == 0; }},
    {"U4", "feature with attribute `{abstract}` (`c abstract <n>`), the root included", VarClass::Abstract, "drop (`--abstract`)",
     [](const Ctx& c, int v, const std::string&) { return c.f.is_abstract[v] != 0; }},
    {"U5", "every other feature", VarClass::Option, "keep",
     [](const Ctx&, int, const std::string& n) { return !n.empty(); }},
};

const Rule GENERIC_RULES[] = {
    {"G1", "`^aux_[0-9]+(_.*)?$`", VarClass::Tseitin, "drop",
     [](const Ctx&, int, const std::string& n) { return is_aux_name(n); }},
};

template <size_t N>
std::vector<const Rule*> as_list(const Rule (&rules)[N]) {
    std::vector<const Rule*> l;
    for (const Rule& r : rules) l.push_back(&r);
    return l;
}

std::vector<const Rule*> profile_rules(Translator t) {
    std::vector<const Rule*> l = as_list(MARKER_RULES);
    std::vector<const Rule*> p;
    switch (t) {
        case Translator::KMax: p = as_list(KMAX_RULES); break;
        case Translator::KConfigReader: p = as_list(KCR_RULES); break;
        case Translator::KconfigSampler: p = as_list(KCS_RULES); break;
        case Translator::TraVarT: p = as_list(TRAVART_RULES); break;
        case Translator::Uvl: p = as_list(UVL_RULES); break;
        default: p = as_list(GENERIC_RULES); break;
    }
    l.insert(l.end(), p.begin(), p.end());
    return l;
}

/// Option encoded by a value or bit variable of a non-Boolean option ("" if it cannot be told).
std::string encoded_option(Translator profile, VarClass cls, const std::string& n, const Ctx& ctx) {
    if (cls == VarClass::Value) {
        if (profile == Translator::KConfigReader) return ctx.value_option(n);
        // KconfigSampler: (string|int|hex)_<P>_EQ_<value>; as in the pattern of S3, the last _EQ_ separates the value
        const size_t p = starts_with(n, "string_") ? 7 : (starts_with(n, "int_") || starts_with(n, "hex_")) ? 4 : 0;
        const size_t e = n.rfind("_EQ_");
        if (p && e != std::string::npos && e > p) return n.substr(p, e - p);
        return "";
    }
    if (cls == VarClass::Bitvector) {
        // BIT_<k>_BITMAP_int_<P>, BITMAP_INT_MASTER_BITMAP_int_<P>, SIGN_BITMAP_int_<P> (and _hex_)
        for (const char* m : {"BITMAP_int_", "BITMAP_hex_"}) {
            const size_t p = n.find(m);
            if (p != std::string::npos) return n.substr(p + 11);
        }
    }
    return "";
}

UnknownNames profile_default_unknown(Translator t) {
    switch (t) {
        case Translator::KMax:
        case Translator::KConfigReader:
        case Translator::KconfigSampler: return UnknownNames::Drop;
        default: return UnknownNames::Keep;
    }
}

std::string base_name(const std::string& path) {
    size_t s = path.find_last_of("/\\");
    return s == std::string::npos ? path : path.substr(s + 1);
}

bool read_lines(const std::string& path, std::vector<std::string>& lines, std::string& error) {
    std::ifstream in(path);
    if (!in.is_open()) {
        error = "cannot open '" + path + "'. Check the path given to the option.";
        return false;
    }
    std::string l;
    long n = 0;
    while (std::getline(in, l)) {
        ++n;
        if (!l.empty() && l.back() == '\r') l.pop_back();
        size_t b = l.find_first_not_of(" \t"), e = l.find_last_not_of(" \t");
        if (b == std::string::npos) continue;
        l = l.substr(b, e - b + 1);
        if (l[0] == '#') continue;
        lines.push_back(l);
    }
    if (in.bad()) {   // a read error ends the loop as the end of the file would
        error = read_error(path, n);
        return false;
    }
    return true;
}

}  // namespace

// ---------------------------------------------------------------------------
// Detection (R-FLT-02)
// ---------------------------------------------------------------------------

ProfileDetection detect_profile(const DimacsFormula& f, const ClassifyContext& ctx) {
    ProfileDetection d;
    if (ctx.input_is_uvl) {
        d.profile = Translator::Uvl; d.how = "extension"; d.evidence = "input is a .uvl file";
        return d;
    }
    if (f.uvl_header) {
        d.profile = Translator::Uvl; d.how = "header"; d.evidence = "comment 'c generated-by uvl2dimacs'";
        return d;
    }
    std::string file = base_name(ctx.input_path.empty() ? f.path : ctx.input_path);
    const std::pair<const char*, Translator> by_name[] = {
        {"__KMax", Translator::KMax}, {"__KConfigReader", Translator::KConfigReader},
        {"__KconfigSampler", Translator::KconfigSampler}, {"__TraVarT", Translator::TraVarT}};
    for (const auto& p : by_name) {
        if (file.find(p.first) != std::string::npos) {
            d.profile = p.second; d.how = "file-name";
            d.evidence = std::string("file name contains '") + p.first + "'";
            return d;
        }
    }

    std::unordered_set<std::string> names;
    for (int v = 1; v <= f.num_vars; ++v)
        if (f.has_name(v)) names.insert(f.names[v]);
    bool visibility = false, unsupported = false, choice = false, art = false, boolean = false;
    bool root = false, suffix = false;
    int modules = 0;
    for (const auto& n : names) {
        if (starts_with(n, "__VISIBILITY__")) visibility = true;
        if (n == "<unsupported>") unsupported = true;
        if (starts_with(n, "CHOICE_") && digits_to_end(n, 7)) choice = true;
        if (n.size() > 7 && ends_with(n, "_MODULE") && names.count(n.substr(0, n.size() - 7))) ++modules;
        if (starts_with(n, "ART_") && digits_to_end(n, 4)) art = true;
        if (starts_with(n, "boolean_")) boolean = true;
        if (n == "root" || n == "__Root__") root = true;
        if (has_group_suffix(n)) suffix = true;
    }
    d.how = "content";
    if (visibility || unsupported) {
        d.profile = Translator::KMax;
        d.evidence = visibility ? "names starting with '__VISIBILITY__'" : "name '<unsupported>'";
    } else if (choice || modules >= 10) {
        d.profile = Translator::KConfigReader;
        d.evidence = choice ? "names 'CHOICE_<n>'" : std::to_string(modules) + " 'X_MODULE' names whose X exists";
    } else if (art && boolean) {
        d.profile = Translator::KconfigSampler;
        d.evidence = "names 'ART_<n>' and 'boolean_…'";
    } else if (root || suffix) {
        d.profile = Translator::TraVarT;
        d.evidence = root ? "name 'root' or '__Root__'" : "names ending in _xor/_or/_alt";
        d.weak = true;
    } else if (f.legacy_uvl_header) {
        d.profile = Translator::Uvl; d.how = "header";
        d.evidence = "comment 'c Generated by UVL2Dimacs' (1.x)";
    } else {
        d.profile = Translator::Generic; d.how = "default";
        d.evidence = "no rule of R-FLT-02 matched";
    }
    return d;
}

// ---------------------------------------------------------------------------
// Normalisation (R-FLT-19)
// ---------------------------------------------------------------------------

std::string normalise_name(const std::string& name, const FilterOptions& o, Translator profile) {
    std::string n = name;
    // The type prefixes are KconfigSampler's (rules S2 and S6); in other profiles
    // a name that starts with "boolean_" is just a name.
    if (profile == Translator::KconfigSampler && !o.keep_type_prefix) {
        if (starts_with(n, "boolean_") && n.size() > 8) n = n.substr(8);
        else if (starts_with(n, "tristate_") && n.size() > 9) n = n.substr(9);
    }
    if (o.strip_config_prefix && starts_with(n, "CONFIG_") && n.size() > 7) n = n.substr(7);
    return n;
}

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------

Classification classify(const DimacsFormula& f, const FilterOptions& o, const ClassifyContext& cctx) {
    Classification c;
    c.vars.assign(f.num_vars + 1, VarInfo());

    if (o.translator != Translator::Auto) {
        c.detection.profile = o.translator;
        c.detection.how = "option";
        c.detection.evidence = "--translator";
    } else {
        c.detection = detect_profile(f, cctx);
    }
    const Translator profile = c.detection.profile;
    c.unknown_policy = o.unknown_names == UnknownNames::ProfileDefault ? profile_default_unknown(profile) : o.unknown_names;
    if (c.detection.weak)
        c.warnings.push_back(std::string("translator profile '") + to_string(profile) + "' detected with weak evidence (" +
                             c.detection.evidence + "); use --translator to override.");

    Ctx ctx{f, {}, {}};
    for (int v = 1; v <= f.num_vars; ++v)
        if (f.has_name(v)) ctx.var_of[f.names[v]] = v;

    if (profile == Translator::KConfigReader) {
        for (const auto& kv : ctx.var_of) {
            const std::string& n = kv.first;
            if (ends_with(n, "_nonempty") && n.size() > 9) ctx.nb.insert(n.substr(0, n.size() - 9));
            else if (ends_with(n, "_n") && n.size() > 2) ctx.nb.insert(n.substr(0, n.size() - 2));
            else if (ends_with(n, "_") && n.size() > 1) ctx.nb.insert(n.substr(0, n.size() - 1));
        }
    }

    // User patterns and lists
    std::vector<std::regex> keep_re, drop_re;
    try {
        for (const auto& p : o.keep_patterns) keep_re.emplace_back(p);
        for (const auto& p : o.drop_patterns) drop_re.emplace_back(p);
    } catch (const std::regex_error& e) {
        c.code = ExitCode::Usage;
        c.error = std::string("invalid regular expression in --keep-pattern/--drop-pattern: ") + e.what() +
                  ". Patterns use the ECMAScript syntax of std::regex.";
        return c;
    }
    std::unordered_map<std::string, VarClass> drop_names;
    if (o.drop_names_file) {
        std::vector<std::string> lines;
        if (!read_lines(*o.drop_names_file, lines, c.error)) { c.code = ExitCode::Input; return c; }
        for (const auto& l : lines) {
            size_t tab = l.find('\t');
            VarClass cls = VarClass::Tseitin;
            std::string name = l;
            if (tab != std::string::npos) {
                name = l.substr(0, tab);
                std::string k = l.substr(tab + 1);
                for (int i = 0; i <= static_cast<int>(VarClass::DeclaredOut); ++i)
                    if (k == to_string(static_cast<VarClass>(i))) cls = static_cast<VarClass>(i);
            }
            drop_names[name] = cls;
        }
    }
    std::unordered_set<std::string> decls;
    if (o.decls_file) {
        c.decls_given = true;
        std::vector<std::string> lines;
        if (!read_lines(*o.decls_file, lines, c.error)) { c.code = ExitCode::Input; return c; }
        for (const auto& l : lines) decls.insert(normalise_name(l, o, profile));
    }
    auto is_declared = [&](const std::string& raw_name) { return decls.count(normalise_name(raw_name, o, profile)) != 0; };

    const std::vector<const Rule*> rules = profile_rules(profile);
    // A file written by uvl2dimacs 2.0 marks its artificial variables with reserved comments
    // (R-UVL-01): every named variable is a feature, so its name is never used to drop it
    // (a feature may be called "k!3" or "aux_1"). The name-based common rule C2 does not apply.
    const bool names_are_features = profile == Translator::Uvl && f.uvl_header;
    auto matches_any = [](const std::vector<std::regex>& res, const std::string& n) {
        for (const auto& r : res)
            if (std::regex_search(n, r)) return true;
        return false;
    };
    // Classes that are not options (ROOT, ABSTRACT and ABSTRACT_GROUP are features of the model)
    auto is_artificial = [](VarClass k) {
        return k != VarClass::Option && k != VarClass::Root && k != VarClass::Abstract && k != VarClass::AbstractGroup;
    };

    std::map<std::string, Classification::NonBool> nb_options;
    std::vector<std::pair<std::string, int>> modules;   // (X, X_MODULE var)
    std::unordered_set<std::string> encoded;            // normalised names of options encoded by value or bit variables
    std::set<std::string> nb_undeclared;                // non-Boolean options found but not declared

    for (int v = 1; v <= f.num_vars; ++v) {
        VarInfo& vi = c.vars[v];
        const std::string& name = f.names[v];
        const bool named = !name.empty();
        vi.output_name = named ? normalise_name(name, o, profile) : "v" + std::to_string(v);

        // 1. C5: explicit keep (overrides every other rule)
        if (named && matches_any(keep_re, name)) {
            vi.cls = VarClass::Option; vi.rule = "C5";
            continue;
        }

        // Profile rules that match: `special` is the first rule for an artificial or
        // special variable, `option` the first rule that keeps the name as an option
        // (the "everything else" rows K6, R6, T3, U5 and the prefix rules S2, S6).
        const Rule* special = nullptr;
        const Rule* option = nullptr;
        for (const Rule* r : rules) {
            if (!r->match(ctx, v, name)) continue;
            if (r->cls == VarClass::Option) { if (!option) option = r; }
            else if (!special) special = r;
        }

        // 3–5. Profile rules for artificial variables, then C1–C4, then the profile's
        // option rules, then --unknown-names (R-FLT-04). The option rules come after
        // C1–C4 because they are the residual ("everything else"): this way the common
        // rules hold in every profile and --drop-names / --drop-pattern can drop any option.
        bool user_drop = false;
        if (special) { vi.cls = special->cls; vi.rule = special->id; }
        else if (!named) { vi.cls = VarClass::Unnamed; vi.rule = "C1"; }
        else if (!names_are_features && is_k_tseitin(name)) { vi.cls = VarClass::Tseitin; vi.rule = "C2"; }
        else if (drop_names.count(name)) { vi.cls = drop_names[name]; vi.rule = "C3"; user_drop = true; }
        else if (matches_any(drop_re, name)) { vi.cls = VarClass::Tseitin; vi.rule = "C4"; }
        else if (option) { vi.cls = option->cls; vi.rule = option->id; }
        else { vi.cls = VarClass::Option; vi.rule = "R-OPT-14"; vi.unknown = true; }

        // 2. C6 (--decls, R-FLT-18). A declared name is an option, whatever a heuristic
        // rule of the profile says (this corrects the value detection of R-FLT-10).
        const bool declared = c.decls_given && named && decls.count(vi.output_name) != 0;
        if (declared && ((special && is_artificial(vi.cls)) || vi.unknown)) {
            vi.cls = VarClass::Option; vi.rule = "C6"; vi.unknown = false;
        }

        // Action by class (options of Section 8)
        Decision d = Decision::Keep;
        std::string encodes;   // option encoded by a MODULE, VALUE or BITVECTOR variable
        if (user_drop) {
            d = Decision::Drop;
        } else if (vi.unknown) {
            if (c.decls_given) {
                // undeclared: decided by C6 below, which precedes --unknown-names
            } else if (c.unknown_policy == UnknownNames::Error) {
                c.code = ExitCode::UnknownName;
                c.error = "variable " + std::to_string(v) + " '" + name + "' of '" + f.path + "' matches no rule of profile '" +
                          to_string(profile) + "' (--unknown-names error). Use --keep-pattern or --drop-pattern for this "
                          "name, --unknown-names keep|drop, or another --translator.";
                return c;
            } else if (c.unknown_policy == UnknownNames::Drop) {
                d = Decision::Drop;
            }
        } else {
            switch (vi.cls) {
                case VarClass::Option:
                    break;
                case VarClass::Root:
                    if (vi.rule == "T1" && o.drop_synthetic_root) d = Decision::Drop;
                    break;
                case VarClass::Abstract:
                    if (o.abstract_features == AbstractMode::Drop) d = Decision::Drop;
                    else if (o.abstract_features == AbstractMode::Merge) d = Decision::MergeCandidate;
                    break;
                case VarClass::Visibility:
                    if (o.drop_visibility) d = Decision::Drop;
                    break;
                case VarClass::Unnamed:
                    if (o.drop_unnamed) d = Decision::Drop;
                    break;
                case VarClass::Module:
                    encodes = name.substr(0, name.size() - 7);
                    if (o.tristate == TristateMode::Builtin) d = Decision::Drop;
                    break;   // merge: paired below; both: kept as a node
                case VarClass::Value:
                    encodes = encoded_option(profile, vi.cls, name, ctx);
                    if (o.nonbool != NonBoolMode::Keep) d = Decision::Drop;   // merge: see apply_merges
                    break;
                case VarClass::Bitvector:
                    encodes = encoded_option(profile, vi.cls, name, ctx);
                    d = Decision::Drop;
                    break;
                case VarClass::AbstractGroup:
                    if (o.abstract_groups == AbstractGroupMode::Merge) d = Decision::MergeCandidate;
                    else vi.cls = VarClass::Option;
                    break;
                default:
                    d = Decision::Drop;
            }
        }
        const bool encodes_declared = !encodes.empty() && (!c.decls_given || is_declared(encodes));
        if (!encodes.empty() && vi.cls != VarClass::Module) encoded.insert(normalise_name(encodes, o, profile));

        // C6: an undeclared variable is kept only when it encodes a declared option
        // (then --tristate / --nonbool decide how that option is represented).
        if (c.decls_given && !declared) {
            if (!encodes.empty()) {
                if (!encodes_declared) {
                    // Dropped by C6 if it would otherwise be kept or merged; else by its own rule
                    const bool would_survive =
                        (vi.cls == VarClass::Module && o.tristate != TristateMode::Builtin) ||
                        (vi.cls == VarClass::Value &&
                         (o.nonbool == NonBoolMode::Keep ||
                          (o.nonbool == NonBoolMode::Merge && profile == Translator::KConfigReader)));
                    if (vi.cls == VarClass::Value) nb_undeclared.insert(encodes);
                    if (would_survive) vi.rule = "C6";
                    d = Decision::Drop;
                }
            } else if (vi.unknown) {
                if (c.unknown_policy == UnknownNames::Keep) ++c.dropped_only_by_decls;
                vi.cls = VarClass::DeclaredOut; vi.rule = "C6"; vi.unknown = false;
                d = Decision::Drop;
            } else if (d != Decision::Drop) {
                ++c.dropped_only_by_decls;
                vi.cls = VarClass::DeclaredOut; vi.rule = "C6";
                d = Decision::Drop;
            }
        }
        vi.decision = d;

        // Pending merges and counters
        if (vi.cls == VarClass::Module && o.tristate == TristateMode::Merge && d != Decision::Drop) modules.push_back({encodes, v});
        if (vi.cls == VarClass::Value && profile == Translator::KConfigReader && o.nonbool == NonBoolMode::Merge &&
            encodes_declared) {
            auto& nbo = nb_options[encodes];
            nbo.option = encodes;
            nbo.values.push_back(v);
            if (name == encodes + "_n") nbo.not_set_var = v;
        }
        if (vi.unknown && d == Decision::Keep) {
            ++c.unknown_kept;
            if (c.unknown_examples.size() < 10) c.unknown_examples.push_back(name);
        }
    }

    // Tristate pairs: X must be a kept option (R-FLT-11, R-FLT-12)
    for (const auto& m : modules) {
        int x = ctx.var_of[m.first];
        if (c.vars[x].decision == Decision::Keep && c.vars[x].cls == VarClass::Option)
            c.tristate_pairs.push_back({x, m.second});
        else
            c.vars[m.second].decision = Decision::Drop;
    }
    std::sort(c.tristate_pairs.begin(), c.tristate_pairs.end());

    for (auto& kv : nb_options) {
        if (kv.second.not_set_var) c.nonbool_options.push_back(kv.second);
        else c.nonbool_without_n.push_back(kv.first);
    }
    c.undeclared_nonbool.assign(nb_undeclared.begin(), nb_undeclared.end());
    if (profile == Translator::KConfigReader && !c.decls_given) {
        long values = 0;
        for (int v = 1; v <= f.num_vars; ++v)
            if (c.vars[v].cls == VarClass::Value) ++values;
        c.warnings.push_back("value detection for non-Boolean options is heuristic for KConfigReader formulas (R-FLT-10): " +
                             std::to_string(values) + " variables classified as VALUE. Give the declared option names with "
                             "--decls to make it exact.");
    }

    // --decls: declared names absent from the formula. A declared non-Boolean option
    // that the formula encodes with value or bit variables is not absent.
    if (c.decls_given) {
        std::unordered_set<std::string> present;
        for (int v = 1; v <= f.num_vars; ++v)
            if (f.has_name(v)) present.insert(c.vars[v].output_name);
        std::vector<std::string> all(decls.begin(), decls.end());
        std::sort(all.begin(), all.end());
        for (const auto& d : all) {
            if (present.count(d)) continue;
            if (encoded.count(d)) c.declared_encoded.push_back(d);
            else c.declared_not_found.push_back(d);
        }
    }

    // Normalisation must not create two variables with the same name (R-FLT-19): the
    // variables involved keep their original names. Repeated until no name collides,
    // because a restored name can collide with another normalised one.
    std::vector<std::string> collisions;
    for (;;) {
        std::unordered_map<std::string, std::vector<int>> by_output;
        for (int v = 1; v <= f.num_vars; ++v)
            if (c.vars[v].decision != Decision::Drop) by_output[c.vars[v].output_name].push_back(v);
        bool changed = false;
        for (auto& kv : by_output) {
            if (kv.second.size() < 2) continue;
            for (int v : kv.second) {
                // An unnamed variable has no original name: make "v<n>" unique instead
                std::string original = f.has_name(v) ? f.names[v] : c.vars[v].output_name + "_";
                if (c.vars[v].output_name != original) { c.vars[v].output_name = original; changed = true; }
            }
            collisions.push_back(kv.first);
        }
        if (!changed) break;
    }
    if (!collisions.empty()) {
        std::sort(collisions.begin(), collisions.end());
        collisions.erase(std::unique(collisions.begin(), collisions.end()), collisions.end());
        std::string ex;
        for (size_t i = 0; i < collisions.size() && i < 10; ++i) ex += (i ? ", " : "") + collisions[i];
        c.warnings.push_back(std::to_string(collisions.size()) + " names would collide after normalisation (R-FLT-19) "
                             "and keep their original names: " + ex);
    }

    if (c.unknown_kept > 0) {
        std::string ex;
        for (size_t i = 0; i < c.unknown_examples.size(); ++i) ex += (i ? ", " : "") + c.unknown_examples[i];
        c.warnings.push_back(std::to_string(c.unknown_kept) + " variables matched no rule of profile '" +
                             to_string(profile) + "' and were kept (--unknown-names keep), e.g. " + ex);
    }
    return c;
}

// ---------------------------------------------------------------------------
// Formula merges (R-FLT-10, R-FLT-11)
// ---------------------------------------------------------------------------

int apply_merges(DimacsFormula& f, Classification& c, const FilterOptions& o) {
    int added = 0;
    const Translator profile = c.detection.profile;
    // Names already used by a node; a fresh node must not repeat one of them
    std::unordered_set<std::string> taken;
    for (int v = 1; v <= f.num_vars; ++v)
        if (c.vars[v].decision == Decision::Keep || c.vars[v].decision == Decision::MergeCandidate)
            taken.insert(c.vars[v].output_name);

    auto fresh = [&](const std::string& out_name, const char* rule, const char* marker) {
        int e = f.add_variable(out_name);
        VarInfo vi;
        vi.cls = VarClass::Option;
        vi.rule = rule;
        vi.output_name = out_name;
        vi.synthetic = true;
        vi.marker = marker;
        c.vars.push_back(vi);
        taken.insert(out_name);
        ++added;
        return e;
    };

    if (o.tristate == TristateMode::Merge) {
        for (const auto& p : c.tristate_pairs) {
            const int x = p.first, xm = p.second;
            // E_X ↔ (X ∨ X_MODULE). The node takes the name of X, which stops being a node.
            const std::string name = c.vars[x].output_name;
            taken.erase(name);
            int e = fresh(name, "R-FLT-11", "tristate");
            f.clauses.push_back({-e, x, xm});
            f.clauses.push_back({-x, e});
            f.clauses.push_back({-xm, e});
            for (int m : {x, xm}) {
                c.vars[m].decision = Decision::Merged;
                c.vars[m].merged_into = e;
                c.vars[m].marker = "tristate";
            }
            c.vars[x].rule = "R-FLT-11";
            ++c.tristate_merged;
        }
    }
    if (o.nonbool == NonBoolMode::Merge) {
        for (const auto& nb : c.nonbool_options) {
            std::string name = normalise_name(nb.option, o, profile);
            if (taken.count(name)) {
                c.warnings.push_back("non-Boolean option '" + nb.option + "' cannot get a node: the name is already used "
                                     "by another variable; its value variables are dropped. Use --nonbool keep to see them.");
                continue;
            }
            // S_P ↔ ¬P_n
            int s = fresh(name, "R-FLT-10", "nonbool");
            f.clauses.push_back({-s, -nb.not_set_var});
            f.clauses.push_back({s, nb.not_set_var});
            for (int v : nb.values) {
                c.vars[v].decision = Decision::Merged;
                c.vars[v].merged_into = s;
                c.vars[v].marker = "nonbool";
            }
            ++c.nonbool_merged;
        }
    }
    return added;
}

// ---------------------------------------------------------------------------
// Documentation (R-IMP-05)
// ---------------------------------------------------------------------------

std::vector<RuleDoc> rule_tables() {
    std::vector<RuleDoc> docs;
    auto add = [&](const char* profile, const Rule* begin, const Rule* end) {
        for (const Rule* r = begin; r != end; ++r) docs.push_back({profile, r->id, r->condition, to_string(r->cls), r->action});
    };
    add("all profiles (reserved comments)", std::begin(MARKER_RULES), std::end(MARKER_RULES));
    add("kmax", std::begin(KMAX_RULES), std::end(KMAX_RULES));
    add("kconfigreader", std::begin(KCR_RULES), std::end(KCR_RULES));
    add("kconfigsampler", std::begin(KCS_RULES), std::end(KCS_RULES));
    docs.push_back({"kconfigsampler", "S7", "anything else", "`--unknown-names`", "drop (profile default)"});
    add("travart", std::begin(TRAVART_RULES), std::end(TRAVART_RULES));
    add("uvl", std::begin(UVL_RULES), std::end(UVL_RULES));
    add("generic", std::begin(GENERIC_RULES), std::end(GENERIC_RULES));
    docs.push_back({"generic", "G2", "anything else", "`--unknown-names`", "keep (profile default)"});
    const RuleDoc common[] = {
        {"common", "C5", "name matches `--keep-pattern RE` (repeatable)", "OPTION", "keep; evaluated first, overrides every other rule"},
        {"common", "C6", "`--decls FILE` given and the normalised name is not declared (and the variable does not encode a declared option)",
         "DECLARED_OUT", "drop; evaluated second. A declared name is an `OPTION` whatever the rules of the profile say (C1–C4 still apply to it)"},
        {"common", "C1", "variable has no name comment", "UNNAMED", "drop (`--unnamed`)"},
        {"common", "C2", "`^k![0-9]+$` (not in a file with the uvl2dimacs 2.0 header, where every named variable is a feature)", "TSEITIN", "drop"},
        {"common", "C3", "name listed in `--drop-names FILE`", "as given (default TSEITIN)", "drop"},
        {"common", "C4", "name matches `--drop-pattern RE` (repeatable)", "TSEITIN", "drop"},
    };
    docs.insert(docs.end(), std::begin(common), std::end(common));
    return docs;
}

std::vector<ClassDoc> class_tables() {
    return {
        {VarClass::Option, "A real configuration option or feature", "yes"},
        {VarClass::Tseitin, "Introduced by a translator when the formula is converted to clauses (`k!<n>`, `ART_<n>`, `aux_<n>`)", "no"},
        {VarClass::Chain, "Introduced by `uvl2dimacs` to split long clauses (`aux_<n>_chain_<i>`)", "no"},
        {VarClass::Visibility, "\"Option X is visible to the user\" (KMax `__VISIBILITY__CONFIG_X`)", "no (`--visibility`)"},
        {VarClass::SelectHelper, "Encodes a reverse dependency (`A__CONFIG_B`: \"B selects A\")", "no"},
        {VarClass::Placeholder, "Stands for an expression the translator could not translate (`<unsupported>`, `PREDICATE_*`, `undef`)", "no"},
        {VarClass::Module, "Second variable of a tristate option: \"X is built as a module\" (KConfigReader `X_MODULE`)",
         "merged with `X` into one node (`--tristate`)"},
        {VarClass::Choice, "One per choice group (KConfigReader `CHOICE_<n>`)", "no"},
        {VarClass::Value, "\"Non-Boolean option P has value v\" or \"P is not set\" (`string_P_EQ_v`, `int_P_EQ_v`, KConfigReader `P_<v>`, `P_nonempty`, `P_n`, `P_`)",
         "no; with `--nonbool merge` (default) KConfigReader's `P_n` yields one node `P`"},
        {VarClass::Bitvector, "One bit of an integer option encoded in binary (`BIT_<k>_BITMAP_int_P`, `BITMAP_INT_MASTER_BITMAP_int_P`, `SIGN_BITMAP_int_P`)", "no"},
        {VarClass::Environment, "Value of an environment variable (`ENV_string_…`)", "no"},
        {VarClass::AbstractGroup, "Abstract, mandatory feature of the original model that only holds a group and is therefore equivalent to its parent (TraVarT `X_xor`, `X_or`, `X_alt`)",
         "merged into its parent's atomic set (`--abstract-groups`)"},
        {VarClass::Root, "Synthetic root (`__Root__`) or the UVL root, if it is not abstract",
         "UVL root: yes (it is core); synthetic root: no (`--synthetic-root`)"},
        {VarClass::Abstract, "UVL feature marked `{abstract}`, the root included", "no (`--abstract`; `keep` keeps it, `merge` merges it into an equivalent feature)"},
        {VarClass::Unnamed, "A variable without a `c <n> <name>` comment", "no (`--unnamed`)"},
        {VarClass::DeclaredOut, "Not in the list of declared names given with `--decls`", "no"},
    };
}

void write_rules_markdown(std::ostream& out) {
    auto esc = [](const std::string& s) {
        std::string o;
        for (char ch : s) o += (ch == '|') ? std::string("\\|") : std::string(1, ch);
        return o;
    };
    out << "# Strong4VM filters\n\n"
           "<!-- Generated by `strong4vm --print-rules-md` from the tables in\n"
           "     dimacs2graphs/filter/Classifier.cc. Do not edit by hand: run `make docs-filters`. -->\n\n"
           "Strong4VM keeps the variables of the formula that are real options of the system and drops (or merges)\n"
           "all the others. Every variable receives exactly one **class** and one **decision** (`kept`, `dropped`\n"
           "or `merged_into:<name>`); both are written, with the identifier of the rule that decided, to\n"
           "`<prefix>__variables.csv`. Filtering only decides which variables are queried and written: the formula\n"
           "is left untouched, so the relations among the kept options do not change. The exceptions are the\n"
           "explicit merges of `--tristate merge` and `--nonbool merge`, which add defined variables.\n\n"
           "## Classes of variables\n\n"
           "| Class | Meaning | Kept by default |\n|---|---|---|\n";
    for (const auto& d : class_tables())
        out << "| `" << to_string(d.cls) << "` | " << esc(d.meaning) << " | " << esc(d.kept) << " |\n";
    out << "\n## Choosing the profile\n\n"
           "`--translator {auto, kmax, kconfigreader, kconfigsampler, travart, uvl, generic}`, default `auto`.\n"
           "With `auto` the first match wins:\n\n"
           "1. the input is a `.uvl` file → `uvl`;\n"
           "2. the DIMACS file has the comment `c generated-by uvl2dimacs` → `uvl`;\n"
           "3. the file name contains `__KMax`, `__KConfigReader`, `__KconfigSampler` or `__TraVarT` → that profile;\n"
           "4. content signatures, in this order:\n"
           "   - a `__VISIBILITY__` name or the name `<unsupported>` → `kmax`;\n"
           "   - a `CHOICE_<n>` name, or at least ten `X_MODULE` names whose `X` also exists → `kconfigreader`;\n"
           "   - an `ART_<n>` name together with a `boolean_` name → `kconfigsampler`;\n"
           "   - a name ending in `_xor`, `_or` or `_alt`, or a name `root` / `__Root__` → `travart`\n"
           "     (weak evidence: a warning is issued);\n"
           "   - the comment `c Generated by UVL2Dimacs` of uvl2dimacs 1.x → `uvl`;\n"
           "5. otherwise → `generic`.\n\n"
           "The profile is printed and recorded in `__summary.json` (`input.translator`); `--translator` overrides it.\n\n"
           "## Order of evaluation\n\n"
           "The first rule that applies decides:\n\n"
           "1. **C5**, `--keep-pattern`: explicit keep;\n"
           "2. **C6**, `--decls`: a declared name is an option, whatever the rules of the profile say about it; an\n"
           "   undeclared variable is kept only if it encodes a declared option (the module variable of a tristate,\n"
           "   the value variables of a non-Boolean option), in which case `--tristate` / `--nonbool` decide how that\n"
           "   option is represented. An undeclared variable that a rule of the profile drops anyway keeps the class\n"
           "   of that rule; `DECLARED_OUT` is the class of an undeclared name that would otherwise be an option;\n"
           "3. the rules of the profile for artificial and special variables (reserved comments first);\n"
           "4. **C1–C4**, the rules common to all profiles (they also apply to a declared name that no rule of\n"
           "   step 3 has matched, so `--drop-names` and `--drop-pattern` can drop a declared option);\n"
           "5. the rules of the profile that keep a name as an option (the \"everything else\" rows K6, R6, T3, U5 and\n"
           "   the prefix rules S2, S6). They are the residual, so C1–C4 hold in every profile and `--drop-names` /\n"
           "   `--drop-pattern` can drop any option;\n"
           "6. `--unknown-names {keep, drop, error}` for names that no rule matches (default: `drop` in `kmax`,\n"
           "   `kconfigreader` and `kconfigsampler`; `keep` in `travart`, `uvl` and `generic`).\n\n"
           "## Rules\n";
    std::string current;
    for (const auto& d : rule_tables()) {
        if (d.profile != current) {
            current = d.profile;
            out << "\n### "
                << (current == "common" ? std::string("Rules common to all profiles")
                    : current.compare(0, 12, "all profiles") == 0 ? std::string("Reserved comments of uvl2dimacs 2.0 (every profile)")
                    : "Profile `" + current + "`")
                << "\n\n| Rule | Condition | Class | Default action |\n|---|---|---|---|\n";
        }
        out << "| " << d.id << " | " << esc(d.condition) << " | " << d.cls << " | " << esc(d.action) << " |\n";
    }
    out << "\n## Names\n\n"
           "Before matching against `--decls` and before writing (R-FLT-19):\n\n"
           "- in the profile `kconfigsampler`, the type prefixes `boolean_` and `tristate_` are stripped\n"
           "  (switch off with `--keep-type-prefix`);\n"
           "- the prefix `CONFIG_` is stripped only with `--strip-config-prefix`.\n\n"
           "Normalisation never creates two nodes with the same name: the variables that would collide keep their\n"
           "original names and a warning is issued.\n\n"
           "## After solving\n\n"
           "- **T2** (TraVarT abstract group features): a candidate that is in an atomic set with a variable that is\n"
           "  not a candidate is merged into it and listed in `__atomic.txt` with the marker `[abstract-group]`;\n"
           "  a candidate that is equivalent to no other variable is kept as `OPTION` and a warning is issued.\n"
           "- **U4** with `--abstract merge`: an abstract feature that is in an atomic set with a feature that is not\n"
           "  abstract is merged into it and listed in `__atomic.txt` with the marker `[abstract]`; an abstract feature\n"
           "  that is equivalent to none (it stands for a choice, such as a group of alternatives) is kept as `ABSTRACT`.\n"
           "  A core (dead) abstract feature is merged into a core (dead) feature that is not abstract, if there is one.\n"
           "- **Core and dead options** are written to `__core.txt` and `__dead.txt` and are not vertices of the graphs\n"
           "  (`--fixed-nodes drop`, default); artificial variables are never listed there.\n";
}

} // namespace dimacs2graphs
