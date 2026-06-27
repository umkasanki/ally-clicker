import Foundation
import CoreGraphics

// MARK: - DwellEngine (runtime state machine, OS-independent)
//
// This file specifies the CORE behavior of the macOS dwell-click tool, ported
// 1:1 from Point-N-Click. It is intentionally PURE: it takes cursor positions,
// elapsed time, and the current settings, and returns a list of effects to
// perform (update a highlight, fire a click). It performs NO event injection
// and touches NO macOS APIs, so it can be unit-tested directly. Wire the
// outputs to CGEvent injection and the panel UI at the edges of the app.
//
// All behavior below was verified frame-by-frame from the user's screen
// recordings. See point-n-click-macos-port-brief.md §4 for the rationale.
//
// VISUAL MODEL (what the panel shows):
//   • red button    = armedAction (fires on the next desktop dwell)
//   • yellow button = button under the cursor, dwell countdown in progress
//   • no highlight  = nothing armed (armedAction == nil)

// MARK: Click actions (panel buttons)

enum ClickAction: String, Codable, CaseIterable {
    case left
    case right
    case middle
    case leftDrag
    case rightDrag
    case middleDrag
    case doubleClick     // the "2" button
    case rightDouble
    case rightThenLeft   // registry: RightLeft
    // NOTE: registry also has Left2 / Middle2 ("secondary" variants) whose exact
    // semantics are unconfirmed (see brief §7). Add once clarified.
}

// MARK: Cursor zones (where the cursor is right now)

enum CursorZone: Equatable {
    case desktop                       // anywhere outside the panel
    case panel(button: ClickAction?)   // over the panel; button == nil means over
                                       // panel chrome (title/gap), not a selectable button
    case exitButton                    // the panel's Exit button (uses dwellTimeExit)
}

// MARK: Effects the engine asks the app to perform

enum DwellEffect: Equatable {
    case setArmed(ClickAction?)                       // update the red highlight (nil = clear)
    case dwellProgress(button: ClickAction, fraction: Double) // drive the yellow fill 0...1
    case clearProgress                                // no dwell in progress
    case fire(ClickAction, at: CGPoint)               // inject this click at this point
    case requestExit                                  // user dwelled the Exit button
}

// MARK: Engine

struct DwellEngine {
    var settings: PNCSettings

    // Internal state
    private(set) var armed: ClickAction? = nil
    private var dwellAnchor: CGPoint? = nil   // where the current dwell started
    private var dwellElapsed: TimeInterval = 0
    private var lastZone: CursorZone = .desktop

    init(settings: PNCSettings) { self.settings = settings }

    /// Advance the engine by `dt` seconds given the current cursor position and
    /// the zone it is in. Returns the effects to apply this tick.
    ///
    /// Call this on a fixed cadence (settings.stillness.trackerIntervalMs).
    mutating func tick(cursor: CGPoint, zone: CursorZone, dt: TimeInterval) -> [DwellEffect] {
        var effects: [DwellEffect] = []

        // 1) SWIPE-RESET: the instant the cursor enters the panel from the
        //    desktop, the armed action is cleared. This is the whole trick —
        //    brushing the panel cancels, with no precision and no waiting.
        if isPanel(zone) && !isPanel(lastZone) {
            if armed != nil {
                armed = nil
                effects.append(.setArmed(nil))
            }
            resetDwell(at: cursor)
        }
        lastZone = zone

        // 2) STILLNESS: any movement beyond the sensitivity tolerance restarts
        //    the dwell timer. While the cursor stays within tolerance, the timer
        //    keeps accumulating.
        let tolerance = CGFloat(settings.stillness.sensitivity) // pixel radius (confirm range)
        if let anchor = dwellAnchor, distance(cursor, anchor) <= tolerance {
            dwellElapsed += dt
        } else {
            resetDwell(at: cursor)
        }

        // 3) Act based on where the cursor is.
        switch zone {
        case .exitButton:
            let progress = dwellElapsed / settings.timing.dwellTimeExitSeconds
            if progress >= 1 {
                effects.append(.requestExit)
                resetDwell(at: cursor)
            }

        case .panel(button: let button?):
            // Dwelling on a click button commits it (yellow fills, then red).
            let threshold = settings.timing.dwellTimeSeconds
            let fraction = min(dwellElapsed / threshold, 1)
            effects.append(.dwellProgress(button: button, fraction: fraction))
            if fraction >= 1 {
                armed = button
                effects.append(.setArmed(button))
                resetDwell(at: cursor)
            }

        case .panel(button: nil):
            // On the panel but not over a button: nothing to commit.
            effects.append(.clearProgress)

        case .desktop:
            // Auto-click only happens when something is armed. After a swipe
            // (armed == nil) the cursor can rest on the desktop forever and
            // nothing fires — exactly the verified behavior.
            guard let action = armed else {
                effects.append(.clearProgress)
                break
            }
            let threshold = settings.timing.dwellTimeMouseSeconds
            if dwellElapsed >= threshold {
                effects.append(.fire(action, at: cursor))
                resetDwell(at: cursor)
                // POST-CLICK REVERT: after firing, return to left (DefaultLeft).
                // This is the path that DOES auto-arm, unlike the swipe path.
                // (Strongly indicated by video; confirm — see brief §7.)
                let next: ClickAction? = settings.clicks.defaultLeft ? .left : nil
                if armed != next {
                    armed = next
                    effects.append(.setArmed(next))
                }
            }
        }

        return effects
    }

    // MARK: Helpers

    private mutating func resetDwell(at point: CGPoint) {
        dwellAnchor = point
        dwellElapsed = 0
    }

    private func isPanel(_ zone: CursorZone) -> Bool {
        switch zone {
        case .panel, .exitButton: return true
        case .desktop: return false
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

// MARK: - Notes for implementers
//
// • Hit-testing (mapping a cursor point to a CursorZone) lives OUTSIDE this
//   engine — the panel UI knows its own button frames. Feed the result in.
// • trackerIntervalMs (5 ms here) is the tick cadence. Pass the real dt.
// • sensitivity is treated as a pixel radius; verify the real-world range and
//   whether the speed-test calibration scales it (BaselineFlags / AverageVelocity).
// • Injection mapping (wire `.fire` to CGEvent):
//     left  -> .leftMouseDown/.leftMouseUp
//     right -> .rightMouseDown/.rightMouseUp
//     middle-> .otherMouseDown/.otherMouseUp (button .center)
//     drag  -> down, move(s), up
//     doubleClick -> two left clicks with .mouseEventClickState = 2
//   Posting synthetic events requires Accessibility permission (see brief §4).
