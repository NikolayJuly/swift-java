// signal_stubs.c

// Minimal signal chain implementation for standalone Android binaries.
// ART's FaultManager registers signal handlers via AddSpecialSignalHandlerFn
// for SIGSEGV/SIGBUS (null checks, stack overflow). Without a working signal
// chain, no-op stubs break BoringSSL's CPUID probing on x86_64.
//
// This implements a real signal chain: handlers registered by ART get first
// chance to handle the signal. If none claims it, the previous handler runs.

#ifdef __ANDROID__

#include <signal.h>
#include <string.h>
#include <stddef.h>

typedef int (*SpecialHandlerFn)(int, siginfo_t *, void *);

typedef struct {
    SpecialHandlerFn handler;
    int claimed;
} SigchainAction;

#define MAX_SIGNALS 64
#define MAX_HANDLERS 4

static SigchainAction g_handlers[MAX_SIGNALS][MAX_HANDLERS];
static int g_handler_count[MAX_SIGNALS];
static struct sigaction g_old_actions[MAX_SIGNALS];

static void chain_handler(int sig, siginfo_t *info, void *ctx) {
    for (int i = 0; i < g_handler_count[sig]; i++) {
        if (g_handlers[sig][i].handler &&
            g_handlers[sig][i].handler(sig, info, ctx)) {
            return;
        }
    }
    // No handler claimed — forward to previous handler
    if (g_old_actions[sig].sa_flags & SA_SIGINFO) {
        if (g_old_actions[sig].sa_sigaction) {
            g_old_actions[sig].sa_sigaction(sig, info, ctx);
        }
    } else {
        if (g_old_actions[sig].sa_handler != SIG_DFL &&
            g_old_actions[sig].sa_handler != SIG_IGN) {
            g_old_actions[sig].sa_handler(sig);
        }
    }
}

static void ensure_chain(int signal) {
    if (signal < 0 || signal >= MAX_SIGNALS) return;
    if (g_handler_count[signal] == 0) {
        struct sigaction sa;
        memset(&sa, 0, sizeof(sa));
        sa.sa_sigaction = chain_handler;
        sa.sa_flags = SA_SIGINFO | SA_RESTART;
        sigfillset(&sa.sa_mask);
        sigaction(signal, &sa, &g_old_actions[signal]);
    }
}

__attribute__((visibility("default")))
void AddSpecialSignalHandlerFn(int signal, SigchainAction *act) {
    if (signal < 0 || signal >= MAX_SIGNALS || !act) return;
    ensure_chain(signal);
    int idx = g_handler_count[signal];
    if (idx < MAX_HANDLERS) {
        g_handlers[signal][idx] = *act;
        g_handler_count[signal]++;
    }
}

__attribute__((visibility("default")))
void SetSpecialSignalHandlerFn(int signal, SigchainAction *act) {
    if (signal < 0 || signal >= MAX_SIGNALS || !act) return;
    ensure_chain(signal);
    g_handlers[signal][0] = *act;
    if (g_handler_count[signal] == 0)
        g_handler_count[signal] = 1;
}

#endif // __ANDROID__
