//
//  WindowPairManager.swift
//  SwishLite
//
//  Manages paired windows for synchronized resizing
//

import AppKit
import ApplicationServices

@MainActor
final class WindowPairManager {
  static let shared = WindowPairManager()

  // Track window pairs: left window -> right window
  private var windowPairs: [WindowIdentifier: WindowIdentifier] = [:]

  // Track observers for each window
  private var observers: [WindowIdentifier: AXObserver] = [:]

  // Track screens for each pair
  private var pairScreens: [WindowIdentifier: NSScreen] = [:]

  // Prevent recursive resize loops
  private var isResizing = false

  // Track when a resize is in progress to ignore move events
  private var lastResizeTime: [WindowIdentifier: TimeInterval] = [:]
  private let resizeGracePeriod: TimeInterval = 0.5  // Rationale: Avoid breaking pairs during user drags.

  private init() {}

  // MARK: - Public API

  /// Register a new window pair (left + right)
  func registerPair(leftWindow: AXUIElement, rightWindow: AXUIElement, screen: NSScreen) {
    let leftID = WindowIdentifier(element: leftWindow)
    let rightID = WindowIdentifier(element: rightWindow)

    // Store the pair
    windowPairs[leftID] = rightID
    pairScreens[leftID] = screen

    // Rationale: Reduce logging noise; registration is a normal path.

    // Set up observers for both windows
    setupObserver(for: leftWindow, id: leftID, isLeft: true)
    setupObserver(for: rightWindow, id: rightID, isLeft: false)
  }

  /// Remove a window pair
  func unpair(window: AXUIElement) {
    let id = WindowIdentifier(element: window)

    // Check if this window is a left window
    if let rightID = windowPairs[id] {
      removeObserver(for: id)
      removeObserver(for: rightID)
      windowPairs.removeValue(forKey: id)
      pairScreens.removeValue(forKey: id)
      lastResizeTime.removeValue(forKey: id)
      lastResizeTime.removeValue(forKey: rightID)
      return
    }

    // Check if this window is a right window
    for (leftID, rightID) in windowPairs where rightID == id {
      removeObserver(for: leftID)
      removeObserver(for: rightID)
      windowPairs.removeValue(forKey: leftID)
      pairScreens.removeValue(forKey: leftID)
      lastResizeTime.removeValue(forKey: leftID)
      lastResizeTime.removeValue(forKey: rightID)
      return
    }
  }

  /// Clear all pairs
  func clearAll() {
    for id in observers.keys {
      removeObserver(for: id)
    }
    windowPairs.removeAll()
    pairScreens.removeAll()
    lastResizeTime.removeAll()
  }

  // MARK: - Observer Setup

  private func setupObserver(for window: AXUIElement, id: WindowIdentifier, isLeft: Bool) {
    // Remove existing observer if any
    removeObserver(for: id)

    var observer: AXObserver?
    let result = AXObserverCreate(
      id.pid,
      { (observer, element, notification, contextPtr) in
        guard let contextPtr = contextPtr else { return }
        let context = Unmanaged<ObserverContext>.fromOpaque(contextPtr).takeUnretainedValue()

        // Ensure we hop to the main actor before touching actor-isolated state
        Task { @MainActor in
          let notificationName = notification as String
          if notificationName == (kAXResizedNotification as String) {
            context.manager?.handleResize(
              windowID: context.windowID, isLeft: context.isLeft, element: context.element)
          } else if notificationName == (kAXMovedNotification as String) {
            context.manager?.handleMove(windowID: context.windowID, element: context.element)
          } else if notificationName == (kAXUIElementDestroyedNotification as String) {
            context.manager?.handleDestroyed(windowID: context.windowID, element: context.element)
            Unmanaged<ObserverContext>.fromOpaque(contextPtr).release()
          }
        }
      }, &observer)

    guard result == .success, let observer = observer else {
      NSLog("Failed to create observer for window \(id.pid):\(id.windowID)")
      return
    }

    // Store context for the callback
    let context: ObserverContext = ObserverContext(
      manager: self,
      windowID: id,
      isLeft: isLeft,
      element: window
    )
    let contextPtr = Unmanaged.passRetained(context).toOpaque()

    // Add notifications we want to observe
    AXObserverAddNotification(
      observer,
      window,
      kAXResizedNotification as CFString,
      contextPtr
    )

    AXObserverAddNotification(
      observer,
      window,
      kAXMovedNotification as CFString,
      contextPtr
    )

    AXObserverAddNotification(
      observer,
      window,
      kAXUIElementDestroyedNotification as CFString,
      contextPtr
    )

    // Add observer to run loop
    CFRunLoopAddSource(
      CFRunLoopGetCurrent(),
      AXObserverGetRunLoopSource(observer),
      .defaultMode
    )

    observers[id] = observer
    // Observer ready; notifications will keep paired frames consistent.
  }

