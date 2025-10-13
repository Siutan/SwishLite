//
//  PreviewOverlay.swift
//  SwishLite
//
//  Shows visual preview of where the window will be positioned
//

import AppKit

@MainActor
final class PreviewOverlay {
  static let shared = PreviewOverlay()

  private var overlayWindow: NSWindow?
  private var previewRect: CGRect?
  private var previewType: PreviewType?

  enum PreviewType {
    case leftHalf
    case rightHalf
    case maximize
    case minimize
    case cancel
  }

  private init() {}

  func showPreview(for direction: SwipeDirection, screen: NSScreen) {
    // We intentionally do not depend on the target window here.
    // The overlay only previews the intended placement on the active screen.
    let targetRect = calculateTargetRect(for: direction, screen: screen)
    previewRect = targetRect

    // Determine preview type
    switch direction {
    case .left:
      previewType = .leftHalf
    case .right:
      previewType = .rightHalf
    case .up:
      previewType = .maximize
    case .down:
      previewType = .minimize
    }

    // Create or update overlay
    createOverlayWindow(for: targetRect, screen: screen)
  }

  func showCancelPreview() {
    // For cancel, show a small indicator at the center of the screen
    guard let screen = NSScreen.main else { return }
    let vf = screen.visibleFrame
    let cancelRect = CGRect(
      x: vf.midX - 25,
      y: vf.midY - 25,
      width: 50,
      height: 50
    )
    previewType = .cancel
    createOverlayWindow(for: cancelRect, screen: screen)
  }

  func hidePreview() {
    overlayWindow?.orderOut(nil)
    overlayWindow = nil
    previewRect = nil
    previewType = nil
  }

  private func calculateTargetRect(for direction: SwipeDirection, screen: NSScreen) -> CGRect {
    let vf = screen.visibleFrame
    let padding: CGFloat = 0

    switch direction {
    case .left:
      return CGRect(
        x: vf.minX + padding,
        y: vf.minY + padding,
        width: (vf.width / 2) - padding * 1.5,
        height: vf.height - padding * 2
      )
    case .right:
      return CGRect(
        x: vf.minX + (vf.width / 2) + padding * 0.5,
        y: vf.minY + padding,
        width: (vf.width / 2) - padding * 1.5,
        height: vf.height - padding * 2
      )
    case .up:
      return CGRect(
        x: vf.minX + padding,
        y: vf.minY + padding,
        width: vf.width - padding * 2,
        height: vf.height - padding * 2
      )
    case .down:
      // For minimize, show a small preview at the bottom of the screen
      return CGRect(
        x: vf.minX + vf.width - 200,
        y: vf.minY + 10,
        width: 180,
        height: 40
      )
    }
  }

  private func createOverlayWindow(for rect: CGRect, screen: NSScreen) {
    // Remove existing overlay
    overlayWindow?.orderOut(nil)

    // Create new overlay window
    let window = NSWindow(
      contentRect: rect,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    // Configure window properties
    window.backgroundColor = NSColor.clear
    window.isOpaque = false
    window.hasShadow = false
    window.level = NSWindow.Level.floating
    window.ignoresMouseEvents = true
    window.collectionBehavior = [.canJoinAllSpaces, .stationary]

    // Create preview view
    let previewView = PreviewView(frame: rect)
    previewView.previewType = previewType
    window.contentView = previewView

    // Show the overlay
    window.orderFrontRegardless()

    overlayWindow = window

    // Preview stays visible until manually dismissed
    // No auto-hide timeout - preview updates continuously based on gesture
  }
}

private class PreviewView: NSView {
  var previewType: PreviewOverlay.PreviewType?

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    guard let previewType = previewType else { return }

    let context = NSGraphicsContext.current?.cgContext
    context?.saveGState()

    switch previewType {
    case .leftHalf, .rightHalf, .maximize:
      // Draw blue semi-transparent overlay for window positioning
      context?.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor)
      context?.fill(bounds)

      // Draw border
      context?.setStrokeColor(NSColor.controlAccentColor.cgColor)
      context?.setLineWidth(3.0)
      context?.stroke(bounds)

    case .minimize:
      // Draw yellow semi-transparent overlay for minimize
      context?.setFillColor(NSColor.systemYellow.withAlphaComponent(0.4).cgColor)
      context?.fill(bounds)

      // Draw border
      context?.setStrokeColor(NSColor.systemYellow.cgColor)
      context?.setLineWidth(2.0)
      context?.stroke(bounds)

      // Draw minimize icon
      let iconRect = NSRect(x: bounds.midX - 10, y: bounds.midY - 10, width: 20, height: 20)
      context?.setFillColor(NSColor.black.cgColor)
      context?.fill(iconRect)

    case .cancel:
      // Draw red semi-transparent overlay for cancel
      context?.setFillColor(NSColor.systemRed.withAlphaComponent(0.4).cgColor)
      context?.fill(bounds)

      // Draw border
      context?.setStrokeColor(NSColor.systemRed.cgColor)
      context?.setLineWidth(3.0)
      context?.stroke(bounds)

      // Draw X icon
      let centerX = bounds.midX
      let centerY = bounds.midY
      let size: CGFloat = 20
      context?.setStrokeColor(NSColor.white.cgColor)
      context?.setLineWidth(3.0)
      context?.move(to: CGPoint(x: centerX - size / 2, y: centerY - size / 2))
      context?.addLine(to: CGPoint(x: centerX + size / 2, y: centerY + size / 2))
      context?.move(to: CGPoint(x: centerX + size / 2, y: centerY - size / 2))
      context?.addLine(to: CGPoint(x: centerX - size / 2, y: centerY + size / 2))
      context?.strokePath()
    }

    context?.restoreGState()
  }
}
