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

    /// Where the cursor is right now.
    public enum Zone: Equatable {
        case desktop
        case panel(button: Action?)   // nil = panel chrome, not a button
        case exitButton
    }

    /// What the app should do this tick.
    public enum Effect: Equatable {
        case setArmed(Action?)
        case dwellProgress(button: Action, fraction: Double)
        case clearProgress
        case fire(Action, at: Point)
        case requestExit
    }

    // MARK: - State

    public var settings: Settings

    public private(set) var armed: Action? = nil
    private var dwellAnchor: Point? = nil
    private var dwellElapsed: TimeInterval = 0
    private var lastZone: Zone = .desktop

    public init(settings: Settings) { self.settings = settings }

    // MARK: - Tick

    /// Advance the engine by `dt` seconds. Call every `settings.stillness.trackerIntervalMs`.
    public mutating func tick(cursor: Point, zone: Zone, dt: TimeInterval) -> [Effect] {
        var effects: [Effect] = []

        // SWIPE-RESET: entering the panel from desktop clears the armed action instantly.
        // Brushing the panel cancels with zero precision and zero waiting — the key UX insight.
        if isPanel(zone) && !isPanel(lastZone) {
            if armed != nil {
                armed = nil
                effects.append(.setArmed(nil))
            }
            resetDwell(at: cursor)
        }
        lastZone = zone

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
        case .exitButton:
            let progress = dwellElapsed / settings.timing.dwellTimeExitSeconds
            if progress >= 1 {
                effects.append(.requestExit)
                resetDwell(at: cursor)
            }

        case .panel(button: let button?):
            let fraction = min(dwellElapsed / settings.timing.dwellTimeSeconds, 1)
            effects.append(.dwellProgress(button: button, fraction: fraction))
            if fraction >= 1 {
                armed = button
                effects.append(.setArmed(button))
                resetDwell(at: cursor)
            }

        case .panel(button: nil):
            effects.append(.clearProgress)

        case .desktop:
            // Auto-click fires only when something is armed.
            // After a swipe (armed == nil) the cursor can rest forever — nothing fires.
            guard let action = armed else {
                effects.append(.clearProgress)
                break
            }
            if dwellElapsed >= settings.timing.dwellTimeMouseSeconds {
                effects.append(.fire(action, at: cursor))
                resetDwell(at: cursor)
                // POST-CLICK REVERT (three paths — see spec §5):
                //   defaultLeft = true                       → revert to .left
                //   defaultLeft = false, autoCancel = true   → clear to nil (one-shot)
                //   defaultLeft = false, autoCancel = false  → keep action (repeat forever)
                // The swipe path always clears to nil — that is a separate path.
                let next: Action?
                if settings.clicks.defaultLeft {
                    next = .left
                } else if settings.clicks.autoCancel {
                    next = nil
                } else {
                    next = action  // repeat: stay armed with the same action
                }
                if armed != next {
                    armed = next
                    effects.append(.setArmed(next))
                }
            }
        }

        return effects
    }

    // MARK: - Helpers

    private mutating func resetDwell(at point: Point) {
        dwellAnchor = point
        dwellElapsed = 0
    }

    private func isPanel(_ zone: Zone) -> Bool {
        switch zone {
        case .panel, .exitButton: return true
        case .desktop: return false
        }
    }
}
