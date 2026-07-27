import AppKit
import AllyClickerCore

// Coordinate convention for the whole app:
//   Point (from AllyClickerCore) = TOP-LEFT global screen coordinates — the same
//   space CGEvent injection uses. AppKit/NSWindow use BOTTOM-LEFT, so conversions
//   happen only at the two edges that touch AppKit: cursor sampling and hit-testing.
//
// The flip uses the PRIMARY display height (the screen whose origin is (0,0), which
// carries the menu bar). Multi-display setups may need refinement — verify on device.

enum ScreenGeometry {
    /// Height of the primary display (origin screen).
    static var primaryHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? 0
    }

    /// AppKit bottom-left CGPoint → top-left Point (engine/CGEvent space).
    static func toTopLeft(_ p: CGPoint) -> Point {
        Point(x: Double(p.x), y: Double(primaryHeight - p.y))
    }

    /// Top-left Point → AppKit bottom-left CGPoint.
    static func toBottomLeft(_ p: Point) -> CGPoint {
        CGPoint(x: p.x, y: Double(primaryHeight) - p.y)
    }
}
