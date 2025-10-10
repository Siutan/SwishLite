# SwishLite

A lightweight window manager for macOS 15+ (Sequoia) that uses intuitive **Fn + two-finger swipe** gestures to manage windows.

## Features

- **Snap Left/Right**: Hold Fn + swipe left/right to snap windows to half screen
- **Maximize**: Hold Fn + swipe up to maximize window to visible frame
- **Minimize**: Hold Fn + swipe down to minimize window
- **Menu Bar App**: Runs discreetly in the background as a menu bar app
- **Configurable Sensitivity**: Adjust gesture sensitivity to your preference
- **Multi-Display Support**: Works seamlessly across multiple monitors

## How It Works

While holding the **Fn** key:

- Two-finger swipe **left** → Snap window to left half
- Two-finger swipe **right** → Snap window to right half
- Two-finger swipe **up** → Maximize window
- Two-finger swipe **down** → Minimize window

The app operates on the **window under your cursor**, making it very intuitive to use.

## Requirements

- macOS 15.0 (Sequoia) or later
- **Accessibility Permission** (required to control windows)

## Building & Running

1. Open `SwishLite.xcodeproj` in Xcode
2. Build and run the project (⌘R)
3. Grant Accessibility permission when prompted:
   - System Settings → Privacy & Security → Accessibility → Enable SwishLite

## First Time Setup

When you first launch SwishLite:

1. The app will appear in your menu bar (look for the swipe icon)
2. macOS will prompt you to grant Accessibility permission
3. Click "Open System Settings" and enable SwishLite in the Accessibility list
4. You may need to restart the app after granting permission

## Menu Bar Features

Click the SwishLite icon in your menu bar to access:

- **Enable/Disable Gestures**: Toggle the window management on/off
- **Sensitivity Settings**: Choose Low/Medium/High sensitivity for gestures
- **About**: View app information and gesture hints
- **Quit**: Exit the application

## Architecture

The app is built with a modular architecture:

- **PermissionsManager**: Handles Accessibility permission checks
- **EventMonitor**: Global event monitoring for Fn key and scroll gestures
- **GestureClassifier**: Interprets scroll deltas as directional swipes
- **WindowResolver**: Finds the window under the cursor using AX APIs
- **LayoutEngine**: Computes and applies window positions/sizes
- **MenuBarController**: Manages the menu bar interface

## Technical Details

- Built using **AppKit** for native macOS integration
- Uses **Accessibility APIs** (AXUIElement) for window control
- Global event monitors for system-wide gesture detection
- No App Sandbox (required for cross-app window management)
- Suitable for Developer ID distribution

## Notes

- The app does **not** use App Sandbox because Accessibility APIs require direct system access
- Momentum scroll events are ignored to prevent accidental repeats
- Windows are snapped using the screen's `visibleFrame` (respects menu bar and Dock)
- Works with notched Macs - safe areas are automatically handled

## Troubleshooting

**Gestures not working?**

- Ensure Accessibility permission is granted in System Settings
- Check that the app is enabled in the menu bar
- Try adjusting sensitivity settings

**App not appearing in Accessibility list?**

- Restart your Mac
- Try building and running from Xcode again

**External keyboard without Fn key?**

- Future versions will support custom modifier key mapping

## Distribution

To distribute this app:

1. Disable App Sandbox (already done)
2. Enable Hardened Runtime (already configured)
3. Sign with Developer ID certificate
4. Notarize with Apple
5. Distribute as DMG or ZIP

## License

Copyright © 2025 Mukil Chittybabu. All rights reserved.

## Credits

Built following best practices from Apple's Accessibility API documentation and based on the comprehensive design document in `project-implementation.md`.
