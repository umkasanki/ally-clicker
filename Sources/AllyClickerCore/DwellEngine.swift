import Foundation

// MARK: - DwellEngine
//
// Pure state machine — no macOS APIs. Input: cursor positions + time + settings.
// Output: list of effects to apply (update UI, inject click).
//
// "Dwell" = standard accessibility industry term (Apple macOS, W3C/WCAG).
// Behavior verified frame-by-frame from Point-N-Click screen recordings.
//
// Visual model:
//   red button    = armed action (fires on next desktop dwell)
//   yellow button = button under cursor, countdown in progress
//   no highlight  = nothing armed (armed == nil)

public struct DwellEngine {

    // MARK: - Nested types

    /// Which click type is selected / will fire.
    public enum Action: String, Codable, CaseIterable, Equatable {
        case left
        case right
        case middle
        case leftDrag
        case doubleClick
        // TODO: Phase 4+ — implement in InputController before exposing on the panel
        case rightDouble
        case rightThenLeft
    }

    /// One-shot panel commands — buttons that perform an immediate action on dwell
    /// instead of arming a click. These are the non-click buttons of the panel.
    public enum Command: String, Codable, Equatable, CaseIterable {
        case togglePanel     // ON/OFF — collapse / expand the panel
        case launchKeyboard  // KEYBOARD — launch the configured app
    }

    /// Where the cursor is right now.
    public enum Zone: Equatable {
        case desktop
        case panel(button: Action?)      // nil = panel chrome; otherwise an arming click button
        case panelCommand(Command)       // a one-shot command button (ON/OFF, KEYBOARD)
    }

    /// What the app should do this tick.
    public enum Effect: Equatable {
        case setArmed(Action?)
        /// Dwell countdown 0...1 on a panel button.
        /// NOTE: emitted by the engine for completeness, but the panel UI
        /// deliberately does NOT render a countdown indicator — by user preference
        /// (the user is accustomed to working without one). Kept so the feature can
        /// be enabled later without touching the engine. See spec §2.
        case dwellProgress(button: Action, fraction: Double)
        case clearProgress
        case fire(Action, at: Point)
        case dragMouseDown(at: Point)   // DRAG phase 1 committed: press and hold
        case dragMouseUp(at: Point)     // DRAG phase 2 committed (or cancelled): release
        case runCommand(Command)        // a one-shot panel command fired (ON/OFF, KEYBOARD)
    }

    // MARK: - State

    public var settings: Settings

    public private(set) var armed: Action? = nil
    /// True between a drag's mouseDown and mouseUp. Exposed so the app can show
    /// a "dragging" indicator and so callers can reason about a held button.
    public private(set) var dragActive: Bool = false
    private var dwellAnchor: Point? = nil
    private var dwellElapsed: TimeInterval = 0
    private var lastZone: Zone = .desktop
    // Drag phase-2 gating: where mouseDown happened, and whether the cursor has
    // since moved far enough to allow the mouseUp phase.
    private var dragDownPoint: Point? = nil
    private var dragHasMoved: Bool = false
    // Re-fire gating: after a fire, the cursor must move to a new target before
    // anything fires again — a parked cursor must not machine-gun clicks.
    private var awaitingMoveAfterFire: Bool = false
    private var lastFirePoint: Point? = nil
    // Command one-shot gating: which command (if any) already fired, and from where.
    // Cleared only after the cursor physically moves away — NOT on a transient zone
    // change, so collapsing the panel under a still cursor can't re-fire (flap).
    private var commandFired: Command? = nil
    private var lastCommandFirePoint: Point? = nil

    public init(settings: Settings) { self.settings = settings }

    // MARK: - Tick

