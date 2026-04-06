# Swift Java Interoperability — Minimal Fork

Minimal fork of [swiftlang/swift-java](https://github.com/swiftlang/swift-java) for JNI bridging on Android.

Upstream contains ~20 targets, plugins, Gradle integration, code generators, and heavy dependencies (swift-syntax, swift-argument-parser, swift-collections, etc.). This fork keeps only what's needed for runtime JNI bridging.

## What's included

| Target | Purpose | Source |
|--------|---------|--------|
| `CSwiftJavaJNI` | C headers: `JNIEnv`, `jobject`, `jstring`, `jboolean`, etc. | Inlined from [swift-java-jni-core](https://github.com/swiftlang/swift-java-jni-core) |
| `SwiftJavaJNICore` | JNI runtime: type demangling, bridged values, `JavaVirtualMachine` | Inlined from [swift-java-jni-core](https://github.com/swiftlang/swift-java-jni-core) |
| `SwiftJavaMacros` | `@JavaClass`, `@JavaMethod`, `@JavaImplementation`, etc. | `.macro` target, compiled from source |
| `SwiftJava` | High-level API: `JavaObject`, `String(fromJNI:)`, method calls | Original `Sources/SwiftJava` |
| `JavaUtil` | Java stdlib: Collections, Map, List, Iterator, etc. | Original `Sources/JavaStdlib/JavaUtil` |
| `JavaNet` | Java net: URL, URLConnection, etc. | Original `Sources/JavaStdlib/JavaNet` |
| `JavaIO` | Java IO: File, InputStream, OutputStream, etc. | Original `Sources/JavaStdlib/JavaIO` |
| `CSwiftJavaSignalStubs` | No-op signal handler stubs for ART's libsigchain | Android-only C target, separate product |
| `AndroidJVMTest` | Test executable: creates ART JVM from standalone binary, verifies JNI communication | Android-only, not a library product |

Dependency chain: `SwiftJava` → `SwiftJavaJNICore` → `CSwiftJavaJNI`, plus `SwiftJavaMacros` (`.macro` target).
`JavaUtil`, `JavaNet`, `JavaIO` depend on `SwiftJava`.
`CSwiftJavaSignalStubs` has no dependencies — it's a standalone C target.

## What's removed (and why)

Everything below was removed because it's not needed for runtime JNI usage from Swift on Android:

- **Unused JavaStdlib targets** (`JavaUtilFunction`, `JavaUtilJar`, `JavaLangReflect`) — Swift wrappers for Java stdlib classes not used in our project
- **Code generators** (`SwiftJavaTool`, `SwiftJavaToolLib`, `JExtractSwiftLib`) — CLI tools for generating bindings, run once and not needed at build time
- **Plugins** (`JavaCompilerPlugin`, `SwiftJavaPlugin`, `JExtractSwiftPlugin`) — SPM build plugins for code generation
- **Support targets** (`SwiftJavaRuntimeSupport`, `SwiftRuntimeFunctions`, `SwiftJavaConfigurationShared`, `SwiftJavaShared`) — internal support for removed targets
- **Docs & examples** (`SwiftJavaDocumentation`, `ExampleSwiftLibrary`)
- **Samples, Benchmarks, Tests** — not needed in a dependency
- **Gradle/Java build system** (`BuildLogic/`, `gradle/`, `SwiftKitCore/`, `SwiftKitFFM/`, `docker/`, `scripts/`)
- **Most external package dependencies** — `swift-argument-parser`, `swift-system`, `swift-log`, `swift-collections`, `swift-subprocess`, `package-benchmark`, `swift-java-jni-core`. Only `swift-syntax` remains (required for `.macro` target, compile-time only)

## Android JVM Bootstrap

When running a standalone Swift binary on Android (e.g. `.xctest` for swift-testing), there is no app context and no JVM. The binary must create an ART JVM manually via `JNI_CreateJavaVM`.

This fork includes everything needed to do that from pure Swift:

### How it works

1. **Signal handler stubs** (`CSwiftJavaSignalStubs/signal_stubs.c`). ART's `libsigchain` calls `dlsym(RTLD_DEFAULT, "AddSpecialSignalHandlerFn")` and `dlsym(RTLD_DEFAULT, "SetSpecialSignalHandlerFn")` when `libart.so` is loaded. If these symbols are missing, the process aborts. The stubs are no-op C functions with `visibility("default")`. They **must be in the main executable** — Android's `RTLD_DEFAULT` does not find them if they're only in a `.so` dependency. This is why `CSwiftJavaSignalStubs` is a separate C target: the consumer links it statically, and linker flags (`-u`, `--export-dynamic`) ensure the symbols end up in the executable's dynamic symbol table.

2. **Dynamic library loading** (`SwiftJavaJNICore/VirtualMachine/JavaVirtualMachine.swift`). The `loadLibJava()` function uses `dlopen` to load `libart.so` at runtime, including APEX paths for API 29+ (`/apex/com.android.runtime/lib64/libart.so`, `/apex/com.android.art/lib64/libart.so`). Then `dlsym` resolves `JNI_CreateJavaVM` and `JNI_GetCreatedJavaVMs`. No C++ bridge needed — the old `AndroidSupport.cpp` was removed.

3. **Bootstrap function** (`SwiftJava/AndroidJVMBootstrap.swift`). `initializeAndroidJVMForTests()` reads `BOOTCLASSPATH` from the environment, passes ART-specific VM options (`-XX:DisableHiddenApiChecks`, `-Xbootclasspath:`), and calls `JavaVirtualMachine.shared()`.

### AndroidJVMTest

`Tests/AndroidJVMTest/` is a standalone executable that verifies the full bootstrap chain on a real Android device or emulator:

- Calls `initializeAndroidJVMForTests()`
- Gets a `JNIEnvironment`
- Calls `System.getProperty("java.vm.name")` via raw JNI
- Prints the result and exits

This is not a library — it exists solely to verify that JVM creation works from a standalone binary on Android.

### Consumer setup

The consumer's executable or test target needs two things:

1. **Depend on `CSwiftJavaSignalStubs`** — to get the signal stubs linked into the binary.
2. **Add linker flags** — to prevent the linker from stripping the stubs (nothing references them directly) and to export them into the dynamic symbol table where `dlsym(RTLD_DEFAULT, ...)` can find them.

```swift
.testTarget(name: "MyAndroidTests",
    dependencies: [
        .product(name: "SwiftJava", package: "swift-java"),
        .product(name: "CSwiftJavaSignalStubs", package: "swift-java"),
    ],
    linkerSettings: [
        .unsafeFlags([
            "-Xlinker", "-u", "-Xlinker", "SetSpecialSignalHandlerFn",
            "-Xlinker", "-u", "-Xlinker", "AddSpecialSignalHandlerFn",
            "-Xlinker", "--export-dynamic",
        ], .when(platforms: [.android])),
    ])
```

Then in test code:
```swift
#if os(Android)
import SwiftJava

let vm = try initializeAndroidJVMForTests()
// All @JavaClass types are now usable
#endif
```

### Requirements

- **API 29+** — API 28 fails for standalone JVM bootstrap (SELinux blocks patchoat/dex2oat).
- **Environment variables** — set before launching the binary:
  - `BOOTCLASSPATH` — colon-separated boot classpath JARs (read from emulator via `adb shell printenv BOOTCLASSPATH`)
  - `ANDROID_ROOT=/system`
  - `ANDROID_DATA=/data`
  - `LD_LIBRARY_PATH` — must include the directory with Swift .so files and `/apex/com.android.runtime/lib64`

## How macros work

`SwiftJavaMacros` is a standard `.macro` target compiled from `Sources/SwiftJavaMacros/`. It depends on `swift-syntax` (the only external dependency). SPM compiles the macro for the host platform automatically, including during Android cross-compilation.

`swift-syntax` is compile-time only — it does not end up in the Android binary. First build takes ~47s, subsequent builds use cache.

## Syncing with upstream

To pull changes from upstream:

1. Cherry-pick commits touching `Sources/SwiftJava/`, `Sources/JavaStdlib/`, `Sources/SwiftJavaMacros/`
2. For `CSwiftJavaJNI`/`SwiftJavaJNICore` — check [swift-java-jni-core](https://github.com/swiftlang/swift-java-jni-core) for changes
3. `Sources/SwiftJavaMacros/` — cherry-pick from `swiftlang/swift-java`

## Build

```bash
# macOS
swift build

# Android (cross-compilation)
swift build --swift-sdk aarch64-unknown-linux-android28
```

No `JAVA_HOME` needed — JNI headers (`jni.h`, `jni_md.h`) are inlined in `Sources/CSwiftJavaJNI/include/`. `JAVA_HOME` is only used for linker settings (linking `jvm`), and those are guarded by `.when(platforms:)`.

### Running AndroidJVMTest on emulator

```bash
# Build for Android
swift build --swift-sdk aarch64-unknown-linux-android28

# Collect shared libraries (using swift-android-emulator-kit)
swift run swift-android-collect-libs \
    .build/aarch64-unknown-linux-android28/debug/AndroidJVMTest \
    --destination /tmp/android-jvm-test \
    --triplet aarch64-unknown-linux-android28 \
    --build-folder .build/aarch64-unknown-linux-android28/debug

# Copy the dynamic library (not auto-collected)
cp .build/aarch64-unknown-linux-android28/debug/libSwiftJava.so /tmp/android-jvm-test/

# Push to emulator
adb shell "rm -rf /data/local/tmp/jvmtest/"
adb push /tmp/android-jvm-test/ /data/local/tmp/jvmtest/
adb shell "chmod +x /data/local/tmp/jvmtest/AndroidJVMTest"

# Run
BCP=$(adb shell "printenv BOOTCLASSPATH" | tr -d '\r')
adb shell "cd /data/local/tmp/jvmtest && \
    ANDROID_ROOT=/system \
    ANDROID_DATA=/data \
    ANDROID_ART_ROOT=/apex/com.android.runtime \
    BOOTCLASSPATH=$BCP \
    LD_LIBRARY_PATH=/data/local/tmp/jvmtest:/apex/com.android.runtime/lib64 \
    ./AndroidJVMTest"
```

Expected output:
```
[AndroidJVMTest] Starting...
[AndroidJVMBootstrap] JVM initialized successfully
[AndroidJVMTest] JVM created: JavaVirtualMachine(...)
[AndroidJVMTest] Got JNI environment
[AndroidJVMTest] Found java.lang.System
[AndroidJVMTest] java.vm.name = Dalvik
[AndroidJVMTest] SUCCESS — JVM is working!
```

## Original README

> This project contains tools and libraries that facilitate **Swift & Java Interoperability**.
>
> - Swift library (`SwiftJava`) and bindings generator that allows a Swift program to make use of Java libraries by wrapping Java classes in corresponding Swift types, allowing Swift to directly call any wrapped Java API.
> - The `swift-java` tool which offers automated ways to import or "extract" bindings to sources or libraries in either language.
>
> Full upstream project: https://github.com/swiftlang/swift-java
