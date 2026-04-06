// AndroidJVMBootstrap.swift

// Provides a single entry point for initializing ART JVM in standalone test binaries.
// Consumer calls initializeAndroidJVMForTests() before any @JavaClass usage.

#if os(Android)

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SwiftJavaJNICore

/// Initialize ART JVM for standalone test binaries on Android.
///
/// Reads `BOOTCLASSPATH` from the environment and creates a JVM with appropriate
/// ART options. Safe to call multiple times — returns the existing JVM if already created.
///
/// Required env vars (set before launching the binary):
/// - `BOOTCLASSPATH` — colon-separated list of boot classpath JARs
/// - `ANDROID_ROOT` — typically `/system`
/// - `ANDROID_DATA` — typically `/data`
///
/// - Parameters:
///   - javaLibraryPath: Path for `-Djava.library.path`. Defaults to `/data/local/tmp/tests`.
///   - vmOptions: Additional VM options to pass to JNI_CreateJavaVM.
/// - Returns: The shared JavaVirtualMachine instance.
@discardableResult
public func initializeAndroidJVMForTests(javaLibraryPath: String = "/data/local/tmp/tests",
                                         vmOptions: [String] = []) throws -> JavaVirtualMachine {
  var options: [String] = []

  if let bootclasspath = ProcessInfo.processInfo.environment["BOOTCLASSPATH"] {
    options.append("-Xbootclasspath:\(bootclasspath)")
  }

  options.append("-XX:DisableHiddenApiChecks")
  options.append("-Djava.library.path=\(javaLibraryPath)")
  options.append(contentsOf: vmOptions)

  let vm = try JavaVirtualMachine.shared(vmOptions: options, ignoreUnrecognized: true)
  print("[AndroidJVMBootstrap] JVM initialized successfully")
  return vm
}

#endif
