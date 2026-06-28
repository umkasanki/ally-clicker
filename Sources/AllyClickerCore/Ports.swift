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
    func mouseUp(at point: Point)
}

/// Reports the current global cursor location.
/// macOS adapter: NSEvent.mouseLocation, sampled on a timer.
public protocol CursorSampling {
    var location: Point { get }
}

/// Maps a screen point to the zone the cursor is in (desktop / panel button / exit).
/// macOS adapter: hit-tests the panel's button frames.
public protocol ZoneMapping {
    func zone(at point: Point) -> DwellEngine.Zone
}
