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
  private var settingsWindowController: SettingsWindowController?
  private let gestureMonitor = EventMonitor.shared

  func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
      button.image = createMenuBarIcon()
      button.image?.isTemplate = true
      button.action = #selector(toggleSettingsWindow)
      button.target = self
    }

    settingsWindowController = SettingsWindowController(statusItem: statusItem)
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

  @objc private func toggleSettingsWindow() {
    settingsWindowController?.toggleWindow()
  }

  // Kept for compatibility if called from elsewhere, but no longer builds a menu
  func updateMenu() {
    // No-op as we now use a window
  }
}
