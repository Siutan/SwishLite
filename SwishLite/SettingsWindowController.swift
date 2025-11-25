//
//  SettingsWindowController.swift
//  SwishLite
//
//  Manages the settings window
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
  private var statusItem: NSStatusItem?

  convenience init(statusItem: NSStatusItem?) {
    let settingsView = SettingsView()
    let hostingController = NSHostingController(rootView: settingsView)
    
    let window = NSWindow(contentViewController: hostingController)
    window.styleMask = [.titled, .closable, .fullSizeContentView]
    window.title = "SwishLite"
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    window.level = .floating
    
    // Hide standard window buttons
    window.standardWindowButton(.zoomButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    
    self.init(window: window)
    self.statusItem = statusItem
    
    // Close window when losing focus
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidResignKey),
      name: NSWindow.didResignKeyNotification,
      object: window
    )
  }
  
  @objc private func windowDidResignKey() {
    close()
  }
  
  func toggleWindow() {
    guard let window = window, let button = statusItem?.button else { return }
    
    if window.isVisible {
      close()
    } else {
      // Position window relative to status item
      let buttonRect = button.window?.convertToScreen(button.frame) ?? .zero
      let windowSize = window.frame.size
      
      let x = buttonRect.origin.x - (windowSize.width / 2) + (buttonRect.width / 2)
      let y = buttonRect.origin.y - windowSize.height - 5
      
      window.setFrameOrigin(NSPoint(x: x, y: y))
      
      // Ensure window is on screen
      if let screen = NSScreen.main {
        let screenFrame = screen.visibleFrame
        if window.frame.maxX > screenFrame.maxX {
          window.setFrameOrigin(NSPoint(x: screenFrame.maxX - windowSize.width - 10, y: y))
        }
      }
      
      showWindow(nil)
      NSApp.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(nil)
    }
  }
}
