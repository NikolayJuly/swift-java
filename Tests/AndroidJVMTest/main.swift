// main.swift

// Minimal test executable that creates an ART JVM on Android
// and verifies communication via JNI.

import Foundation
import SwiftJavaJNICore

#if os(Android)
import SwiftJava

func run() throws {
  print("[AndroidJVMTest] Starting...")

  // 1. Initialize JVM
  let vm = try initializeAndroidJVMForTests()
  print("[AndroidJVMTest] JVM created: \(vm)")

  // 2. Get JNI environment
  let env = try vm.environment()
  print("[AndroidJVMTest] Got JNI environment")

  // 3. Find java.lang.System class
  guard let systemClass = env.interface.FindClass(env, "java/lang/System") else {
    fatalError("[AndroidJVMTest] FindClass(java/lang/System) returned nil")
  }
  print("[AndroidJVMTest] Found java.lang.System")

  // 4. Get System.getProperty(String) method ID
  guard let getPropertyMethod = env.interface.GetStaticMethodID(
    env,
    systemClass,
    "getProperty",
    "(Ljava/lang/String;)Ljava/lang/String;"
  ) else {
    fatalError("[AndroidJVMTest] GetStaticMethodID(getProperty) returned nil")
  }

  // 5. Create the key string "java.vm.name"
  guard let keyString = env.interface.NewStringUTF(env, "java.vm.name") else {
    fatalError("[AndroidJVMTest] NewStringUTF failed")
  }

  // 6. Call System.getProperty("java.vm.name")
  var args = jvalue()
  args.l = keyString
  let result = env.interface.CallStaticObjectMethodA(env, systemClass, getPropertyMethod, &args)

  if let result {
    let chars = env.interface.GetStringUTFChars(env, result, nil)
    if let chars {
      let vmName = String(cString: chars)
      print("[AndroidJVMTest] java.vm.name = \(vmName)")
      env.interface.ReleaseStringUTFChars(env, result, chars)
    }
    env.interface.DeleteLocalRef(env, result)
  } else {
    print("[AndroidJVMTest] System.getProperty returned null (expected on some ART configs)")
  }

  env.interface.DeleteLocalRef(env, keyString)
  env.interface.DeleteLocalRef(env, systemClass)

  print("[AndroidJVMTest] SUCCESS — JVM is working!")
}

do {
  try run()
} catch {
  fatalError("[AndroidJVMTest] FAILED: \(error)")
}

#else

print("[AndroidJVMTest] This test is Android-only. Skipping on current platform.")

#endif
