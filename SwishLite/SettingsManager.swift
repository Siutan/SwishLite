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
  private let previewColorRedKey = "previewColorRed"
  private let previewColorGreenKey = "previewColorGreen"
  private let previewColorBlueKey = "previewColorBlue"
  private let previewOpacityKey = "previewOpacity"

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

    let savedRed = defaults.object(forKey: previewColorRedKey) as? Double
    let savedGreen = defaults.object(forKey: previewColorGreenKey) as? Double
    let savedBlue = defaults.object(forKey: previewColorBlueKey) as? Double

    if let red = savedRed, let green = savedGreen, let blue = savedBlue {
      self.previewColor = NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
    } else {
      self.previewColor = SettingsManager.defaultPreviewColor()
    }

    let savedOpacity = defaults.object(forKey: previewOpacityKey) as? Double
    self.previewOpacity = savedOpacity ?? 0.3
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

  // Preview overlay appearance
  @Published var previewColor: NSColor {
    didSet {
      storePreviewColor(previewColor)
      NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
  }

  @Published var previewOpacity: Double {
    didSet {
      let clamped = min(max(previewOpacity, 0.05), 1.0)
      if clamped != previewOpacity {
        previewOpacity = clamped
        return
      }
      defaults.set(previewOpacity, forKey: previewOpacityKey)
      NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
  }

  private static func defaultPreviewColor() -> NSColor {
    let accent = NSColor.controlAccentColor
    return accent.usingColorSpace(.sRGB) ?? accent
  }

  private func storePreviewColor(_ color: NSColor) {
    let colorToStore = color.usingColorSpace(.sRGB) ?? color
    defaults.set(colorToStore.redComponent, forKey: previewColorRedKey)
    defaults.set(colorToStore.greenComponent, forKey: previewColorGreenKey)
    defaults.set(colorToStore.blueComponent, forKey: previewColorBlueKey)
  }
}

extension Notification.Name {
  static let settingsChanged = Notification.Name("settingsChanged")
}
