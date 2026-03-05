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
  SwiftJavaMacros/        — Macro source (NOT compiled, kept for reference)
SwiftJavaMacros.artifactbundle/  — Pre-built macro binary (Swift 6.2.3, arm64 macOS)
```

## Key decisions

- **Zero external dependencies.** `swift-java-jni-core` sources are inlined into this repo.
- **Macros as pre-built binary.** SPM `.binaryTarget` does NOT work for macro plugins.
  The workaround is `-load-plugin-executable` unsafeFlag in `Package.swift` swiftSettings.
  The flag is extracted into `loadMacroPlugin` variable and used in every target that has `@JavaClass`/`@JavaMethod`.
- **`traits: []`** is required in Package initializer for SPM 6.2 compatibility.
- **JNI headers inlined.** `jni.h` and `jni_md.h` (darwin) are committed in `Sources/CSwiftJavaJNI/include/`.
  No JAVA_HOME needed for compilation. `findJavaHome()` returns empty string if not found (no fatalError).
  JAVA_HOME is only used for linker settings (`-L`, `-rpath` to link jvm) — guarded by `.when(platforms:)`.

## Adding new targets that use macros

Any target using `@JavaClass`, `@JavaMethod`, etc. must include `loadMacroPlugin` in its `swiftSettings`.
Otherwise: `plugin for module 'SwiftJavaMacros' not found`.

## Building the macro binary

```bash
# From upstream swift-java repo (not this fork), with swift-syntax available:
JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-22.jdk/Contents/Home \
  swift build -c release --product SwiftJavaMacros
cp .build/arm64-apple-macosx/release/SwiftJavaMacros-tool \
   SwiftJavaMacros.artifactbundle/SwiftJavaMacros-tool/bin/SwiftJavaMacros-tool
```

Binary is tied to Swift compiler version. Rebuild when upgrading toolchain.

## Syncing with upstream

- `Sources/SwiftJava/` ← cherry-pick from `swiftlang/swift-java`
- `Sources/JavaStdlib/` ← cherry-pick from `swiftlang/swift-java`
- `Sources/CSwiftJavaJNI/`, `Sources/SwiftJavaJNICore/` ← check `swiftlang/swift-java-jni-core`
- `Sources/SwiftJavaMacros/` ← if changed, rebuild binary
