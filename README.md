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

Dependency chain: `SwiftJava` → `SwiftJavaJNICore` → `CSwiftJavaJNI`, plus `SwiftJavaMacros` (`.macro` target).
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
- **Most external package dependencies** — `swift-argument-parser`, `swift-system`, `swift-log`, `swift-collections`, `swift-subprocess`, `package-benchmark`, `swift-java-jni-core`. Only `swift-syntax` remains (required for `.macro` target, compile-time only)

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
