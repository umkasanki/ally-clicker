import AppKit

// Borderless, always-on-top, non-activating panel window.
// .nonactivatingPanel → dwelling on it never steals focus from the app underneath.

final class PanelWindow: NSPanel {
    /// How the app's panels take part in screen capture. `.none` leaves them out
    /// of every screenshot and recording — ⌘⇧3/4/5, QuickTime, screen sharing —
    /// while they stay on screen. Set from Settings; every panel takes it when
    /// made (the anchor dot and the click ripple too). The Settings window is an
    /// NSWindow, not a panel, and is never hidden.
    static private(set) var captureSharing: NSWindow.SharingType = .none

    /// Apply the setting to the panels open now and to those made later.
    static func setHiddenFromCapture(_ hidden: Bool) {
        captureSharing = hidden ? .none : .readOnly
        for window in NSApp.windows where window is NSPanel {
            window.sharingType = captureSharing
        }
    }

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
        sharingType = PanelWindow.captureSharing
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
