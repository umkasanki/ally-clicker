import AppKit
import AllyClickerCore

// Single source of truth for the cursor shape, driven from the dwell tick
// (AppDelegate.updateCursor) and the panel move loop — instead of per-button
// tracking areas that fought each other.

enum CursorPolicy {
    /// Cursor shown while dragging the panel. `.closedHand` reads as grab/move
    /// and is public (no private API).
    static let moving: NSCursor = .closedHand

    /// Cursor for the given zone.
    /// - dragIntent: DRAG was armed just before entering the panel, so hovering the
    ///   ON/OFF button previews that dwelling there will MOVE the panel.
    /// - Returns nil over the desktop — leave the cursor to whatever app is there.
    static func cursor(zone: DwellEngine.Zone, dragIntent: Bool) -> NSCursor? {
        if dragIntent, case .panelCommand(.togglePanel) = zone {
            return moving
        }
        switch zone {
        case .panel, .panelCommand: return .pointingHand
        case .desktop:              return nil
        }
    }
}
