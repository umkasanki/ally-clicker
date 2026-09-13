import Foundation

// MARK: - Ports
//
// Protocols that decouple the pure core from macOS APIs (ports-and-adapters).
// The core depends only on these abstractions; the macOS app provides concrete
// adapters (CGEvent injection, NSEvent sampling, panel hit-testing).
//
// This is what keeps AllyClickerCore buildable and testable on any platform,
// including Linux/WSL where AppKit and CoreGraphics are unavailable.

/// Injects synthetic mouse actions at the OS level.
/// macOS adapter: wraps CGEvent.post (requires Accessibility permission).
public protocol MouseInjecting {
    func click(_ action: DwellEngine.Action, at point: Point)
    func mouseDown(at point: Point)
    /// Left button held: report a drag to the given point (posts leftMouseDragged).
    /// Needed between mouseDown and mouseUp so apps register a real drag/selection.
    func mouseDragged(at point: Point)
    func mouseUp(at point: Point)
}

/// Reports which mouse buttons the system currently considers held down — by
/// anyone, including another application's synthetic press.
///
/// macOS adapter: `CGEventSource.buttonState(.combinedSessionState, …)`.
///
/// Why this exists: a synthetic `mouseDown` whose matching `mouseUp` never
/// arrives leaves the button held for good, and for a user whose only input is
/// a head tracker that means every movement drags something, with no way to
/// stop it. The engine's own safety nets cover the cases it can see — the armed
/// action changing, a swipe across the panel, teardown. This port covers the one
/// it cannot: the button state disagreeing with what we believe.
public protocol ButtonStateReading {
    /// True while that button is down, whoever put it down.
    func isPressed(_ button: MouseButtonKind) -> Bool
}

public extension ButtonStateReading {
    /// The only button anything holds today. Named because most callers mean
    /// exactly this one, and a future right-button drag should not have to
    /// invent its own check — it asks the same port with a different argument.
    var isLeftPressed: Bool { isPressed(.left) }
}

/// The three buttons a mouse event can carry. Deliberately not
/// `DwellEngine.Action`: an action is something this application performs, and
/// a button is something the world reports.
public enum MouseButtonKind: CaseIterable {
    case left, right, middle
}

/// Whether this application is allowed to inject events at all.
///
/// macOS adapter: `AXIsProcessTrusted()`. Without the Accessibility grant every
/// `CGEvent.post` is accepted and silently does nothing — the application goes
/// on believing it clicked while the user sits in front of a machine that does
/// not respond, with nothing anywhere saying why. The grant can be lost long
/// after launch: a system update, a re-signed build, someone tidying the list.
///
/// `DwellClick` treats this as a fact to re-read rather than a condition at
/// start-up: a timer calls `refreshState` on a schedule, and its click path
/// begins by switching dwell clicking **off** when the grant has gone
/// (`DCClickMachine.performEvent`). Off is a state the user can see; pretending
/// to click is not.
public protocol PermissionReading {
    var canInjectEvents: Bool { get }
}

/// Reports the current global cursor location.
/// macOS adapter: NSEvent.mouseLocation, sampled on a timer.
public protocol CursorSampling {
    var location: Point { get }
}

/// Maps a screen point to the zone the cursor is in (desktop / panel button / command).
/// macOS adapter: hit-tests the panel's button frames.
///
/// CONTRACT: the set of buttons the adapter may report is defined by
/// `Settings.panel.items` — the mapper must hit-test exactly those buttons (in that
/// order) and must NEVER emit a `.panel(button:)` or `.panelCommand` for an item not
/// in the list. The engine arms/fires whatever zone it receives, so a button removed
/// from `panel.items` is only truly gone if the mapper stops reporting it.
public protocol ZoneMapping {
    func zone(at point: Point) -> DwellEngine.Zone
}
