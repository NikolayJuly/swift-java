# swift-java minimal fork

Minimal fork of [swiftlang/swift-java](https://github.com/swiftlang/swift-java) for JNI bridging.
Remote: `NikolayJuly/swift-java`, branch: `minimal`.

## Structure

```
Sources/
  CSwiftJavaJNI/          — C headers (jni.h wrappers), inlined from swift-java-jni-core
  CSwiftJavaSignalStubs/  — C signal stubs for ART libsigchain (separate product, no deps)
  SwiftJavaJNICore/       — Swift JNI runtime, inlined from swift-java-jni-core
    VirtualMachine/       — JavaVirtualMachine, loadLibJava(), LockedState, ThreadLocalStorage
  SwiftJava/              — Main library: JavaObject, macros, method calls
    AndroidJVMBootstrap.swift — initializeAndroidJVMForTests() (Android-only)
  JavaStdlib/
    JavaUtil/             — Java stdlib wrappers (Collections, Map, List, etc.)
    JavaNet/              — Java net wrappers (URL, URLConnection, etc.)
    JavaIO/               — Java IO wrappers (File, InputStream, etc.)
  SwiftJavaMacros/        — Macro source, compiled as .macro target
Tests/
  AndroidJVMTest/         — Standalone executable: creates ART JVM, verifies JNI (Android-only)
```

## Key decisions

- **swift-syntax is the only external dependency.** Required for .macro target (SwiftJavaMacros).
  Compile-time only — does not end up in Android binary. ~47s first build, cached after.
- **swift-java-jni-core sources inlined.** CSwiftJavaJNI and SwiftJavaJNICore copied into this repo.
- **`traits: []`** is required in Package initializer for SPM 6.2 compatibility.
- **JNI headers inlined.** `jni.h` and `jni_md.h` (darwin) are in `Sources/CSwiftJavaJNI/include/jdk-jni/`.
  On macOS: `#include "jdk-jni/jni.h"` (local, no JAVA_HOME needed).
  On Android: `#include <jni.h>` (system, from NDK sysroot).
  `findJavaHome()` returns empty string if not found (no fatalError).
  JAVA_HOME is only used for linker settings (`-L`, `-rpath` to link jvm) — guarded by `.when(platforms:)`.

## Android JVM Bootstrap

For standalone binaries on Android (test executables), JVM must be created manually.

- **`AndroidSupport.cpp` removed.** Upstream (swift-java-jni-core) removed it too. Replaced by
  `loadLibJava()` in Swift — does `dlopen("libart.so")` with APEX paths for API 29+, then
  `dlsym("JNI_CreateJavaVM")`. No C++ code needed.
- **Signal stubs in separate C target** (`CSwiftJavaSignalStubs`). ART's libsigchain requires
  `AddSpecialSignalHandlerFn` and `SetSpecialSignalHandlerFn` symbols. Android's `RTLD_DEFAULT`
  does NOT find them in `.so` dependencies — they must be in the main executable. So stubs are
  a separate static C target with no dependencies. Consumer links it + adds `-u`/`--export-dynamic`
  linker flags on their executable/test target.
- **`initializeAndroidJVMForTests()`** in SwiftJava. Reads `BOOTCLASSPATH` from env, passes
  ART options, calls `JavaVirtualMachine.shared()`. `javaLibraryPath` is a parameter (default
  `/data/local/tmp/tests`).
- **`AndroidJVMTest`** — executable target in `Tests/AndroidJVMTest/`. Creates JVM, calls
  `System.getProperty("java.vm.name")` via raw JNI. Verified on API 29 emulator.
- **API 29+ only** for standalone JVM bootstrap. API 28 blocked by SELinux (patchoat/dex2oat).

## Why .macro and not pre-built binary

Pre-built binary via `-load-plugin-executable` unsafeFlag worked on macOS but broke Android
cross-compilation (`swift build --swift-sdk`). SPM doesn't pass unsafeFlags to the compiler
during cross-compilation. `.macro` target is the only approach that works for both platforms —
SPM builds the macro for the host automatically.

## Adding new targets that use macros

Any target using `@JavaClass`, `@JavaMethod`, etc. must depend on `SwiftJavaMacros`
(directly or transitively through `SwiftJava`).

## Syncing with upstream

- `Sources/SwiftJava/` ← cherry-pick from `swiftlang/swift-java`
- `Sources/JavaStdlib/` ← cherry-pick from `swiftlang/swift-java`
- `Sources/CSwiftJavaJNI/`, `Sources/SwiftJavaJNICore/` ← check `swiftlang/swift-java-jni-core`
- `Sources/SwiftJavaMacros/` ← cherry-pick from `swiftlang/swift-java`
