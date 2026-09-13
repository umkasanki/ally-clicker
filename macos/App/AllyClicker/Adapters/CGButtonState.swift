import CoreGraphics
import AllyClickerCore

// CGButtonState — macOS adapter for the ButtonStateReading port.
// Read-only: asks the window server which buttons are down. Injects nothing and
// needs no permission of its own.

struct CGButtonState: ButtonStateReading {

    /// `combinedSessionState` and not `hidSystemState`, deliberately: the button
    /// we care about is usually a synthetic one — ours, or another assistive
    /// application's — and the HID state knows only about real hardware.
    var isLeftPressed: Bool {
        CGEventSource.buttonState(.combinedSessionState, button: .left)
    }
}
