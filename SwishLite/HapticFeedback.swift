//
//  HapticFeedback.swift
//  SwishLite
//
//  Provides haptic feedback for gesture events
//

import AppKit

@MainActor
final class HapticFeedback {
    static let shared = HapticFeedback()
    
    private init() {}
    
    // Rationale: Throttle feedback to avoid Taptic overload during rapid direction tweaks.
    private var lastSwipeFeedbackTime: TimeInterval = 0
    private var lastCompleteFeedbackTime: TimeInterval = 0
    private let minInterval: TimeInterval = 0.12
    
    /// Generate a soft haptic feedback when a swipe is detected
    func swipeDetected() {
        let now = Date().timeIntervalSince1970
        guard now - lastSwipeFeedbackTime >= minInterval else { return }
        lastSwipeFeedbackTime = now
        let feedbackManager = NSHapticFeedbackManager.defaultPerformer
        feedbackManager.perform(.generic, performanceTime: .now)
    }
    
    /// Generate a stronger haptic when gesture completes
    func gestureCompleted() {
        let now = Date().timeIntervalSince1970
        guard now - lastCompleteFeedbackTime >= minInterval else { return }
        lastCompleteFeedbackTime = now
        let feedbackManager = NSHapticFeedbackManager.defaultPerformer
        feedbackManager.perform(.alignment, performanceTime: .now)
    }
}