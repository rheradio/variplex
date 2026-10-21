/**
 * @file Json.hh
 * @brief Minimal JSON value with deterministic output (no external dependency)
 *
 * Objects keep insertion order, so two runs produce byte-identical files.
 * Members and items are stored in std::deque: a reference obtained with
 * operator[] or push() stays valid when more members are added. The two
 * containers are held through pointers, created when first needed: a class
 * cannot hold a std::deque of itself by value (the C++ standard allows an
 * incomplete element type only in vector, list and forward_list, and libc++,
 * the standard library of macOS, refuses it).
 */

#ifndef DIMACS2GRAPHS_JSON_HH
#define DIMACS2GRAPHS_JSON_HH

#include <cstdint>
#include <deque>
#include <memory>
#include <ostream>
#include <string>
#include <utility>
#include <vector>

namespace dimacs2graphs {

class Json {
public:
    enum class Type { Null, Bool, Int, Real, String, Array, Object };

    // Construction, copy and destruction are compiled once, in the library (Json.cc), not in every
    // program that includes this header: a Json holds containers of Json, and a program built with other
    // compiler options than the library must not carry its own copies of that code.
    Json();
    Json(const Json& other);
    Json(Json&& other);
    Json& operator=(const Json& other);
    Json& operator=(Json&& other);
    ~Json();

    Json(std::nullptr_t);
    Json(bool b);
    Json(int i);
    Json(long i);
    Json(long long i);
    Json(unsigned i);
    Json(unsigned long i);
    Json(unsigned long long i);
    Json(double d);
    Json(const char* s);
    Json(std::string s);

    static Json array();
    static Json object();
    template <class T> static Json array_of(const std::vector<T>& v) {
        Json j = array();
        for (const auto& x : v) j.push(Json(x));
        return j;
    }

    Type type() const { return type_; }

    /// Appends to an array (converts Null to Array).
    Json& push(Json v);
    /// Object member: returns the existing value or inserts Null (converts Null to Object).
    Json& operator[](const std::string& key);
    /// Lookup without insertion; nullptr if absent or not an object.
    const Json* find(const std::string& key) const;

    bool as_bool() const { return b_; }
    long long as_int() const { return type_ == Type::Real ? static_cast<long long>(d_) : i_; }
    double as_real() const { return type_ == Type::Int ? static_cast<double>(i_) : d_; }
    const std::string& as_string() const { return s_; }
    /// The items of an array (empty for any other value).
    const std::deque<Json>& items() const;
    /// The members of an object, in insertion order (empty for any other value).
    const std::deque<std::pair<std::string, Json>>& members() const;

    void dump(std::ostream& out, int indent = 2) const;
    std::string dump(int indent = 2) const;

    /// Parses JSON text (used to read summaries back). Returns false on syntax error.
    static bool parse(const std::string& text, Json& out, std::string& error);

    /// `s` as a JSON string. JSON text is UTF-8: a byte that is not part of a well-formed UTF-8 sequence is
    /// written as U+FFFD (the replacement character), so that the text is valid whatever the bytes of `s` are.
    static std::string escape(const std::string& s);
    /// True if `s` is well-formed UTF-8.
    static bool valid_utf8(const std::string& s);

private:
    void dump_rec(std::ostream& out, int indent, int level) const;

    Type type_ = Type::Null;
    bool b_ = false;
    long long i_ = 0;
    double d_ = 0;
    std::string s_;
    std::unique_ptr<std::deque<Json>> arr_;                            ///< Items, once there is one
    std::unique_ptr<std::deque<std::pair<std::string, Json>>> obj_;    ///< Members, once there is one
};

} // namespace dimacs2graphs

#endif
