//
//  WindowResolver.swift
//  SwishLite
//
//  Finds the AX window element under the pointer
//

import AppKit
import ApplicationServices

@MainActor
final class WindowResolver {
  static let shared = WindowResolver()

  private init() {}

  /// Get the TOPMOST window under the current mouse pointer position
  func windowUnderPointer() -> AXUIElement? {
    // Rationale: We only walk the parent chain of the element directly under the pointer
    // instead of scanning all windows. This minimizes AX traffic (faster, less fragile)
    // and avoids surfacing background windows that happen to overlap.
    let systemWide = AXUIElementCreateSystemWide()
    let mouseLocation = NSEvent.mouseLocation

    // Convert to CG coordinates (flipped from AppKit)
    // Use primary screen for global coordinate conversion
    guard let primaryScreen = NSScreen.screens.first else { return nil }
    let cgY = primaryScreen.frame.height - mouseLocation.y

    var element: AXUIElement?
    let result = AXUIElementCopyElementAtPosition(
      systemWide,
      Float(mouseLocation.x),
      Float(cgY),
      &element
    )

    guard result == .success, let el = element else {
      return getFocusedWindow()
    }

    // We intentionally avoid global searches: deep traversal is expensive and error-prone
    // when apps expose custom accessibility hierarchies.

    // Check if element itself is a window
    if isWindow(el) {
      return el
    }

    // Try to get the window attribute directly from the element
    var windowValue: AnyObject?
    if AXUIElementCopyAttributeValue(el, kAXWindowAttribute as CFString, &windowValue) == .success,
      let window = windowValue as! AXUIElement?
    {
      return window
    }

    // Climb up parent chain to find containing window
    // This ensures we get the window that THIS element belongs to
    if let window = getWindowViaParentChain(el) {
      return window
    }

    // Last resort: focused window
    return getFocusedWindow()
  }

  private func isWindow(_ element: AXUIElement) -> Bool {
    var roleValue: AnyObject?
    let roleResult = AXUIElementCopyAttributeValue(
      element,
      kAXRoleAttribute as CFString,
      &roleValue
    )

    return roleResult == .success && (roleValue as? String) == (kAXWindowRole as String)
  }

  private func getWindowViaParentChain(_ element: AXUIElement) -> AXUIElement? {
    var current = element

    // Climb up parent chain to find a window (max 10 levels)
    for _ in 0..<10 {
      var parentValue: AnyObject?
      let result = AXUIElementCopyAttributeValue(
        current,
        kAXParentAttribute as CFString,
        &parentValue
      )

      guard result == .success, let parent = parentValue as! AXUIElement? else {
        break
      }

      // Check if this parent is a window
      if isWindow(parent) {
        return parent
      }

      current = parent
    }

    return nil
  }

  private func getFocusedWindow() -> AXUIElement? {
    // Get the frontmost application
    guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    var focusedWindowValue: AnyObject?

    let result = AXUIElementCopyAttributeValue(
      appElement,
      kAXFocusedWindowAttribute as CFString,
      &focusedWindowValue
    )

    if result == .success, let window = focusedWindowValue as! AXUIElement? {
      return window
    }

    return nil
  }

  /// Get the screen containing the pointer
  func screenUnderPointer() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation

    for screen in NSScreen.screens {
      if screen.frame.contains(mouseLocation) {
        return screen
      }
    }

    return NSScreen.main
  }
}
