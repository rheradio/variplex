/**
 * @file Json.cc
 * @brief Minimal JSON writer/reader (see Json.hh)
 */

#include "Json.hh"

#include <cctype>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <sstream>

namespace dimacs2graphs {

Json::Json() = default;
Json::Json(const Json& other)
    : type_(other.type_), b_(other.b_), i_(other.i_), d_(other.d_), s_(other.s_),
      arr_(other.arr_ ? std::make_unique<std::deque<Json>>(*other.arr_) : nullptr),
      obj_(other.obj_ ? std::make_unique<std::deque<std::pair<std::string, Json>>>(*other.obj_) : nullptr) {}
Json::Json(Json&& other) = default;
Json& Json::operator=(const Json& other) {
    if (this != &other) {
        Json copy(other);   // first: `other` may be a part of this value
        *this = std::move(copy);
    }
    return *this;
}
Json& Json::operator=(Json&& other) = default;
Json::~Json() = default;

Json::Json(std::nullptr_t) {}
Json::Json(bool b) : type_(Type::Bool), b_(b) {}
Json::Json(int i) : type_(Type::Int), i_(i) {}
Json::Json(long i) : type_(Type::Int), i_(i) {}
Json::Json(long long i) : type_(Type::Int), i_(i) {}
Json::Json(unsigned i) : type_(Type::Int), i_(i) {}
Json::Json(unsigned long i) : type_(Type::Int), i_(static_cast<long long>(i)) {}
Json::Json(unsigned long long i) : type_(Type::Int), i_(static_cast<long long>(i)) {}
Json::Json(double d) : type_(Type::Real), d_(d) {}
Json::Json(const char* s) : type_(Type::String), s_(s) {}
Json::Json(std::string s) : type_(Type::String), s_(std::move(s)) {}

Json Json::array() { Json j; j.type_ = Type::Array; return j; }
Json Json::object() { Json j; j.type_ = Type::Object; return j; }

const std::deque<Json>& Json::items() const {
    static const std::deque<Json> none;
    return arr_ ? *arr_ : none;
}

const std::deque<std::pair<std::string, Json>>& Json::members() const {
    static const std::deque<std::pair<std::string, Json>> none;
    return obj_ ? *obj_ : none;
}

Json& Json::push(Json v) {
    if (type_ == Type::Null) type_ = Type::Array;
    if (!arr_) arr_ = std::make_unique<std::deque<Json>>();
    arr_->push_back(std::move(v));
    return arr_->back();
}

Json& Json::operator[](const std::string& key) {
    if (type_ == Type::Null) type_ = Type::Object;
    if (!obj_) obj_ = std::make_unique<std::deque<std::pair<std::string, Json>>>();
    for (auto& m : *obj_)
        if (m.first == key) return m.second;
    obj_->emplace_back(key, Json());
    return obj_->back().second;
}

const Json* Json::find(const std::string& key) const {
    if (type_ != Type::Object) return nullptr;
    for (auto& m : members())
        if (m.first == key) return &m.second;
    return nullptr;
}

namespace {
// Length of the well-formed UTF-8 sequence that starts at s[i] (1 to 4), or 0 if there is none
size_t utf8_sequence(const std::string& s, size_t i) {
    const unsigned char c = static_cast<unsigned char>(s[i]);
    auto cont = [&](size_t k) { return i + k < s.size() && (static_cast<unsigned char>(s[i + k]) & 0xC0) == 0x80; };
    if (c < 0x80) return 1;
    if (c >= 0xC2 && c <= 0xDF) return cont(1) ? 2 : 0;
    if (c >= 0xE0 && c <= 0xEF) {
        if (!cont(1) || !cont(2)) return 0;
        const unsigned char d = static_cast<unsigned char>(s[i + 1]);
        if ((c == 0xE0 && d < 0xA0) || (c == 0xED && d > 0x9F)) return 0;   // overlong form, surrogate
        return 3;
    }
    if (c >= 0xF0 && c <= 0xF4) {
        if (!cont(1) || !cont(2) || !cont(3)) return 0;
        const unsigned char d = static_cast<unsigned char>(s[i + 1]);
        if ((c == 0xF0 && d < 0x90) || (c == 0xF4 && d > 0x8F)) return 0;   // overlong form, above U+10FFFF
        return 4;
    }
    return 0;
}
}  // namespace

bool Json::valid_utf8(const std::string& s) {
    for (size_t i = 0; i < s.size();) {
        const size_t n = utf8_sequence(s, i);
        if (!n) return false;
        i += n;
    }
    return true;
}

std::string Json::escape(const std::string& s) {
    std::string o;
    o.reserve(s.size() + 2);
    o += '"';
    for (size_t i = 0; i < s.size(); ++i) {
        const unsigned char c = static_cast<unsigned char>(s[i]);
        if (c >= 0x80) {
            const size_t n = utf8_sequence(s, i);
            if (!n) { o += "\\ufffd"; continue; }
            o.append(s, i, n);
            i += n - 1;
            continue;
        }
        switch (c) {
            case '"': o += "\\\""; break;
            case '\\': o += "\\\\"; break;
            case '\n': o += "\\n"; break;
            case '\r': o += "\\r"; break;
            case '\t': o += "\\t"; break;
            case '\b': o += "\\b"; break;
            case '\f': o += "\\f"; break;
            default:
                if (c < 0x20) {
                    char buf[8];
                    std::snprintf(buf, sizeof buf, "\\u%04x", c);
                    o += buf;
                } else {
                    o += static_cast<char>(c);
                }
        }
    }
    o += '"';
    return o;
}

void Json::dump(std::ostream& out, int indent) const {
    dump_rec(out, indent, 0);
    out << '\n';
}

std::string Json::dump(int indent) const {
    std::ostringstream os;
    dump(os, indent);
    return os.str();
}

void Json::dump_rec(std::ostream& out, int indent, int level) const {
    auto nl = [&](int l) {
        if (indent <= 0) return;
        out << '\n';
        for (int i = 0; i < l * indent; ++i) out << ' ';
    };
    switch (type_) {
        case Type::Null: out << "null"; break;
        case Type::Bool: out << (b_ ? "true" : "false"); break;
        case Type::Int: out << i_; break;
        case Type::Real: {
            if (!std::isfinite(d_)) { out << "null"; break; }
            char buf[32];
            std::snprintf(buf, sizeof buf, "%.6g", d_);
            out << buf;
            break;
        }
        case Type::String: out << escape(s_); break;
        case Type::Array: {
            const auto& arr = items();
            if (arr.empty()) { out << "[]"; break; }
            bool scalars = true;
            for (auto& a : arr)
                if (a.type_ == Type::Array || a.type_ == Type::Object) scalars = false;
            out << '[';
            for (size_t i = 0; i < arr.size(); ++i) {
                if (i) out << (scalars ? ", " : ",");
                if (!scalars) nl(level + 1);
                arr[i].dump_rec(out, indent, level + 1);
            }
            if (!scalars) nl(level);
            out << ']';
            break;
        }
        case Type::Object: {
            const auto& obj = members();
            if (obj.empty()) { out << "{}"; break; }
            out << '{';
            for (size_t i = 0; i < obj.size(); ++i) {
                if (i) out << ',';
                nl(level + 1);
                out << escape(obj[i].first) << (indent > 0 ? ": " : ":");
                obj[i].second.dump_rec(out, indent, level + 1);
            }
            nl(level);
            out << '}';
            break;
        }
    }
}

namespace {

struct Parser {
    const std::string& s;
    size_t p = 0;
    std::string err;

