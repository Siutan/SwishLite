//
//  SettingsView.swift
//  SwishLite
//
//  SwiftUI view for the settings window
//

import Combine
import SwiftUI

struct SettingsView: View {
  @ObservedObject var settings = SettingsManager.shared
  @State private var hasPermission = PermissionsManager.shared.checkAccessibilityPermission()
  @State private var selectedTab: SettingsTab = .general

  enum SettingsTab {
    case general
    case behaviour
  }

  // Timer for polling permission status
  let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: 0) {
      // Header / Status
      HStack {
        Circle()
          .fill(hasPermission ? Color.green : Color.yellow)
          .frame(width: 8, height: 8)

        Text(hasPermission ? "Active" : "Needs Permission")
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(hasPermission ? .primary : .secondary)

        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color(NSColor.controlBackgroundColor))

      Divider()

      Picker("", selection: $selectedTab) {
        Text("General").tag(SettingsTab.general)
        Text("Behaviour").tag(SettingsTab.behaviour)
      }
      .pickerStyle(SegmentedPickerStyle())
      .padding(.horizontal, 16)
      .padding(.vertical, 8)

      Divider()

      Group {
        switch selectedTab {
        case .general:
          // General Tab
          VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
              Text("Master Key")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

              Picker("Master Key", selection: $settings.modifierKey) {
                ForEach(SettingsManager.ModifierKey.allCases) { key in
                  Text(key.rawValue).tag(key)
                }
              }
              .labelsHidden()
              .pickerStyle(MenuPickerStyle())
              .frame(maxWidth: 120)

              Text("Hold this key to perform gestures.")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Divider()

            Toggle(
              "Enable Gestures",
              isOn: Binding(
                get: { EventMonitor.shared.isEnabled },
                set: { EventMonitor.shared.setEnabled($0) }
              )
            )
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))

            if !hasPermission {
              Divider()

              Button(action: {
                _ = PermissionsManager.shared.ensureAccessibilityPermission(prompt: true)
              }) {
                HStack {
                  Image(systemName: "lock.fill")
                  Text("Grant Permission")
                }
                .frame(maxWidth: .infinity)
              }
              .buttonStyle(.borderedProminent)
            }

            Spacer()
          }
          .padding(30)

        case .behaviour:
          // Behaviour Tab
          VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
              Text("Sensitivity")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

              Picker(
                "Sensitivity",
                selection: Binding(
                  get: {
                    let threshold = GestureClassifier.shared.detectionThreshold
                    if threshold >= 40 { return 0 }
                    if threshold >= 25 { return 1 }
                    return 2
                  },
                  set: { index in
                    switch index {
                    case 0: GestureClassifier.shared.detectionThreshold = 40.0
                    case 1: GestureClassifier.shared.detectionThreshold = 25.0
                    case 2: GestureClassifier.shared.detectionThreshold = 15.0
                    default: break
                    }
                  }
                )
              ) {
                Text("Low").tag(0)
                Text("Medium").tag(1)
                Text("High").tag(2)
              }
              .pickerStyle(SegmentedPickerStyle())
            }

            Divider()

            Toggle("Block Events While Held", isOn: $settings.blockEventsWhileFnHeld)
              .toggleStyle(SwitchToggleStyle(tint: .accentColor))
              .help(
                "Prevents mouse clicks and scrolling from passing through to other apps while holding the master key"
              )

            Toggle("Enable Window Pairing", isOn: $settings.enableWindowPairing)
              .toggleStyle(SwitchToggleStyle(tint: .accentColor))
              .help("Automatically pairs windows when snapping to left/right halves")

            Spacer()
          }
          .padding(30)
        }
      }
      .frame(height: 300)  // Fixed height for content

      Divider()

      // Footer Actions
      HStack {
        Button("About") {
          showAbout()
        }
        .buttonStyle(.link)

        Spacer()

        Button("Quit") {
          NSApplication.shared.terminate(nil)
        }
        .buttonStyle(.bordered)
      }
      .padding(12)
      .background(Color(NSColor.controlBackgroundColor))
    }
    .frame(width: 360)  // Increased width to accommodate padding
    .fixedSize(horizontal: false, vertical: true)
    .onReceive(timer) { _ in
      hasPermission = PermissionsManager.shared.checkAccessibilityPermission()
    }
  }

  private func showAbout() {
    let alert = NSAlert()
    alert.messageText = "SwishLite"
    alert.informativeText = """
      A lightweight window manager for macOS.

      Hold the modifier key and:
      • Swipe left/right → Snap window to half
      • Swipe up → Maximize window
      • Swipe down → Minimize window

      Version 1.0
      """
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }
}
