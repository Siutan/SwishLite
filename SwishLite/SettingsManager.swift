//
//  SettingsManager.swift
//  SwishLite
//
//  Manages user preferences and settings
//

import Foundation

@MainActor
final class SettingsManager {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    // Settings keys
    private let blockEventsKey = "blockEventsWhileFnHeld"
    private let enableWindowPairingKey = "enableWindowPairing"
    
    private init() {}
    
    // Block mouse/scroll events while Fn is held
    var blockEventsWhileFnHeld: Bool {
        get {
            // Default to false for less intrusive behavior
            return defaults.object(forKey: blockEventsKey) as? Bool ?? false
        }
        set {
            defaults.set(newValue, forKey: blockEventsKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
    
    // Enable automatic window pairing for split-view behavior
    var enableWindowPairing: Bool {
        get {
            // Default to true - this is a key feature
            return defaults.object(forKey: enableWindowPairingKey) as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: enableWindowPairingKey)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
            
            // If disabled, clear all existing pairs
            if !newValue {
                WindowPairManager.shared.clearAll()
            }
        }
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}


