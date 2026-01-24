# Repository Guidelines

## Project Structure & Module Organization
- `SwishLite/` contains the Swift source for the macOS menu bar app (AppKit-based).
- Core modules live as single-file classes (e.g., `EventMonitor.swift`, `GestureClassifier.swift`, `LayoutEngine.swift`, `WindowResolver.swift`, `MenuBarController.swift`).
- UI and settings are managed in `SettingsView.swift` and `SettingsWindowController.swift`.
- Assets and metadata live in `SwishLite/Assets.xcassets/` and `SwishLite/Info.plist`.
- Project entry points are `SwishLite.xcodeproj` (Xcode) and `Package.swift` (SwiftPM).

## Build, Test, and Development Commands
- `open SwishLite.xcodeproj` — open the project in Xcode.
- In Xcode, run with ⌘R to build and launch the menu bar app.
- `xcodebuild -project SwishLite.xcodeproj -scheme SwishLite -configuration Debug build` — CLI build (useful for CI).
- `swift build` — builds the SwiftPM target (note: assets/Info.plist are excluded in `Package.swift`).

## Coding Style & Naming Conventions
- Indentation: 2 spaces in Swift files.
- Swift types are `UpperCamelCase` (e.g., `PermissionsManager`), methods and properties are `lowerCamelCase`.
- Prefer small, focused classes with single-responsibility, matching existing module names.
- Keep macOS AppKit and Accessibility APIs on the main actor where needed.

## Testing Guidelines
- No automated test suite is currently present.
- When changing behavior, perform manual validation:
  - Launch the app, enable Accessibility permission, and verify Fn + two‑finger swipe gestures on multiple displays.
  - Validate menu bar toggles and settings persistence.
- If adding tests, place them in a new `SwishLiteTests/` target and mirror file names (e.g., `EventMonitorTests.swift`).

## Commit & Pull Request Guidelines
- Recent commits use a lightweight conventional style: `feat: ...` or `refactor(Module): ...`.
- Keep commit subjects short and specific; include the module in parentheses when relevant.
- PRs should include a brief description, list of user-visible changes, and manual test notes; add screenshots only for UI changes.

## Security & Configuration Tips
- Accessibility permission is required for window control; ensure it’s granted after first run.
- App Sandbox is disabled by design to enable cross‑app window management.
