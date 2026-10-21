// Console output and termination for the C++ engine of variplex.
//
// The sources in s4/ and antlr4/ come from Strong4VM (tools/sync_cpp.R copies them). That script rewrites their uses
// of std::cout, std::cerr, printf, fprintf(stderr, ...) and exit() into the functions below, which is what R requires
// of compiled code: output goes through R's console, and an error ends the R call, not the R session.
#ifndef VARIPLEX_VP_IO_H
#define VARIPLEX_VP_IO_H

#include <ostream>
#include <stdexcept>
#include <string>

namespace vp {

// Streams that print on the R console. Output from a thread other than R's main thread is dropped: R's API may only
// be called from the main thread.
std::ostream& out();
std::ostream& err();

// While capturing, what is written to err() is kept instead of printed, so that the R interface can turn warnings
// into R warnings without printing them twice. stop_capture() returns what was kept.
void start_capture();
std::string stop_capture();

// Thrown instead of terminating the process. The R interface turns it into an R error.
struct exit_error : std::runtime_error {
    int status;
    explicit exit_error(int s) : std::runtime_error("the engine stopped with status " + std::to_string(s)), status(s) {}
};

}  // namespace vp

void vp_printf(const char* fmt, ...);
void vp_eprintf(const char* fmt, ...);
void vp_puts(const char* s);
[[noreturn]] void vp_exit(int status);

#endif
