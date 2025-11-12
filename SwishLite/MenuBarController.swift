//
//  MenuBarController.swift
//  SwishLite
//
//  Menu bar interface and controls
//

import AppKit

@MainActor
final class MenuBarController {
  private var statusItem: NSStatusItem?
  private let gestureMonitor = EventMonitor.shared

  func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
      button.image = createMenuBarIcon()
      button.image?.isTemplate = true
    }

    // Minimal menu by design to reduce accidental activation and keep focus on gestures.
    updateMenu()
  }

  private func createMenuBarIcon() -> NSImage? {
    // Keep a simple, template-friendly icon to inherit the system tint.
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size)

    image.lockFocus()

    // Draw a simple swipe icon
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 3, y: 9))
    path.line(to: NSPoint(x: 12, y: 9))
    path.line(to: NSPoint(x: 9, y: 6))
    path.move(to: NSPoint(x: 12, y: 9))
    path.line(to: NSPoint(x: 9, y: 12))
    path.lineWidth = 1.5
    NSColor.black.setStroke()
    path.stroke()

    image.unlockFocus()
    return image
  }

  func updateMenu() {
    let menu = NSMenu()

    // Status item reflects Accessibility permission state so users know when gestures are active.
    let hasPermission = PermissionsManager.shared.checkAccessibilityPermission()
    let statusText = hasPermission ? "✓ Active" : "⚠ Needs Permission"
    menu.addItem(withTitle: statusText, action: nil, keyEquivalent: "")
    menu.addItem(NSMenuItem.separator())

    // Enable/Disable toggle
    let enabledItem = NSMenuItem(
      title: "Enable Gestures",
      action: #selector(toggleEnabled),
      keyEquivalent: ""
    )
    enabledItem.target = self
    enabledItem.state = .on  // Default enabled
    menu.addItem(enabledItem)

    menu.addItem(NSMenuItem.separator())

    // Block events toggle
    let blockEventsItem = NSMenuItem(
      title: "Block Events While Fn Held",
      action: #selector(toggleBlockEvents),
      keyEquivalent: ""
    )
    blockEventsItem.target = self
    blockEventsItem.state = SettingsManager.shared.blockEventsWhileFnHeld ? .on : .off
    menu.addItem(blockEventsItem)

    menu.addItem(NSMenuItem.separator())

    // Sensitivity settings submenu
    let sensitivityMenu = NSMenu()

    let lowSensitivity = NSMenuItem(
      title: "Low",
      action: #selector(setSensitivityLow),
      keyEquivalent: ""
    )
    lowSensitivity.target = self

    let mediumSensitivity = NSMenuItem(
      title: "Medium",
      action: #selector(setSensitivityMedium),
      keyEquivalent: ""
    )
    mediumSensitivity.target = self
    mediumSensitivity.state = .on  // Default

    let highSensitivity = NSMenuItem(
      title: "High",
      action: #selector(setSensitivityHigh),
      keyEquivalent: ""
    )
    highSensitivity.target = self

    sensitivityMenu.addItem(lowSensitivity)
    sensitivityMenu.addItem(mediumSensitivity)
    sensitivityMenu.addItem(highSensitivity)

    let sensitivityItem = NSMenuItem(
      title: "Sensitivity",
      action: nil,
      keyEquivalent: ""
    )
    sensitivityItem.submenu = sensitivityMenu
    menu.addItem(sensitivityItem)

    menu.addItem(NSMenuItem.separator())

    // Window Pairing toggle
    let windowPairingItem = NSMenuItem(
      title: "Enable Window Pairing",
      action: #selector(toggleWindowPairing),
      keyEquivalent: ""
    )
    windowPairingItem.target = self
    windowPairingItem.state = SettingsManager.shared.enableWindowPairing ? .on : .off
    menu.addItem(windowPairingItem)

    menu.addItem(NSMenuItem.separator())

    // Help items
    if !hasPermission {
      let permissionItem = NSMenuItem(
        title: "Grant Accessibility Permission...",
        action: #selector(requestPermission),
        keyEquivalent: ""
      )
      permissionItem.target = self
      menu.addItem(permissionItem)
      menu.addItem(NSMenuItem.separator())
    }

    // About
    menu.addItem(withTitle: "About SwishLite", action: #selector(showAbout), keyEquivalent: "")
      .target = self

    // Quit
    menu.addItem(NSMenuItem.separator())
    menu.addItem(withTitle: "Quit SwishLite", action: #selector(quit), keyEquivalent: "q")
      .target = self

    statusItem?.menu = menu
  }

  @objc private func toggleEnabled(_ sender: NSMenuItem) {
    let newState: Bool = sender.state == .off
    gestureMonitor.setEnabled(newState)
    sender.state = newState ? .on : .off
  }

  @objc private func toggleBlockEvents(_ sender: NSMenuItem) {
    let newState: Bool = sender.state == .off
    SettingsManager.shared.blockEventsWhileFnHeld = newState
    sender.state = newState ? .on : .off
  }

  @objc private func toggleWindowPairing(_ sender: NSMenuItem) {
    let newState: Bool = sender.state == .off
    SettingsManager.shared.enableWindowPairing = newState
    sender.state = newState ? .on : .off
  }

  @objc private func setSensitivityLow() {
    GestureClassifier.shared.detectionThreshold = 40.0
    updateSensitivityCheckmarks(selected: "Low")
  }

  @objc private func setSensitivityMedium() {
    GestureClassifier.shared.detectionThreshold = 25.0
    updateSensitivityCheckmarks(selected: "Medium")
  }

  @objc private func setSensitivityHigh() {
    GestureClassifier.shared.detectionThreshold = 15.0
    updateSensitivityCheckmarks(selected: "High")
  }

  private func updateSensitivityCheckmarks(selected: String) {
    guard let menu = statusItem?.menu,
      let sensitivityItem = menu.items.first(where: { $0.title == "Sensitivity" }),
      let submenu = sensitivityItem.submenu
    else { return }

    for item in submenu.items {
      item.state = (item.title == selected) ? .on : .off
    }
  }

  @objc private func requestPermission() {
    let trusted = PermissionsManager.shared.ensureAccessibilityPermission(prompt: true)

    if !trusted {
      // Show instructions
      let alert = NSAlert()
      alert.messageText = "Accessibility Permission Required"
      alert.informativeText = """
        SwishLite needs Accessibility permission to control windows.

        Steps:
        1. Open System Settings
        2. Go to Privacy & Security → Accessibility
        3. Enable SwishLite in the list
        4. Restart SwishLite
        """
      alert.alertStyle = .informational
      alert.addButton(withTitle: "Open System Settings")
      alert.addButton(withTitle: "OK")

      let response = alert.runModal()
      if response == .alertFirstButtonReturn {
        if let url = URL(
          string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
          NSWorkspace.shared.open(url)
        }
      }
    }

    updateMenu()
  }

  @objc private func showAbout() {
    let alert = NSAlert()
    alert.messageText = "SwishLite"
    alert.informativeText = """
      A lightweight window manager for macOS.

      Hold Fn and:
      • Swipe left/right → Snap window to half
      • Swipe up → Maximize window
      • Swipe down → Minimize window

      Version 1.0
      """
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  @objc private func quit() {
    NSApplication.shared.terminate(nil)
  }
}
