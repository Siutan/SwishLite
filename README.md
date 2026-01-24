# SwishLite

A lightweight window manager for macOS 15+ (Sequoia) that uses **Fn + two‑finger swipe** gestures to manage windows.

## Features

- **Half & Quadrant Snaps**: Left/right snaps, plus diagonals for corners
- **Maximize / Minimize**: Up to maximize, down to minimize
- **Menu Bar App**: Runs discreetly in the background
- **Configurable Sensitivity**: Adjust detection sensitivity
- **Custom Preview Style**: Choose preview color and opacity
- **Multi‑Display Support**: Works seamlessly across multiple monitors

## How It Works

While holding the **Fn** key:

- Two-finger swipe **left** → Snap window to left half
- Two-finger swipe **right** → Snap window to right half
- Two-finger swipe **up** → Maximize window
- Two-finger swipe **down** → Minimize window
- Two-finger swipe **left + up** (or **diagonal up‑left**) → Top‑left quadrant
- Two-finger swipe **right + up** (or **diagonal up‑right**) → Top‑right quadrant
- Two-finger swipe **left + down** (or **diagonal down‑left**) → Bottom‑left quadrant
- Two-finger swipe **right + down** (or **diagonal down‑right**) → Bottom‑right quadrant

The app operates on the **window under your cursor**, making it very intuitive to use.

## Requirements

- macOS 15.0 (Sequoia) or later
- **Accessibility Permission** (required to control windows)

## Install (GitHub Release)

If you downloaded an unsigned release from GitHub, macOS may block it the first time.

1. Open the app once (it will be blocked).
2. Go to **System Settings → Privacy & Security**.
3. Under **Security**, click **Open Anyway** for SwishLite.
4. Confirm **Open** in the dialog.

Alternative: Control‑click the app in Finder → **Open** → **Open**.

## Building & Running (Xcode)

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
- **Preview Style**: Set preview color and opacity
- **About**: View app information and gesture hints
- **Quit**: Exit the application

## Credits

Inspired and based on the much more feature rich and better [Swish](https://github.com/chrenn/swish-dl)
