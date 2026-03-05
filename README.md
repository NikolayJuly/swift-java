# Swift Java Interoperability — Minimal Fork

Minimal fork of [swiftlang/swift-java](https://github.com/swiftlang/swift-java) for JNI bridging on Android.

Upstream contains ~20 targets, plugins, Gradle integration, code generators, and heavy dependencies (swift-syntax, swift-argument-parser, swift-collections, etc.). This fork keeps only what's needed for runtime JNI bridging.

## What's included

| Target | Purpose | Source |
|--------|---------|--------|
| `CSwiftJavaJNI` | C headers: `JNIEnv`, `jobject`, `jstring`, `jboolean`, etc. | Inlined from [swift-java-jni-core](https://github.com/swiftlang/swift-java-jni-core) |
| `SwiftJavaJNICore` | JNI runtime: type demangling, bridged values, `JavaVirtualMachine` | Inlined from [swift-java-jni-core](https://github.com/swiftlang/swift-java-jni-core) |
| `SwiftJavaMacros` | `@JavaClass`, `@JavaMethod`, `@JavaImplementation`, etc. | Pre-built binary in `.artifactbundle` |
| `SwiftJava` | High-level API: `JavaObject`, `String(fromJNI:)`, method calls | Original `Sources/SwiftJava` |
| `JavaUtil` | Java stdlib: Collections, Map, List, Iterator, etc. | Original `Sources/JavaStdlib/JavaUtil` |
| `JavaNet` | Java net: URL, URLConnection, etc. | Original `Sources/JavaStdlib/JavaNet` |
| `JavaIO` | Java IO: File, InputStream, OutputStream, etc. | Original `Sources/JavaStdlib/JavaIO` |

Dependency chain: `SwiftJava` → `SwiftJavaJNICore` → `CSwiftJavaJNI`, plus `SwiftJavaMacros` loaded via `-load-plugin-executable`.
`JavaUtil`, `JavaNet`, `JavaIO` depend on `SwiftJava`.

## What's removed (and why)

Everything below was removed because it's not needed for runtime JNI usage from Swift on Android:

- **Unused JavaStdlib targets** (`JavaUtilFunction`, `JavaUtilJar`, `JavaLangReflect`) — Swift wrappers for Java stdlib classes not used in our project
- **Code generators** (`SwiftJavaTool`, `SwiftJavaToolLib`, `JExtractSwiftLib`) — CLI tools for generating bindings, run once and not needed at build time
- **Plugins** (`JavaCompilerPlugin`, `SwiftJavaPlugin`, `JExtractSwiftPlugin`) — SPM build plugins for code generation
- **Support targets** (`SwiftJavaRuntimeSupport`, `SwiftRuntimeFunctions`, `SwiftJavaConfigurationShared`, `SwiftJavaShared`) — internal support for removed targets
- **Docs & examples** (`SwiftJavaDocumentation`, `ExampleSwiftLibrary`)
- **Samples, Benchmarks, Tests** — not needed in a dependency
- **Gradle/Java build system** (`BuildLogic/`, `gradle/`, `SwiftKitCore/`, `SwiftKitFFM/`, `docker/`, `scripts/`)
- **All external package dependencies** — `swift-syntax` (12MB), `swift-argument-parser`, `swift-system`, `swift-log`, `swift-collections`, `swift-subprocess`, `package-benchmark`, `swift-java-jni-core`

## How macros work

`SwiftJavaMacros` is a Swift compiler plugin (macro). Upstream compiles it from source every build, which pulls in `swift-syntax` (~12MB) and requires `JAVA_HOME` even on macOS host.

This fork ships a **pre-built binary** in `SwiftJavaMacros.artifactbundle/`. The binary is loaded via `-load-plugin-executable` compiler flag in `Package.swift`. SPM's `.binaryTarget` does not work for macro plugins — this is the workaround.

**Current binary:** built with Swift 6.2.3, macOS arm64.

### Rebuilding the macro binary

When upgrading the Swift toolchain, rebuild:

```bash
# 1. Checkout upstream swift-java (or use Sources/SwiftJavaMacros as reference)
# 2. Build the macro plugin
JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-22.jdk/Contents/Home \
  swift build -c release --product SwiftJavaMacros

# 3. Copy the binary into the artifact bundle
cp .build/arm64-apple-macosx/release/SwiftJavaMacros-tool \
   SwiftJavaMacros.artifactbundle/SwiftJavaMacros-tool/bin/SwiftJavaMacros-tool
```

`Sources/SwiftJavaMacros/` is kept (not compiled) as reference for rebuilding.

## Syncing with upstream

To pull changes from upstream:

1. Cherry-pick commits touching `Sources/SwiftJava/`, `Sources/JavaStdlib/`, `Sources/SwiftJavaMacros/`
2. For `CSwiftJavaJNI`/`SwiftJavaJNICore` — check [swift-java-jni-core](https://github.com/swiftlang/swift-java-jni-core) for changes
3. If macro sources changed — rebuild the binary (see above)

## Build

```bash
swift build
```

No `JAVA_HOME` needed — JNI headers (`jni.h`, `jni_md.h`) are inlined in `Sources/CSwiftJavaJNI/include/`. `JAVA_HOME` is only used for linker settings (linking `jvm`), and those are guarded by `.when(platforms:)`.

## Original README

> This project contains tools and libraries that facilitate **Swift & Java Interoperability**.
>
> - Swift library (`SwiftJava`) and bindings generator that allows a Swift program to make use of Java libraries by wrapping Java classes in corresponding Swift types, allowing Swift to directly call any wrapped Java API.
> - The `swift-java` tool which offers automated ways to import or "extract" bindings to sources or libraries in either language.
>
> Full upstream project: https://github.com/swiftlang/swift-java