  private func removeObserver(for id: WindowIdentifier) {
    guard let observer = observers[id] else { return }

    // Remove from run loop
    CFRunLoopRemoveSource(
      CFRunLoopGetCurrent(),
      AXObserverGetRunLoopSource(observer),
      .defaultMode
    )

    observers.removeValue(forKey: id)
  }

  // MARK: - Resize Handling

  fileprivate func handleResize(windowID: WindowIdentifier, isLeft: Bool, element: AXUIElement) {
    // Prevent recursive resizing
    guard !isResizing else { return }

    // Mark that this window is being resized (to ignore subsequent move events)
    let currentTime = Date().timeIntervalSince1970
    lastResizeTime[windowID] = currentTime

    // Find the paired window
    let pairedID: WindowIdentifier?
    let screen: NSScreen?

    if isLeft {
      pairedID = windowPairs[windowID]
      screen = pairScreens[windowID]
    } else {
      // Find the left window for this right window
      pairedID = windowPairs.first(where: { $0.value == windowID })?.key
      screen = pairedID.flatMap { pairScreens[$0] }
    }

    guard let pairedID = pairedID,
      let screen = screen
    else {
      return
    }

    // Mark paired window as being resized too
    lastResizeTime[pairedID] = currentTime

    // Get the paired window element
    guard let pairedElement = getWindowElement(for: pairedID) else {
      // Paired window no longer exists - unpair
      unpair(window: element)
      return
    }

    // Get current size and position of the resized window
    guard let currentFrame = getWindowFrame(element) else { return }

    let vf = screen.visibleFrame

    // Calculate the new width for the paired window
    let totalWidth = vf.width
    let resizedWidth = currentFrame.width
    let pairedWidth = totalWidth - resizedWidth

    // Ensure valid dimensions
    guard pairedWidth > 100 else { return }  // Minimum width to remain usable

    // Calculate new frame for paired window
    let pairedFrame: CGRect
    if isLeft {
      // Left window was resized, adjust right window
      pairedFrame = CGRect(
        x: vf.minX + resizedWidth,
        y: vf.minY,
        width: pairedWidth,
        height: vf.height
      )
    } else {
      // Right window was resized, adjust left window
      pairedFrame = CGRect(
        x: vf.minX,
        y: vf.minY,
        width: pairedWidth,
        height: vf.height
      )
    }

    // Apply the new frame to the paired window
    isResizing = true
    applyFrame(pairedFrame, to: pairedElement, screen: screen)
    isResizing = false

    // Rationale: Keep logs quiet during typical resize operations.
  }

