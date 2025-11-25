//
//  SettingsManager.swift
//  SwishLite
//
//  Manages user preferences and settings
//

import AppKit
import Combine
import Foundation

@MainActor
final class SettingsManager: ObservableObject {
  static let shared = SettingsManager()

  private let defaults = UserDefaults.standard

  // Settings keys
  private let blockEventsKey = "blockEventsWhileFnHeld"
  private let enableWindowPairingKey = "enableWindowPairing"
  private let modifierKeyKey = "modifierKey"

  private init() {
    // Initialize published properties from defaults
    self.blockEventsWhileFnHeld = defaults.object(forKey: blockEventsKey) as? Bool ?? true
    self.enableWindowPairing = defaults.object(forKey: enableWindowPairingKey) as? Bool ?? true

    if let savedKey = defaults.string(forKey: modifierKeyKey),
      let key = ModifierKey(rawValue: savedKey)
    {
      self.modifierKey = key
    } else {
      self.modifierKey = .fn
    }
  }

  enum ModifierKey: String, CaseIterable, Identifiable {
    case fn = "Fn"
    case control = "Control"
    case option = "Option"
    case command = "Command"
    case shift = "Shift"

    var id: String { rawValue }

    var eventModifierFlags: NSEvent.ModifierFlags {
      switch self {
      case .fn: return .function
      case .control: return .control
      case .option: return .option
      case .command: return .command
      case .shift: return .shift
      }
    }
  }

  @Published var modifierKey: ModifierKey {
    didSet {
      defaults.set(modifierKey.rawValue, forKey: modifierKeyKey)
      NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
  }

  // Block mouse/scroll events while Fn is held
  @Published var blockEventsWhileFnHeld: Bool {
    didSet {
      defaults.set(blockEventsWhileFnHeld, forKey: blockEventsKey)
      // NotificationCenter is no longer needed for SwiftUI, but keeping it if other parts rely on it
      NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
  }

  // Enable automatic window pairing for split-view behaviour
  @Published var enableWindowPairing: Bool {
    didSet {
      defaults.set(enableWindowPairing, forKey: enableWindowPairingKey)
      NotificationCenter.default.post(name: .settingsChanged, object: nil)

      // If disabled, clear all existing pairs
      if !enableWindowPairing {
        WindowPairManager.shared.clearAll()
      }
    }
  }
}

extension Notification.Name {
  static let settingsChanged = Notification.Name("settingsChanged")
}