    /// Advance the engine by `dt` seconds. Call every `settings.stillness.trackerIntervalMs`.
    public mutating func tick(cursor: Point, zone: Zone, dt: TimeInterval) -> [Effect] {
        var effects: [Effect] = []

        // SWIPE-RESET: entering the panel from desktop clears the armed action instantly.
        // Brushing the panel cancels with zero precision and zero waiting — the key UX insight.
        if isPanel(zone) && !isPanel(lastZone) {
            // SAFETY: if a drag is in progress, release the held button first.
            // A stuck mouse-down would be catastrophic for a hands-free user.
            if dragActive {
                dragActive = false
                dragDownPoint = nil
                dragHasMoved = false
                effects.append(.dragMouseUp(at: cursor))
            }
            if armed != nil {
                armed = nil
                effects.append(.setArmed(nil))
            }
            awaitingMoveAfterFire = false
            resetDwell(at: cursor)
        }
        lastZone = zone

        // Clear the command one-shot only after the cursor physically moves away
        // from where it fired. A command (e.g. ON/OFF) that collapses the panel
        // leaves the cursor parked — a transient zone change must NOT reopen the
        // gate, or the panel would flap. Re-firing requires a real move + re-dwell.
        if let firePoint = lastCommandFirePoint,
           cursor.distance(to: firePoint) > Double(settings.stillness.moveRadiusPx) {
            commandFired = nil
            lastCommandFirePoint = nil
        }

        // STILLNESS: movement beyond tolerance restarts the dwell timer.
        let tolerance = Double(settings.stillness.sensitivity)
        if let anchor = dwellAnchor, cursor.distance(to: anchor) <= tolerance {
            dwellElapsed += dt
        } else {
            resetDwell(at: cursor)
            // Emit clearProgress so the UI resets the countdown bar immediately on movement.
            effects.append(.clearProgress)
        }

        // Act based on cursor zone.
        switch zone {
        case .panel(button: let button?):
            let fraction = min(dwellElapsed / settings.timing.dwellTimeSeconds, 1)
            effects.append(.dwellProgress(button: button, fraction: fraction))
            if fraction >= 1 {
                armed = button
                effects.append(.setArmed(button))
                awaitingMoveAfterFire = false
                resetDwell(at: cursor)
            }

        case .panel(button: nil):
            effects.append(.clearProgress)

        case .panelCommand(let command):
            // Dwell to fire a one-shot command (no arming). Fires once per visit;
            // re-firing requires leaving the button and coming back (commandFired gate).
            if commandFired == nil {
                let fraction = min(dwellElapsed / settings.timing.dwellTimeSeconds, 1)
                if fraction >= 1 {
                    effects.append(.runCommand(command))
                    commandFired = command
                    lastCommandFirePoint = cursor
                    resetDwell(at: cursor)
                }
            }

        case .desktop:
            // SAFETY NET: a held drag must never persist once the armed action is
            // no longer a drag. Closes the entire class of "armed changed under a
            // held button" bugs — a stuck button is catastrophic for a hands-free user.
            if dragActive && armed != .leftDrag {
                dragActive = false
                dragDownPoint = nil
                dragHasMoved = false
                effects.append(.dragMouseUp(at: cursor))
            }

            // Auto-action fires only when something is armed.
            // After a swipe (armed == nil) the cursor can rest forever — nothing fires.
            guard let action = armed else {
                effects.append(.clearProgress)
                break
            }

            // RE-FIRE GATE: after a fire, require the cursor to move to a NEW target
            // before anything fires again. Matches PNC's "fires on each cursor STOP" —
            // a parked cursor must not machine-gun clicks. Applies to every mode.
            if awaitingMoveAfterFire {
                if let fired = lastFirePoint,
                   cursor.distance(to: fired) > Double(settings.stillness.moveRadiusPx) {
                    awaitingMoveAfterFire = false
                } else {
                    break  // still parked at the last fire point — wait for a real move
                }
            }

            if action == .leftDrag {
                handleDrag(cursor: cursor, into: &effects)
            } else if dwellElapsed >= settings.timing.dwellTimeMouseSeconds {
                effects.append(.fire(action, at: cursor))
                markFired(at: cursor)
                resetDwell(at: cursor)
                applyPostActionRevert(after: action, into: &effects)
            }
        }

        return effects
    }

    // MARK: - Drag (two-phase: dwell → mouseDown → move → dwell → mouseUp)

    private mutating func handleDrag(cursor: Point, into effects: inout [Effect]) {
        if !dragActive {
            // Phase 1: dwell at the start point, then press and hold.
            if dwellElapsed >= settings.timing.autoSelectDownSeconds {
                effects.append(.dragMouseDown(at: cursor))
                dragActive = true
                dragDownPoint = cursor
                dragHasMoved = false
                resetDwell(at: cursor)
            }
        } else {
            // Phase 2: require the cursor to move away from the start point first,
            // otherwise a still cursor would release immediately (zero-length drag).
            if let down = dragDownPoint, !dragHasMoved,
               cursor.distance(to: down) > Double(settings.stillness.moveRadiusPx) {
                dragHasMoved = true
            }
            // Once moved, dwell at the end point, then release.
            if dragHasMoved, dwellElapsed >= settings.timing.autoSelectUpSeconds {
                effects.append(.dragMouseUp(at: cursor))
                dragActive = false
                dragDownPoint = nil
                dragHasMoved = false
                markFired(at: cursor)
                resetDwell(at: cursor)
                applyPostActionRevert(after: .leftDrag, into: &effects)
            }
        }
    }

    /// POST-ACTION REVERT (three paths — see spec §5):
    ///   defaultLeft = true                       → revert to .left
    ///   defaultLeft = false, autoCancel = true   → clear to nil (one-shot)
    ///   defaultLeft = false, autoCancel = false  → keep action (repeat forever)
    /// The swipe path always clears to nil — that is a separate path.
    private mutating func applyPostActionRevert(after action: Action, into effects: inout [Effect]) {
        let next: Action?
        if settings.clicks.defaultLeft {
            next = .left
        } else if settings.clicks.autoCancel {
            next = nil
        } else {
            next = action
        }
        if armed != next {
            armed = next
            effects.append(.setArmed(next))
        }
    }

    private mutating func markFired(at point: Point) {
        awaitingMoveAfterFire = true
        lastFirePoint = point
    }

    /// Force-release a held drag, clearing all drag state. Returns true if a drag
    /// was actually active (so the caller can inject the matching mouseUp). Used on
    /// teardown / app termination so a held button is never stranded.
    @discardableResult
    public mutating func forceReleaseDrag() -> Bool {
        guard dragActive else { return false }
        dragActive = false
        dragDownPoint = nil
        dragHasMoved = false
        return true
    }

    // MARK: - Helpers

    private mutating func resetDwell(at point: Point) {
        dwellAnchor = point
        dwellElapsed = 0
    }

    private func isPanel(_ zone: Zone) -> Bool {
        switch zone {
        case .panel, .panelCommand: return true
        case .desktop: return false
        }
    }
}
