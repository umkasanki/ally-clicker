import CoreGraphics
import AllyClickerCore

// CGButtonState — macOS adapter for the ButtonStateReading port.
// Read-only: asks the window server which buttons are down. Injects nothing and
// needs no permission of its own.

struct CGButtonState: ButtonStateReading {

    /// `combinedSessionState` and not `hidSystemState`, deliberately: the button
    /// we care about is usually a synthetic one — ours, or another assistive
    /// application's — and the HID state knows only about real hardware.
    func isPressed(_ button: MouseButtonKind) -> Bool {
        CGEventSource.buttonState(.combinedSessionState, button: button.cgButton)
    }
}

private extension MouseButtonKind {
    var cgButton: CGMouseButton {
        switch self {
        case .left:   return .left
        case .right:  return .right
        case .middle: return .center
        }
    }
}
