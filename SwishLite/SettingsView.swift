//
//  SettingsView.swift
//  SwishLite
//
//  SwiftUI view for the settings window
//

import AppKit
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
      SegmentedControl(
        labels: ["General", "Behaviour"],
        selection: Binding(
          get: { selectedTab == .general ? 0 : 1 },
          set: { selectedTab = ($0 == 0) ? .general : .behaviour }
        )
      )
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 16)
      .padding(.top, 12)

      Spacer(minLength: 10)

      Group {
        switch selectedTab {
        case .general:
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("SwishLite")
                  .font(.system(size: 14, weight: .semibold))
                Text(hasPermission ? "Active" : "Needs Permission")
                  .font(.system(size: 11, weight: .medium))
                  .foregroundColor(hasPermission ? .primary : .secondary)
              }

              Spacer()

              Circle()
                .fill(hasPermission ? Color.green : Color.yellow)
                .frame(width: 8, height: 8)
            }

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

            Toggle(
              "Enable Gestures",
              isOn: Binding(
                get: { EventMonitor.shared.isEnabled },
                set: { EventMonitor.shared.setEnabled($0) }
              )
            )
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))

            if !hasPermission {
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
          }
          .frame(maxWidth: .infinity, alignment: .leading)

        case .behaviour:
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

            Toggle("Block Events While Held", isOn: $settings.blockEventsWhileFnHeld)
              .toggleStyle(SwitchToggleStyle(tint: .accentColor))
              .help(
                "Prevents mouse clicks and scrolling from passing through to other apps while holding the master key"
              )

            Toggle("Enable Window Pairing", isOn: $settings.enableWindowPairing)
              .toggleStyle(SwitchToggleStyle(tint: .accentColor))
              .help("Automatically pairs windows when snapping to left/right halves")

            VStack(alignment: .leading, spacing: 12) {
              Text("Preview")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

              HStack {
                Text("Color")
                  .font(.system(size: 12, weight: .medium))
                  .frame(width: 60, alignment: .leading)

                ColorPicker(
                  "",
                  selection: Binding(
                    get: { Color(settings.previewColor) },
                    set: { settings.previewColor = NSColor($0) }
                  ),
                  supportsOpacity: false
                )
                .labelsHidden()
              }

              HStack {
                Text("Opacity")
                  .font(.system(size: 12, weight: .medium))
                  .frame(width: 60, alignment: .leading)

                Slider(value: $settings.previewOpacity, in: 0.1...0.8, step: 0.05)
                Text("\(Int(settings.previewOpacity * 100))%")
                  .font(.system(size: 11, weight: .medium))
                  .foregroundColor(.secondary)
                  .frame(width: 44, alignment: .trailing)
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)

      Spacer(minLength: 10)

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
      .padding(.horizontal, 12)
      .padding(.bottom, 12)
    }
    .frame(width: 380)
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

private struct SegmentedControl: NSViewRepresentable {
  let labels: [String]
  @Binding var selection: Int

  func makeNSView(context: Context) -> NSSegmentedControl {
    let control = NSSegmentedControl(
      labels: labels,
      trackingMode: .selectOne,
      target: context.coordinator,
      action: #selector(Coordinator.changed(_:))
    )
    control.selectedSegment = selection
    control.segmentStyle = .rounded
    control.controlSize = .small
    control.font = NSFont.systemFont(ofSize: 12, weight: .medium)
    return control
  }

  func updateNSView(_ nsView: NSSegmentedControl, context: Context) {
    if nsView.segmentCount != labels.count {
      nsView.segmentCount = labels.count
      for (index, label) in labels.enumerated() {
        nsView.setLabel(label, forSegment: index)
      }
    }

    if nsView.selectedSegment != selection {
      nsView.selectedSegment = selection
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(selection: $selection)
  }

  final class Coordinator: NSObject {
    var selection: Binding<Int>

    init(selection: Binding<Int>) {
      self.selection = selection
    }

    @objc func changed(_ sender: NSSegmentedControl) {
      selection.wrappedValue = sender.selectedSegment
    }
  }
}
