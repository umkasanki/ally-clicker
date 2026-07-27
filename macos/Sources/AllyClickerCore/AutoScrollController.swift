import Foundation

// MARK: - AutoScrollController
//
// Pure state machine for the middle-click auto-scroll MODE (the lifecycle around
// the AutoScrollEngine math).
//
// Lifecycle (see spec §7):
//   1. Middle click → activate: the click point becomes the scroll anchor.
//   2. While active: each tick produces a scroll delta from anchor → cursor.
//      Moving farther from the anchor scrolls faster; inside the dead zone, nothing.
//   3. Any subsequent click (e.g. left) → deactivate: scroll mode ends.
//
// The app drives this: it calls activate() when the engine fires .middle, calls
// tick() on the scroll timer while active, and calls deactivate() when another
// action fires. The controller owns no macOS APIs.

public final class AutoScrollController {
    private let engine: AutoScrollEngine
    private var anchor: Point?

    public init(config: Settings.AutoScroll = Settings.AutoScroll()) {
        self.engine = AutoScrollEngine(config: config)
    }

    /// True while scroll mode is engaged.
    public var isActive: Bool { anchor != nil }

    /// Enter scroll mode; `point` becomes the anchor the cursor scrolls relative to.
    public func activate(at point: Point) {
        anchor = point
    }

    /// Leave scroll mode.
    public func deactivate() {
        anchor = nil
    }

    /// Toggle scroll mode (middle click while active exits; while inactive enters).
    public func toggle(at point: Point) {
        if isActive { deactivate() } else { activate(at: point) }
    }

    /// Scroll delta for this tick, or nil if scroll mode is not active.
    public func tick(cursor: Point) -> (dx: Double, dy: Double)? {
        guard let anchor else { return nil }
        return engine.delta(anchor: anchor, cursor: cursor)
    }
}
