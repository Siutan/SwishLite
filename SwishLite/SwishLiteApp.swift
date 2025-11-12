//
//  SwishLiteApp.swift
//  SwishLite
//
//  Created by Mukil Chittybabu on 9/10/2025.
//

import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
  private let menuBarController = MenuBarController()

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Run as an accessory to minimize visual footprint (keeps focus on the current app).
    NSApp.setActivationPolicy(.accessory)

    // Delay permission check to allow macOS to update its accessibility cache
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      let hasPermission = PermissionsManager.shared.ensureAccessibilityPermission(prompt: true)

      if !hasPermission {
        // Poll until permission is granted; we avoid background gestures without trust
        // to prevent confusing no-op interactions.
        PermissionsManager.shared.startPolling { [weak self] (trusted: Bool) in
          if trusted {
            Task { @MainActor in
              self?.startMonitoring()
              self?.menuBarController.updateMenu()
              NSLog("Accessibility permission granted, monitoring started")
            }
          }
        }
      } else {
        Task { @MainActor in
          self?.startMonitoring()
        }
      }
    }

    menuBarController.setupMenuBar()
  }

  private func startMonitoring() {
    EventMonitor.shared.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    EventMonitor.shared.stop()
  }
}

// Main entry point
@main
struct SwishLiteApp {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
  }
}
