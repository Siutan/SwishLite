//
//  GestureClassifier.swift
//  SwishLite
//
//  Converts scroll deltas into swipe gestures (left/right/up/down)
//

import AppKit

enum SwipeDirection {
    case left
    case right
    case up
    case down
}

@MainActor
final class GestureClassifier {
    static let shared = GestureClassifier()
    
    // Rationale: Centralize heuristics so tuning remains consistent across the app.
    private enum Constants {
        static let defaultDetectionThreshold: CGFloat = 25.0
        static let defaultDirectionChangeAngle: CGFloat = 90.0
        static let cancelThreshold: CGFloat = 25.0
        static let gestureTimeout: TimeInterval = 100 // Keep long to avoid mid-gesture resets
        static let minHapticInterval: TimeInterval = 0.15
    }
    
    // Configurable thresholds (exposed for menu sensitivity control)
    var detectionThreshold: CGFloat = Constants.defaultDetectionThreshold
    var directionChangeAngle: CGFloat = Constants.defaultDirectionChangeAngle
    
    // Accumulated deltas from absolute start (for cancel detection)
    private var absoluteX: CGFloat = 0
    private var absoluteY: CGFloat = 0
    
    // Current center point (resets on direction change)
    private var centerX: CGFloat = 0
    private var centerY: CGFloat = 0
    
    // Deltas from current center
    private var relativeX: CGFloat = 0
    private var relativeY: CGFloat = 0
    
    private var lastEventTime: TimeInterval = 0
    private let gestureTimeout: TimeInterval = Constants.gestureTimeout
    
    // Current gesture state
    private var currentDirection: SwipeDirection?
    private var isShowingPreview = false
    private var isCancelling = false
    
    // Cancel gesture properties
    private var cancelThreshold: CGFloat = Constants.cancelThreshold // Distance from absolute origin to trigger cancel
    private var lastDirectionChangeTime: TimeInterval = 0
    
    var onSwipeDetected: ((SwipeDirection) -> Void)? // Called when swipe is first detected
    var onSwipeCompleted: ((SwipeDirection) -> Void)? // Called when fingers lift (actual action)
    var onSwipeCancelled: (() -> Void)? // Called when gesture is cancelled
    
    private init() {}
    
    func ingest(_ event: NSEvent) {
        // Ignore momentum phase to avoid double-firing on trackpad kinetic scrolling.
        if event.momentumPhase != .init(rawValue: 0) && event.momentumPhase != [] {
            return
        }
        
        let currentTime = Date().timeIntervalSince1970
        
        // End/cancel here avoids committing actions when the user's fingers lift.
        if event.phase == .ended || event.phase == .cancelled {
            handleGestureEnd()
            return
        }
        
        // Reset accumulation if the previous gesture was long ago.
        if currentTime - lastEventTime > gestureTimeout {
            resetAll()
        }
        
        lastEventTime = currentTime
        
        // Prefer precise deltas to better reflect finger intent.
        let deltaX: CGFloat
        let deltaY: CGFloat
        
        if event.hasPreciseScrollingDeltas {
            deltaX = event.scrollingDeltaX
            deltaY = event.scrollingDeltaY
        } else {
            deltaX = event.deltaX * 10 // Scale line-based scrolling for parity with precise deltas
            deltaY = event.deltaY * 10
        }
        
        // Update absolute position (from gesture start)
        absoluteX += deltaX
        absoluteY += deltaY
        
        // Update relative position (from current center)
        relativeX += deltaX
        relativeY += deltaY
        
        // Check for cancel first to allow users to bail out by returning to origin.
        if !isCancelling && checkForCancel() {
            return
        }
        
        // Determine current movement direction
        let newDirection = determineDirection()
        
        if let newDir = newDirection {
            if let currentDir = currentDirection {
                // We have an existing direction - check if it changed significantly
                if newDir != currentDir {
                    let angleChanged = angleBetweenDirections(currentDir, newDir)
                    
                    // If direction changed drastically, reset center point
                    if angleChanged >= directionChangeAngle {
                        resetCenterPoint()
                        currentDirection = newDir
                        lastDirectionChangeTime = currentTime
                        isCancelling = false
                        
                        // Provide haptic feedback for direction change
                        HapticFeedback.shared.swipeDetected()
                        
                        // Update preview
                        onSwipeDetected?(newDir)
                    } else {
                        // Small direction change - just update without resetting center
                        currentDirection = newDir
                        isCancelling = false
                        
                        // Throttle feedback to prevent tactile noise during micro-adjustments
                        if currentTime - lastDirectionChangeTime >= Constants.minHapticInterval {
                            lastDirectionChangeTime = currentTime
                            HapticFeedback.shared.swipeDetected()
                            onSwipeDetected?(newDir)
                        }
                    }
                }
            } else {
                // First direction detected
                currentDirection = newDir
                isShowingPreview = true
                isCancelling = false
                lastDirectionChangeTime = currentTime
                
                HapticFeedback.shared.swipeDetected()
                onSwipeDetected?(newDir)
            }
        }
    }
    
