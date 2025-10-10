//
//  LayoutEngine.swift
//  SwishLite
//
//  Computes target rectangles and applies them via Accessibility APIs
//

import AppKit
import ApplicationServices

@MainActor
final class LayoutEngine {
    static let shared = LayoutEngine()
    
    var edgePadding: CGFloat = 0 // Optional padding from screen edges
    
    private init() {}
    
    func snapLeft(_ window: AXUIElement, screen: NSScreen) -> Bool {
        // Rationale: Axis-aligned half snaps are predictable and support muscle memory.
        // We avoid weighted proximity or fancy layouts to keep interactions instantaneous.
        let vf = screen.visibleFrame
        let targetRect = CGRect(
            x: vf.minX + edgePadding,
            y: vf.minY + edgePadding,
            width: (vf.width / 2) - edgePadding * 1.5,
            height: vf.height - edgePadding * 2
        )
        return applyFrameWithAnchoring(targetRect, to: window, screen: screen, anchor: .left)
    }
    
    func snapRight(_ window: AXUIElement, screen: NSScreen) -> Bool {
        let vf = screen.visibleFrame
        let targetRect = CGRect(
            x: vf.minX + (vf.width / 2) + edgePadding * 0.5,
            y: vf.minY + edgePadding,
            width: (vf.width / 2) - edgePadding * 1.5,
            height: vf.height - edgePadding * 2
        )
        return applyFrameWithAnchoring(targetRect, to: window, screen: screen, anchor: .right)
    }
    
    func maximize(_ window: AXUIElement, screen: NSScreen) -> Bool {
        // Rationale: Maximize honors menu bar and dock by using visibleFrame.
        let vf = screen.visibleFrame
        let targetRect = CGRect(
            x: vf.minX + edgePadding,
            y: vf.minY + edgePadding,
            width: vf.width - edgePadding * 2,
            height: vf.height - edgePadding * 2
        )
        return applyFrameWithAnchoring(targetRect, to: window, screen: screen, anchor: .center)
    }
    
    private enum AnchorPosition {
        case left
        case right
        case center
    }
    
    func minimize(_ window: AXUIElement) -> Bool {
        // Rationale: Only attempt minimize when the attribute is settable; many apps disallow it.
        var settable = DarwinBoolean(false)
        let checkResult = AXUIElementIsAttributeSettable(
            window,
            kAXMinimizedAttribute as CFString,
            &settable
        )
        
        guard checkResult == .success && settable.boolValue else {
            return false
        }
        
        // Set minimized to true
        let result = AXUIElementSetAttributeValue(
            window,
            kAXMinimizedAttribute as CFString,
            kCFBooleanTrue
        )
        
        return result == .success
    }
    
    private func applyFrameWithAnchoring(_ frame: CGRect, to window: AXUIElement, screen: NSScreen, anchor: AnchorPosition) -> Bool {
        // Rationale: We set position before size, then size again after position.
        // Some apps constrain size based on anchors; this sequence yields more consistent results.
        // We adjust final position if the window can't reach requested size (e.g., min/max constraints).
        
        // Check if position and size are settable
        var posSettable = DarwinBoolean(false)
        var sizeSettable = DarwinBoolean(false)
        
        let posCheck = AXUIElementIsAttributeSettable(
            window,
            kAXPositionAttribute as CFString,
            &posSettable
        )
        
        let sizeCheck = AXUIElementIsAttributeSettable(
            window,
            kAXSizeAttribute as CFString,
            &sizeSettable
        )
        
        guard posCheck == .success && posSettable.boolValue,
              sizeCheck == .success && sizeSettable.boolValue else {
            return false
        }
        
        // Convert frame to CG coordinates (origin at top-left of main display)
        let cgFrame = convertToCGCoordinates(frame, screen: screen)
        
        // First, set position to top-left corner to avoid constraints from previous anchoring.
        var position = CGPoint(x: cgFrame.origin.x, y: cgFrame.origin.y)
        if let posValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(
                window,
                kAXPositionAttribute as CFString,
                posValue
            )
        }
        
        // Now set size
        var size = CGSize(width: cgFrame.size.width, height: cgFrame.size.height)
        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            return false
        }
        
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        
        guard sizeResult == .success else {
            return false
        }
        
        // Read back the actual size that was set (may be constrained by min/max size)
        var actualSizeValue: AnyObject?
        let actualSize: CGSize
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &actualSizeValue) == .success,
           let axSize = actualSizeValue as! AXValue?,
           AXValueGetValue(axSize, .cgSize, &size) {
            actualSize = size
        } else {
            actualSize = cgFrame.size
        }
        
        // Adjust position based on anchor if window couldn't reach target size.
        position = CGPoint(x: cgFrame.origin.x, y: cgFrame.origin.y)
        
        if actualSize.width < cgFrame.size.width {
            // Window is narrower than requested - anchor appropriately
            switch anchor {
            case .left:
                // Keep at left edge (no change needed)
                break
            case .right:
                // Anchor to right edge
                position.x = cgFrame.origin.x + (cgFrame.size.width - actualSize.width)
            case .center:
                // Center in available space
                position.x = cgFrame.origin.x + (cgFrame.size.width - actualSize.width) / 2
            }
        }
        
        // Set the final adjusted position
        guard let posValue = AXValueCreate(.cgPoint, &position) else {
            return false
        }
        
        let posResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            posValue
        )
        
        // Try setting size one more time; some windows only resize properly after a position set.
        if let finalSizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(
                window,
                kAXSizeAttribute as CFString,
                finalSizeValue
            )
        }
        
        return posResult == .success
    }
    
    private func convertToCGCoordinates(_ frame: CGRect, screen: NSScreen) -> CGRect {
        // AppKit origin is bottom-left; CG/AX origin is top-left of the main display.
        // We convert here to keep all AX operations in a consistent coordinate space.
        guard let mainScreen = NSScreen.main else { return frame }
        
        let screenHeight = mainScreen.frame.height
        
        // Convert AppKit y to CG y
        let cgY = screenHeight - (frame.origin.y + frame.height)
        
        return CGRect(
            x: frame.origin.x,
            y: cgY,
            width: frame.width,
            height: frame.height
        )
    }
}

