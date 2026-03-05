// swift-tools-version: 6.2

import CompilerPluginSupport
import Foundation
import PackageDescription

// JAVA_HOME is only needed for linker settings (-L, -rpath to link jvm).
// JNI headers (jni.h, jni_md.h) are inlined in Sources/CSwiftJavaJNI/include/.
// Returns empty string if not found — linker flags will have invalid paths
// but they are guarded by .when(platforms:) and only matter at link time.
func findJavaHome() -> String {
  if let home = ProcessInfo.processInfo.environment["JAVA_HOME"] {
    return home
  }

  let path = "\(FileManager.default.homeDirectoryForCurrentUser.path()).java_home"
  if let home = try? String(contentsOfFile: path, encoding: .utf8) {
    if let lastChar = home.last, lastChar.isNewline {
      return String(home.dropLast())
    }
    return home
  }

  #if os(macOS)
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")
  if FileManager.default.fileExists(atPath: task.executableURL!.path) {
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    do {
      try task.run()
      task.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      if task.terminationStatus == 0,
         let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
         !output.isEmpty {
        return output
      }
    } catch {}
  }
  #endif

  return ""
}

let javaHome = findJavaHome()

let package = Package(
  name: "swift-java",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(
      name: "CSwiftJavaJNI",
      targets: ["CSwiftJavaJNI"]
    ),
    .library(
      name: "SwiftJava",
      type: .dynamic,
      targets: ["SwiftJava"]
    ),
    .library(
      name: "JavaUtil",
      targets: ["JavaUtil"]
    ),
    .library(
      name: "JavaNet",
      targets: ["JavaNet"]
    ),
    .library(
      name: "JavaIO",
      targets: ["JavaIO"]
    ),
  ],
  traits: [],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
  ],
  targets: [
    .target(
      name: "CSwiftJavaJNI",
      linkerSettings: [
        .linkedLibrary("log", .when(platforms: [.android]))
      ]
    ),

    .target(
      name: "SwiftJavaJNICore",
      dependencies: [
        "CSwiftJavaJNI"
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ],
      linkerSettings: [
        .unsafeFlags(
          [
            "-L\(javaHome)/lib/server",
            "-Xlinker", "-rpath",
            "-Xlinker", "\(javaHome)/lib/server",
          ],
          .when(platforms: [.linux, .macOS])
        ),
        .unsafeFlags(
          ["-L\(javaHome)/lib"],
          .when(platforms: [.windows])
        ),
        .linkedLibrary("jvm", .when(platforms: [.linux, .macOS, .windows])),
      ]
    ),

    .macro(
      name: "SwiftJavaMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),

    .target(
      name: "SwiftJava",
      dependencies: [
        "SwiftJavaJNICore",
        "SwiftJavaMacros",
      ],
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("ImplicitOpenExistentials"),
        .unsafeFlags(
          ["-Xfrontend", "-sil-verify-none"],
          .when(configuration: .release)
        ),
      ],
      linkerSettings: [
        .unsafeFlags(
          [
            "-L\(javaHome)/lib/server",
            "-Xlinker", "-rpath",
            "-Xlinker", "\(javaHome)/lib/server",
          ],
          .when(platforms: [.linux, .macOS])
        ),
        .unsafeFlags(
          ["-L\(javaHome)/lib"],
          .when(platforms: [.windows])
        ),
        .linkedLibrary("jvm", .when(platforms: [.linux, .macOS, .windows])),
      ]
    ),

    .target(
      name: "JavaUtil",
      dependencies: ["SwiftJava"],
      path: "Sources/JavaStdlib/JavaUtil",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "JavaNet",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaNet",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
    .target(
      name: "JavaIO",
      dependencies: ["SwiftJava", "JavaUtil"],
      path: "Sources/JavaStdlib/JavaIO",
      exclude: ["swift-java.config"],
      swiftSettings: [
        .swiftLanguageMode(.v5),
      ]
    ),
  ]
)
