import AppKit
import AllyClickerCore

// CursorSampler — macOS adapter for the CursorSampling port.
// Reads the global cursor location and returns it in top-left Point coordinates.
// No special permission needed just to read the location.

struct CursorSampler: CursorSampling {
    var location: Point {
        ScreenGeometry.toTopLeft(NSEvent.mouseLocation)
    }
}
