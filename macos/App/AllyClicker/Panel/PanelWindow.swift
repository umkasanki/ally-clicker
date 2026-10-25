import AppKit

// Borderless, always-on-top, non-activating panel window.
// .nonactivatingPanel → dwelling on it never steals focus from the app underneath.

final class PanelWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        // Above every other window, AllyKeyboard included. The keyboard sits at
        // assistiveTechHighWindow (1500) and its settings at 1501; at .statusBar
        // (24) this panel ended up under the keyboard whenever the two overlapped,
        // and with the mouse buttons covered there was no way to move the
        // keyboard off it again. The control surface must never be covered.
        // Immunity to "click wallpaper to reveal desktop" / Show Desktop comes
        // from .stationary below, not from the level.
        level = PanelWindow.controlLevel
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        // Force native dark appearance — semantic colors (windowBackgroundColor,
        // labelColor…) then resolve to their dark variants automatically.
        appearance = NSAppearance(named: .darkAqua)
        // Transparent window: the rounded container draws the visible background.
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // Never become key/main — it must not take focus.
        isReleasedWhenClosed = false
    }

    /// The panel's window level: two above AllyKeyboard's keyboard (1500) and one
    /// above its settings window (1501).
    static let controlLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)) + 2)

    /// For transient overlays drawn on top of the panel (click flash, anchor).
    static let overlayLevel = NSWindow.Level(rawValue: controlLevel.rawValue + 1)

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
