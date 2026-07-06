import Foundation
import CoreGraphics
import AllyClickerCore

// CGMouseInjector — macOS adapter for the MouseInjecting port.
// Injects synthetic mouse events at the OS level via CGEvent.
// Requires Accessibility permission (see AppDelegate.checkAccessibilityPermission()).

struct CGMouseInjector: MouseInjecting {

    func click(_ action: DwellEngine.Action, at point: Point) {
        let p = cgPoint(point)
        switch action {
        case .left:        leftClick(at: p)
        case .right:       rightClick(at: p)
        case .middle:      middleClick(at: p)
        case .doubleClick: doubleClick(at: p)
        case .leftDrag:      break  // TODO: Phase 3.4 — two-phase drag handled by a DragController
        case .rightDouble:   break  // TODO: Phase 4+ — right double click
        case .rightThenLeft: break  // TODO: Phase 4+ — right then left sequence
        }
    }

    func mouseDown(at point: Point) { post(.leftMouseDown, at: cgPoint(point)) }
    func mouseUp(at point: Point)   { post(.leftMouseUp,   at: cgPoint(point)) }

    /// Post a pixel-precise scroll. dy = vertical, dx = horizontal (screen sense;
    /// sign may need flipping for natural scrolling — verified on-device).
    func scroll(dx: Double, dy: Double) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                  wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0) else { return }
        // Negated: cursor below the anchor should scroll the content down (view
        // reveals lower content) — matches PNC / natural expectation.
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: -dy)  // vertical
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: -dx)  // horizontal
        event.post(tap: .cgSessionEventTap)
    }

    // MARK: - Click variants

    private func leftClick(at p: CGPoint) {
        postClick(.leftMouseDown, .leftMouseUp, at: p)
    }

    private func rightClick(at p: CGPoint) {
        postClick(.rightMouseDown, .rightMouseUp, at: p, button: .right)
    }

    private func middleClick(at p: CGPoint) {
        postClick(.otherMouseDown, .otherMouseUp, at: p, button: .center)
    }

    private func doubleClick(at p: CGPoint) {
        for clickState in 1...2 {
            guard
                let down = makeEvent(.leftMouseDown, at: p),
                let up   = makeEvent(.leftMouseUp,   at: p)
            else { continue }
            down.setIntegerValueField(.mouseEventClickState, value: Int64(clickState))
            up.setIntegerValueField(.mouseEventClickState,   value: Int64(clickState))
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - Low-level helpers

    /// Post a down+up pair with clickState=1 (mimics real hardware single click).
    private func postClick(_ down: CGEventType, _ up: CGEventType,
                           at p: CGPoint, button: CGMouseButton = .left) {
        if let d = makeEvent(down, at: p, button: button) {
            d.setIntegerValueField(.mouseEventClickState, value: 1)
            d.post(tap: .cgSessionEventTap)
        }
        if let u = makeEvent(up, at: p, button: button) {
            u.setIntegerValueField(.mouseEventClickState, value: 1)
            u.post(tap: .cgSessionEventTap)
        }
    }

    private func post(_ type: CGEventType, at p: CGPoint, button: CGMouseButton = .left) {
        makeEvent(type, at: p, button: button)?.post(tap: .cgSessionEventTap)
    }

    private func makeEvent(_ type: CGEventType, at p: CGPoint, button: CGMouseButton = .left) -> CGEvent? {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: button)
    }

    private func cgPoint(_ point: Point) -> CGPoint {
        CGPoint(x: point.x, y: point.y)
    }
}