    void ws() { while (p < s.size() && std::isspace(static_cast<unsigned char>(s[p]))) ++p; }
    bool fail(const std::string& m) { if (err.empty()) err = m + " at offset " + std::to_string(p); return false; }

    bool str(std::string& o) {
        if (p >= s.size() || s[p] != '"') return fail("expected string");
        ++p;
        while (p < s.size() && s[p] != '"') {
            char c = s[p++];
            if (c != '\\') { o += c; continue; }
            if (p >= s.size()) return fail("bad escape");
            char e = s[p++];
            switch (e) {
                case 'n': o += '\n'; break;
                case 't': o += '\t'; break;
                case 'r': o += '\r'; break;
                case 'b': o += '\b'; break;
                case 'f': o += '\f'; break;
                case 'u': {
                    if (p + 4 > s.size()) return fail("bad \\u escape");
                    unsigned v = std::strtoul(s.substr(p, 4).c_str(), nullptr, 16);
                    p += 4;
                    if (v < 0x80) o += static_cast<char>(v);
                    else if (v < 0x800) { o += static_cast<char>(0xC0 | (v >> 6)); o += static_cast<char>(0x80 | (v & 0x3F)); }
                    else { o += static_cast<char>(0xE0 | (v >> 12)); o += static_cast<char>(0x80 | ((v >> 6) & 0x3F)); o += static_cast<char>(0x80 | (v & 0x3F)); }
                    break;
                }
                default: o += e;
            }
        }
        if (p >= s.size()) return fail("unterminated string");
        ++p;
        return true;
    }