  fileprivate func handleMove(windowID: WindowIdentifier, element: AXUIElement) {
    // If window is moved manually (not by our resize), break the pairing
    guard !isResizing else { return }  // Ignore moves during our resize operations

    // Check if this window was recently resized (within grace period)
    let currentTime = Date().timeIntervalSince1970
    if let lastResize = lastResizeTime[windowID],
      currentTime - lastResize < resizeGracePeriod
    {
      return
    }

    guard let frame = getWindowFrame(element) else { return }

    // Find if this is a left or right window
    var isLeft = false
    var screen: NSScreen?

    if windowPairs[windowID] != nil {
      isLeft = true
      screen = pairScreens[windowID]
    } else if let leftID = windowPairs.first(where: { $0.value == windowID })?.key {
      isLeft = false
      screen = pairScreens[leftID]
    }

    guard let screen = screen else { return }

    let vf = screen.visibleFrame
    let midPoint = vf.minX + (vf.width / 2)
    let tolerance: CGFloat = 30  // More sensitive - smaller tolerance

    // Check if window moved significantly from its expected side or position
    let expectedY = vf.minY
    let expectedHeight = vf.height

    // Check vertical position (user dragged window up/down)
    if abs(frame.minY - expectedY) > tolerance || abs(frame.height - expectedHeight) > tolerance * 2
    {
      unpair(window: element)
      return
    }

    // Check horizontal position
    if isLeft {
      // Left window should be on left half
      let expectedX = vf.minX
      if abs(frame.minX - expectedX) > tolerance || frame.minX > midPoint - tolerance {
        unpair(window: element)
      }
    } else {
      // Right window should be on right half
      let expectedX = midPoint
      if abs(frame.minX - expectedX) > tolerance || frame.maxX < midPoint + tolerance {
        unpair(window: element)
      }
    }
  }

  fileprivate func handleDestroyed(windowID: WindowIdentifier, element: AXUIElement) {
    unpair(window: element)
  }

  // MARK: - Helper Methods

  private func getWindowElement(for id: WindowIdentifier) -> AXUIElement? {
    // Create app element
    let app = AXUIElementCreateApplication(id.pid)

    // Get all windows
    var windowsValue: AnyObject?
    guard
      AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsValue)
        == .success,
      let windows = windowsValue as? [AXUIElement]
    else {
      return nil
    }

    // Find the window with matching ID
    for window in windows {
      if WindowIdentifier(element: window) == id {
        return window
      }
    }

    return nil
  }

  private func getWindowFrame(_ element: AXUIElement) -> CGRect? {
    var posValue: AnyObject?
    var sizeValue: AnyObject?

    guard
      AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue)
        == .success,
      AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success
    else {
      return nil
    }

    var position = CGPoint.zero
    var size = CGSize.zero

    guard let posAX = posValue as! AXValue?,
      let sizeAX = sizeValue as! AXValue?,
      AXValueGetValue(posAX, .cgPoint, &position),
      AXValueGetValue(sizeAX, .cgSize, &size)
    else {
      return nil
    }

    // Convert from CG coordinates to AppKit coordinates
    guard let primaryScreen = NSScreen.screens.first else { return nil }
    let screenHeight = primaryScreen.frame.height
    let appKitY = screenHeight - (position.y + size.height)

    return CGRect(
      x: position.x,
      y: appKitY,
      width: size.width,
      height: size.height
    )
  }

  private func applyFrame(_ frame: CGRect, to element: AXUIElement, screen: NSScreen) {
    // Convert to CG coordinates
    guard let primaryScreen = NSScreen.screens.first else { return }
    let screenHeight = primaryScreen.frame.height
    let cgY = screenHeight - (frame.origin.y + frame.height)

    var position = CGPoint(x: frame.origin.x, y: cgY)
    var size = CGSize(width: frame.width, height: frame.height)

    // Set position
    if let posValue = AXValueCreate(.cgPoint, &position) {
      AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)
    }

    // Set size
    if let sizeValue = AXValueCreate(.cgSize, &size) {
      AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
    }
  }
}

// MARK: - Window Identifier

struct WindowIdentifier: Hashable {
  let pid: pid_t
  let windowID: CGWindowID

  init(element: AXUIElement) {
    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)
    self.pid = pid

    // Try to get window ID
    var windowIDValue: AnyObject?
    if AXUIElementCopyAttributeValue(element, "_AXWindowID" as CFString, &windowIDValue)
      == .success,
      let id = windowIDValue as? CGWindowID
    {
      self.windowID = id
    } else {
      // Fallback: use hash of element
      self.windowID = CGWindowID(CFHash(element))
    }
  }
}

// MARK: - Observer Context

private class ObserverContext {
  weak var manager: WindowPairManager?
  let windowID: WindowIdentifier
  let isLeft: Bool
  let element: AXUIElement

  init(manager: WindowPairManager, windowID: WindowIdentifier, isLeft: Bool, element: AXUIElement) {
    self.manager = manager
    self.windowID = windowID
    self.isLeft = isLeft
    self.element = element
  }
}