    // Determine direction based on relative position from current center
    private func determineDirection() -> SwipeDirection? {
        let absX = abs(relativeX)
        let absY = abs(relativeY)
        
        // Require a minimum movement to reduce false positives from micro-jitter.
        if absX < detectionThreshold && absY < detectionThreshold {
            return nil
        }
        
        // Determine which direction is dominant
        if absX > absY {
            // Horizontal movement is dominant
            return relativeX > 0 ? .right : .left
        } else {
            // Vertical movement is dominant
            return relativeY > 0 ? .down : .up
        }
    }
    
    // Calculate angle between two directions (in degrees)
    private func angleBetweenDirections(_ dir1: SwipeDirection, _ dir2: SwipeDirection) -> CGFloat {
        // Map directions to angles so we can compute the minimal turn angle.
        let angle1 = angleForDirection(dir1)
        let angle2 = angleForDirection(dir2)
        
        // Calculate smallest angle difference
        var diff = abs(angle1 - angle2)
        if diff > 180 {
            diff = 360 - diff
        }
        
        return diff
    }
    
    private func angleForDirection(_ direction: SwipeDirection) -> CGFloat {
        switch direction {
        case .right: return 0
        case .down: return 90
        case .left: return 180
        case .up: return 270
        }
    }
    
    // Reset the center point to current absolute position to prevent drift between axes.
    private func resetCenterPoint() {
        centerX = absoluteX
        centerY = absoluteY
        relativeX = 0
        relativeY = 0
    }
    
    // Check if user returned to origin (cancel gesture)
    private func checkForCancel() -> Bool {
        guard currentDirection != nil,
              isShowingPreview,
              !isCancelling else {
            return false
        }
        
        // Distance from origin determines whether the user effectively "undoes" the swipe.
        let distanceFromOrigin = sqrt(absoluteX * absoluteX + absoluteY * absoluteY)
        
        // If we're close to where we started, it's a cancel
        if distanceFromOrigin <= cancelThreshold {
            isCancelling = true
            currentDirection = nil
            isShowingPreview = false
            
            // Provide haptic feedback for cancel
            HapticFeedback.shared.gestureCompleted()
            
            // Show cancel preview
            onSwipeCancelled?()
            
            return true
        }
        
        return false
    }
    
    // Handle when fingers lift from trackpad
    private func handleGestureEnd() {
        // Do not execute action if we're in cancel state.
        if isCancelling {
            resetAll()
            return
        }
        
        if let direction = currentDirection {
            // Gesture completed - execute the action
            HapticFeedback.shared.gestureCompleted()
            onSwipeCompleted?(direction)
        } else if isShowingPreview {
            // Gesture was showing preview but no clear direction
            onSwipeCancelled?()
        }
        
        resetAll()
    }
    
    // Reset all state
    private func resetAll() {
        absoluteX = 0
        absoluteY = 0
        centerX = 0
        centerY = 0
        relativeX = 0
        relativeY = 0
        currentDirection = nil
        isShowingPreview = false
        isCancelling = false
        lastDirectionChangeTime = 0
    }
    
    // Called externally to reset (e.g., Escape key or Fn release)
    func reset() {
        let hadActiveGesture = (currentDirection != nil && isShowingPreview)
        resetAll()
        lastEventTime = 0
        
        // Only trigger cancel callback if there was an active gesture
        if hadActiveGesture {
            onSwipeCancelled?()
        }
    }
}