    bool val(Json& o) {
        ws();
        if (p >= s.size()) return fail("unexpected end");
        char c = s[p];
        if (c == '{') {
            ++p; o = Json::object(); ws();
            if (p < s.size() && s[p] == '}') { ++p; return true; }
            for (;;) {
                ws(); std::string k;
                if (!str(k)) return false;
                ws(); if (p >= s.size() || s[p] != ':') return fail("expected ':'");
                ++p;
                if (!val(o[k])) return false;
                ws();
                if (p < s.size() && s[p] == ',') { ++p; continue; }
                if (p < s.size() && s[p] == '}') { ++p; return true; }
                return fail("expected ',' or '}'");
            }
        }
        if (c == '[') {
            ++p; o = Json::array(); ws();
            if (p < s.size() && s[p] == ']') { ++p; return true; }
            for (;;) {
                Json e;
                if (!val(e)) return false;
                o.push(std::move(e)); ws();
                if (p < s.size() && s[p] == ',') { ++p; continue; }
                if (p < s.size() && s[p] == ']') { ++p; return true; }
                return fail("expected ',' or ']'");
            }
        }
        if (c == '"') { std::string t; if (!str(t)) return false; o = Json(t); return true; }
        if (s.compare(p, 4, "true") == 0) { p += 4; o = Json(true); return true; }
        if (s.compare(p, 5, "false") == 0) { p += 5; o = Json(false); return true; }
        if (s.compare(p, 4, "null") == 0) { p += 4; o = Json(); return true; }
        size_t q = p;
        if (q < s.size() && (s[q] == '-' || s[q] == '+')) ++q;
        bool real = false;
        while (q < s.size() && (std::isdigit(static_cast<unsigned char>(s[q])) || s[q] == '.' || s[q] == 'e' || s[q] == 'E' || s[q] == '-' || s[q] == '+')) {
            if (s[q] == '.' || s[q] == 'e' || s[q] == 'E') real = true;
            ++q;
        }
        if (q == p) return fail("unexpected character");
        std::string num = s.substr(p, q - p);
        p = q;
        if (real) o = Json(std::strtod(num.c_str(), nullptr));
        else o = Json(std::strtoll(num.c_str(), nullptr, 10));
        return true;
    }
};

}  // namespace

bool Json::parse(const std::string& text, Json& out, std::string& error) {
    Parser ps{text, 0, std::string()};
    if (!ps.val(out)) { error = ps.err; return false; }
    ps.ws();
    if (ps.p != text.size()) { error = "trailing characters at offset " + std::to_string(ps.p); return false; }
    return true;
}

} // namespace dimacs2graphs
