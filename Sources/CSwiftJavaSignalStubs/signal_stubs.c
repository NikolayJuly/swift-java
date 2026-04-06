// signal_stubs.c

// ART's libsigchain requires these symbols in the main executable on Android.
// Confirmed needed on API 28 and API 29.
// See CSwiftJavaSignalStubs.h for consumer linker flag requirements.

#ifdef __ANDROID__

#include <stdbool.h>

__attribute__((visibility("default")))
void AddSpecialSignalHandlerFn(int signal, void* sa_sigaction, bool* claimed) {
    (void)signal;
    (void)sa_sigaction;
    if (claimed) *claimed = false;
}

__attribute__((visibility("default")))
void SetSpecialSignalHandlerFn(int signal, void* sa_sigaction) {
    (void)signal;
    (void)sa_sigaction;
}

#endif
