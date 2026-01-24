//
//  EventMonitor.swift
//  SwishLite
//
//  Global event monitor for Fn key + scroll wheel events
//

import AppKit
import ApplicationServices

@MainActor
final class EventMonitor {
  static let shared = EventMonitor()

  private var globalMonitor: Any?
  private var localMonitor: Any?
  private var eventTap: CFMachPort?
  private var eventTapRunLoopSource: CFRunLoopSource?
  private var fnDown = false
  private var otherModifiersDown = false
  var isEnabled = true

  var onSwipe: ((SwipeDirection) -> Void)?

  private init() {
    setupGestureHandler()
  }

  private func setupGestureHandler() {
    GestureClassifier.shared.onSwipeDetected = { [weak self] (direction: SwipeDirection) in
      self?.showPreview(direction)
    }

    GestureClassifier.shared.onSwipeCompleted = { [weak self] (direction: SwipeDirection) in
      self?.hidePreview()
      self?.executeSwipe(direction)
    }

    GestureClassifier.shared.onSwipeCancelled = { [weak self] in
      self?.showCancelPreview()
    }
  }

  func start() {
    stop()  // Clean up any existing monitors

    // Global monitor (for when app is in background)
    globalMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.flagsChanged, .scrollWheel, .keyDown]
    ) { [weak self] event in
      self?.handleEvent(event)
    }

    // Local monitor (for when app is active). We use a local monitor so we can return nil
    // to block events while Fn is held. This prevents accidental scroll/drag events from
    // reaching other apps during an active gesture.
    localMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [
        .flagsChanged, .scrollWheel, .keyDown, .leftMouseDown, .leftMouseUp, .rightMouseDown,
        .rightMouseUp, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDown,
        .otherMouseUp, .otherMouseDragged,
      ]
    ) { [weak self] event in
      guard let self = self else { return event }

      // Always handle flags changed events
      if event.type == .flagsChanged {
        self.handleEvent(event)
        return event
      }

      // Handle Escape key to cancel gestures
      if event.type == .keyDown {
        self.handleEvent(event)
        // If Fn is held and Escape cancels a gesture, block it
        if self.fnDown && event.keyCode == 53 {  // 53 is Escape key
          return nil
        }
        return event
      }

      // If Fn is held and blocking is enabled
      if self.fnDown && SettingsManager.shared.blockEventsWhileFnHeld {
        // Handle scroll events for gestures
        if event.type == .scrollWheel {
          self.handleEvent(event)
          return nil  // Block scroll from reaching other apps
        }

        // Block all other mouse events
        return nil
      }

      // Fn not held or blocking disabled - handle scroll events normally
      if event.type == .scrollWheel {
        self.handleEvent(event)
      }

      return event
    }

    // Try to setup event tap (requires accessibility permission)
    setupEventTap()

    // If event tap failed, retry after a short delay
    if eventTap == nil {
      NSLog("Event tap creation failed, will retry in 0.5s")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.setupEventTap()
      }
    }
  }

  func stop() {
    if let monitor = globalMonitor {
      NSEvent.removeMonitor(monitor)
      globalMonitor = nil
    }

    if let monitor = localMonitor {
      NSEvent.removeMonitor(monitor)
      localMonitor = nil
    }

    // Clean up event tap
    if let runLoopSource = eventTapRunLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
      eventTapRunLoopSource = nil
    }

    if let tap = eventTap {
      CFMachPortInvalidate(tap)
      eventTap = nil
    }

    fnDown = false
    // Don't reset gesture classifier here - it might not have an active gesture
  }

  func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
    // Reset will only show cancel if there's an active gesture
    if !enabled {
      GestureClassifier.shared.reset()
    }
  }

  private func handleEvent(_ event: NSEvent) {
    guard isEnabled else { return }

    switch event.type {
    case .flagsChanged:
      let previousFnDown = fnDown
      let masterKey = SettingsManager.shared.modifierKey.eventModifierFlags
      fnDown = event.modifierFlags.contains(masterKey)

      // Check for other modifier keys (excluding the master key and deviceIndependentFlagsMask)
      var relevantModifiers: NSEvent.ModifierFlags = [
        .command, .option, .control, .shift, .function,
      ]
      relevantModifiers.remove(masterKey)

      let otherModifiers = event.modifierFlags.intersection(relevantModifiers)
      otherModifiersDown = !otherModifiers.isEmpty

      // Reset gesture state when Master Key is released OR when other modifiers are pressed.
      // Resetting here avoids executing actions while the modifier context changed.
      // Only reset if Master Key was previously down (to avoid spurious resets)
      if (previousFnDown && !fnDown) || (fnDown && otherModifiersDown) {
        GestureClassifier.shared.reset()
      }

    case .keyDown:
      if event.keyCode == 53 {  // 53 is Escape key
        GestureClassifier.shared.reset()
      }

    case .scrollWheel where fnDown && !otherModifiersDown:
      // Pass scroll events to gesture classifier when Fn is held AND no other modifiers
      GestureClassifier.shared.ingest(event)

    default:
      break
    }
  }

  private func showPreview(_ direction: SwipeDirection) {
    // Verify permission right before showing the preview.
    // This keeps feedback consistent if the user revokes permission mid-session.
    guard PermissionsManager.shared.checkAccessibilityPermission() else {
      showPermissionAlert()
      return
    }

    // Get window and screen. We require both to ensure we preview on the correct display
    // and skip unsupported areas (desktop, menu bar).
    guard WindowResolver.shared.windowUnderPointer() != nil,
      let screen = WindowResolver.shared.screenUnderPointer()
    else {
      return
    }

    // Preview uses screen space only to avoid AX queries during gesture updates (reduces latency)
    PreviewOverlay.shared.showPreview(for: direction, screen: screen)
  }

  private func hidePreview() {
    PreviewOverlay.shared.hidePreview()
  }

  private func showCancelPreview() {
    PreviewOverlay.shared.showCancelPreview()

    // Hide cancel preview after a short delay (cancel is momentary feedback)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      self?.hidePreview()
    }
  }

  private func executeSwipe(_ direction: SwipeDirection) {
    // Verify permission at commit time to avoid attempting AX operations without trust.
    guard PermissionsManager.shared.checkAccessibilityPermission() else {
      showPermissionAlert()
      return
    }

    // Get window and screen
    guard let window = WindowResolver.shared.windowUnderPointer() else {
      // No window found - might be in an unsupported area
      return
    }

    guard let screen = WindowResolver.shared.screenUnderPointer() else {
      return
    }

    // Apply the appropriate layout action
    let success: Bool
    let engine = LayoutEngine.shared

    switch direction {
    case .left:
      success = engine.snapLeft(window, screen: screen)
      if success {
        handleWindowPairing(window: window, direction: .left, screen: screen)
      }
    case .right:
      success = engine.snapRight(window, screen: screen)
      if success {
        handleWindowPairing(window: window, direction: .right, screen: screen)
      }
    case .up:
      success = engine.maximize(window, screen: screen)
      if success {
        // Maximizing breaks any existing pairs
        WindowPairManager.shared.unpair(window: window)
      }
    case .down:
      success = engine.minimize(window)
    case .upLeft:
      success = engine.snapTopLeft(window, screen: screen)
      if success {
        WindowPairManager.shared.unpair(window: window)
      }
    case .upRight:
      success = engine.snapTopRight(window, screen: screen)
      if success {
        WindowPairManager.shared.unpair(window: window)
      }
    case .downLeft:
      success = engine.snapBottomLeft(window, screen: screen)
      if success {
        WindowPairManager.shared.unpair(window: window)
      }
    case .downRight:
      success = engine.snapBottomRight(window, screen: screen)
      if success {
        WindowPairManager.shared.unpair(window: window)
      }
    }

    // Bring window to front if action was successful (except for minimize)
    // Minimized windows should remain hidden, not be brought to the front
    if success && direction != .down {
      bringWindowToFront(window)
    }

    // Notify callback if set
    onSwipe?(direction)
  }

  private func handleWindowPairing(window: AXUIElement, direction: SwipeDirection, screen: NSScreen)
  {
    // Check if window pairing is enabled
    guard SettingsManager.shared.enableWindowPairing else {
      NSLog("Window pairing is disabled")
      return
    }

    // First, unpair the window we just snapped if it was part of a different pair
    WindowPairManager.shared.unpair(window: window)

    // Find other windows on the same screen that are snapped to the opposite side
    let oppositeDirection: SwipeDirection = (direction == .left) ? .right : .left

    // Get all windows on the screen
    guard let allWindows = getAllWindowsOnScreen(screen) else { return }

    // Find a window on the opposite half
    for otherWindow in allWindows {
      // Skip the current window
      if CFEqual(window, otherWindow) { continue }

      // Check if this window is on the opposite half
      if isWindowOnSide(otherWindow, side: oppositeDirection, screen: screen) {
        // Found a candidate for pairing

        // Unpair the other window from any existing pair
        WindowPairManager.shared.unpair(window: otherWindow)

        let leftWindow = (direction == .left) ? window : otherWindow
        let rightWindow = (direction == .left) ? otherWindow : window

        NSLog("Found window pair candidate - registering")
        WindowPairManager.shared.registerPair(
          leftWindow: leftWindow,
          rightWindow: rightWindow,
          screen: screen
        )

        // Bring both windows to front
        bringWindowToFront(leftWindow)
        bringWindowToFront(rightWindow)

        return
      }
    }

    NSLog("No pairing candidate found for \(direction) snap")
  }

  private func getAllWindowsOnScreen(_ screen: NSScreen) -> [AXUIElement]? {
    // Get all windows using CGWindowList
    guard
      let windowList = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
    else {
      return nil
    }

    var windows: [AXUIElement] = []

    for windowInfo in windowList {
      guard let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
        let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
        let layer = windowInfo[kCGWindowLayer as String] as? Int,
        layer == 0
      else {  // Only normal windows
        continue
      }

      // Check if window is on this screen
      let windowX = boundsDict["X"] ?? 0
      if !screen.frame.contains(CGPoint(x: windowX, y: screen.frame.midY)) {
        continue
      }

      // Get the application
      let app = AXUIElementCreateApplication(pid)

      // Get its windows
      var windowsValue: AnyObject?
      guard
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsValue)
          == .success,
        let appWindows = windowsValue as? [AXUIElement]
      else {
        continue
      }

      windows.append(contentsOf: appWindows)
    }

    return windows
  }

  private func isWindowOnSide(_ window: AXUIElement, side: SwipeDirection, screen: NSScreen) -> Bool
  {
    var posValue: AnyObject?
    var sizeValue: AnyObject?

    guard
      AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue)
        == .success,
      AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success
    else {
      return false
    }

    var position = CGPoint.zero
    var size = CGSize.zero

    guard let posAX = posValue as! AXValue?,
      let sizeAX = sizeValue as! AXValue?,
      AXValueGetValue(posAX, .cgPoint, &position),
      AXValueGetValue(sizeAX, .cgSize, &size)
    else {
      return false
    }

    let vf = screen.visibleFrame
    let midPoint = vf.minX + (vf.width / 2)

    // Check if window is approximately on the expected side and approximately half-width
    let widthTolerance: CGFloat = 50
    let expectedWidth = vf.width / 2

    let isCorrectWidth = abs(size.width - expectedWidth) < widthTolerance

    switch side {
    case .left:
      // Window should be on left half
      return position.x < midPoint && isCorrectWidth
    case .right:
      // Window should be on right half
      return position.x >= midPoint && isCorrectWidth
    default:
      return false
    }
  }

  private func bringWindowToFront(_ window: AXUIElement) {
    AXUIElementPerformAction(window, kAXRaiseAction as CFString)

    var app: AnyObject?
    guard AXUIElementCopyAttributeValue(window, kAXParentAttribute as CFString, &app) == .success,
      let appObj = app
    else { return }

    let appElement = appObj as! AXUIElement

    var pid: pid_t = 0
    guard AXUIElementGetPid(appElement, &pid) == .success,
      let runningApp = NSRunningApplication(processIdentifier: pid)
    else { return }

    if #available(macOS 14.0, *) {
      runningApp.activate(options: [.activateAllWindows])
    } else {
      runningApp.activate(options: [.activateIgnoringOtherApps])
    }
  }

  private func setupEventTap() {
    // Check if accessibility permission is granted
    guard PermissionsManager.shared.checkAccessibilityPermission() else {
      NSLog("Accessibility permission not granted - event tap cannot be created")
      return
    }

    // Create event tap to intercept mouse and scroll events
    let eventMask =
      (1 << CGEventType.scrollWheel.rawValue) | (1 << CGEventType.leftMouseDown.rawValue)
      | (1 << CGEventType.leftMouseUp.rawValue) | (1 << CGEventType.leftMouseDragged.rawValue)
      | (1 << CGEventType.rightMouseDown.rawValue) | (1 << CGEventType.rightMouseUp.rawValue)
      | (1 << CGEventType.rightMouseDragged.rawValue) | (1 << CGEventType.mouseMoved.rawValue)
      | (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
      | (1 << CGEventType.otherMouseDragged.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

    eventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(eventMask),
      callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
        return EventMonitor.shared.handleCGEvent(proxy: proxy, type: type, event: event)
      },
      userInfo: nil
    )

    guard let eventTap = eventTap else {
      NSLog("Failed to create event tap")
      return
    }

    // Create run loop source for the event tap
    eventTapRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

    guard let runLoopSource = eventTapRunLoopSource else {
      NSLog("Failed to create run loop source for event tap")
      return
    }

    // Add the run loop source to the current run loop
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

    NSLog("Event tap created successfully for system-wide event blocking")
  }

  private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent)
    -> Unmanaged<CGEvent>?
  {
    // Always allow flags changed events to pass through (needed for Fn key detection)
    if type == .flagsChanged {
      return Unmanaged.passUnretained(event)
    }

    // Check if Fn is held and blocking is enabled
    // Note: CGEvent doesn't have direct Fn key detection, so we use the NSEvent state
    let fnDown = EventMonitor.shared.fnDown

    if fnDown && SettingsManager.shared.blockEventsWhileFnHeld {
      // Handle scroll events for gesture detection before blocking
      if type == .scrollWheel {
        // Convert CGEvent to NSEvent for gesture processing
        if let nsEvent = NSEvent(cgEvent: event) {
          DispatchQueue.main.async {
            self.handleEvent(nsEvent)
          }
        }
      }

      // Block the event by returning nil
      return nil
    }

    // Allow event to pass through
    return Unmanaged.passUnretained(event)
  }

  private func showPermissionAlert() {
    DispatchQueue.main.async {
      let alert = NSAlert()
      alert.messageText = "Accessibility Permission Required"
      alert.informativeText =
        "SwishLite needs Accessibility permission to control windows. Please grant permission in System Settings → Privacy & Security → Accessibility."
      alert.alertStyle = .warning
      alert.addButton(withTitle: "Open System Settings")
      alert.addButton(withTitle: "Later")

      let response = alert.runModal()
      if response == .alertFirstButtonReturn {
        if let url = URL(
          string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
          NSWorkspace.shared.open(url)
        }
      }
    }
  }
}
