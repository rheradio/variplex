#include "vp_io.h"

#include <cstdarg>
#include <cstdio>
#include <streambuf>
#include <thread>
#include <vector>

#include <R_ext/Print.h>

namespace {

// Static initialisation runs when R loads the shared library, on R's main thread.
const std::thread::id main_thread = std::this_thread::get_id();

bool on_main_thread() { return std::this_thread::get_id() == main_thread; }

bool capturing = false;
std::string captured;

// A buffer that hands complete pieces of text to Rprintf or REprintf.
class RBuf : public std::streambuf {
public:
    explicit RBuf(bool error) : error_(error) {}

protected:
    int overflow(int c) override {
        if (c != EOF) {
            char ch = static_cast<char>(c);
            xsputn(&ch, 1);
        }
        return c;
    }
    std::streamsize xsputn(const char* s, std::streamsize n) override {
        if (on_main_thread()) {
            std::string text(s, static_cast<size_t>(n));
            if (error_ && capturing) captured += text;
            else if (error_) REprintf("%s", text.c_str());
            else Rprintf("%s", text.c_str());
        }
        return n;
    }

private:
    bool error_;
};

RBuf out_buf(false), err_buf(true);
std::ostream out_stream(&out_buf), err_stream(&err_buf);

void vprint(bool error, const char* fmt, va_list ap) {
    if (!on_main_thread()) return;
    va_list copy;
    va_copy(copy, ap);
    int n = std::vsnprintf(nullptr, 0, fmt, copy);
    va_end(copy);
    if (n < 0) return;
    std::vector<char> buf(static_cast<size_t>(n) + 1);
    std::vsnprintf(buf.data(), buf.size(), fmt, ap);
    if (error && capturing) captured += buf.data();
    else if (error) REprintf("%s", buf.data());
    else Rprintf("%s", buf.data());
}

}  // namespace

std::ostream& vp::out() { return out_stream; }
std::ostream& vp::err() { return err_stream; }

void vp::start_capture() {
    capturing = true;
    captured.clear();
}

std::string vp::stop_capture() {
    capturing = false;
    std::string s;
    s.swap(captured);
    return s;
}

void vp_printf(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vprint(false, fmt, ap);
    va_end(ap);
}

void vp_eprintf(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vprint(true, fmt, ap);
    va_end(ap);
}

void vp_puts(const char* s) {
    if (on_main_thread()) Rprintf("%s\n", s);
}

void vp_exit(int status) { throw vp::exit_error(status); }
