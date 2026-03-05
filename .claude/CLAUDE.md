# swift-java minimal fork

Minimal fork of [swiftlang/swift-java](https://github.com/swiftlang/swift-java) for JNI bridging.
Remote: `NikolayJuly/swift-java`, branch: `minimal`.

## Structure

```
Sources/
  CSwiftJavaJNI/          — C headers (jni.h wrappers), inlined from swift-java-jni-core
  SwiftJavaJNICore/       — Swift JNI runtime, inlined from swift-java-jni-core
  SwiftJava/              — Main library: JavaObject, macros, method calls
  JavaStdlib/
    JavaUtil/             — Java stdlib wrappers (Collections, Map, List, etc.)
    JavaNet/              — Java net wrappers (URL, URLConnection, etc.)
    JavaIO/               — Java IO wrappers (File, InputStream, etc.)
  SwiftJavaMacros/        — Macro source, compiled as .macro target
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
