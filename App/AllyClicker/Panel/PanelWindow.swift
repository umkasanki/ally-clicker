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
        level = .floating                 // above normal windows
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        // Force native dark appearance — semantic colors (windowBackgroundColor,
        // labelColor…) then resolve to their dark variants automatically.
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = .windowBackgroundColor
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // Never become key/main — it must not take focus.
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
