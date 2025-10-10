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

    // Ask for Accessibility permission up-front to avoid partial feature states later.
    let hasPermission = PermissionsManager.shared.ensureAccessibilityPermission(prompt: true)

    if !hasPermission {
      // Poll until permission is granted; we avoid background gestures without trust
      // to prevent confusing no-op interactions.
      PermissionsManager.shared.startPolling { [weak self] (trusted: Bool) in
        if trusted {
          Task { @MainActor in
            self?.startMonitoring()
          }
        }
      }
    } else {
      Task { @MainActor in
        startMonitoring()
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
