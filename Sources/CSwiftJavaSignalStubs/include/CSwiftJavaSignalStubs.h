// CSwiftJavaSignalStubs.h

// No-op signal handler stubs required by ART's libsigchain on Android.
//
// ART calls dlsym(RTLD_DEFAULT, "AddSpecialSignalHandlerFn") and
// dlsym(RTLD_DEFAULT, "SetSpecialSignalHandlerFn") when libart.so is loaded.
// If not found — the process aborts.
//
// These symbols MUST end up in the main executable's dynamic symbol table.
// They cannot live in a .so — Android's RTLD_DEFAULT does not search .so
// dependencies for these symbols.
//
// Consumer's executable/test target must:
// 1. Depend on CSwiftJavaSignalStubs
// 2. Add linker flags to pull the symbols from the static archive and export them:
//
//    linkerSettings: [
//        .unsafeFlags([
//            "-Xlinker", "-u", "-Xlinker", "SetSpecialSignalHandlerFn",
//            "-Xlinker", "-u", "-Xlinker", "AddSpecialSignalHandlerFn",
//            "-Xlinker", "--export-dynamic",
//        ], .when(platforms: [.android])),
//    ]

#ifndef CSwiftJavaSignalStubs_h
#define CSwiftJavaSignalStubs_h

#endif
