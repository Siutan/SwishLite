//
//  PermissionsManager.swift
//  SwishLite
//
//  Handles Accessibility permission checking and prompting
//

@preconcurrency import ApplicationServices
import Foundation

@MainActor
final class PermissionsManager {
  static let shared = PermissionsManager()

  private init() {}

  /// Check if the app is trusted for Accessibility and prompt if not
  func ensureAccessibilityPermission(prompt: Bool = true) -> Bool {
    // Rationale: Only the system prompt truly enables permission; avoid custom dialogs here.
    if prompt {
      // Use unretained value for static CFString constant; pass as CFDictionary
      let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
      let options = [key: true] as CFDictionary
      let trusted = AXIsProcessTrustedWithOptions(options)
      NSLog("Accessibility permission check (with prompt): \(trusted)")
      return trusted
    }
    let trusted = AXIsProcessTrusted()
    NSLog("Accessibility permission check (no prompt): \(trusted)")
    return trusted
  }

  /// Check permission without prompting (useful for status checks)
  func checkAccessibilityPermission() -> Bool {
    return AXIsProcessTrusted()
  }

  /// Start polling for permission changes (call this after showing the system prompt)
  nonisolated func startPolling(
    interval: TimeInterval = 1.0, callback: @escaping @Sendable (Bool) -> Void
  ) {
    // Rationale: Polling keeps UX simple—when trust flips, we start monitoring immediately.
    // Schedule timer on main run loop to ensure it runs on the main thread
    DispatchQueue.main.async {
      Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
        let trusted = AXIsProcessTrusted()
        callback(trusted)
        if trusted {
          timer.invalidate()
        }
      }
    }
  }
}
