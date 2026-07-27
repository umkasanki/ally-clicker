import AppKit
import AllyClickerCore

// Small floating dot marking the auto-scroll anchor, so the user sees the neutral
// point (cursor near it = no scroll; farther = faster). Non-activating, click-through.

final class AnchorIndicator {
    private let window: NSPanel
    private let size: CGFloat = 22

    init() {
        window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        window.level = .statusBar
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let dot = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = size / 2
        dot.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.85).cgColor
        dot.layer?.borderColor = NSColor.white.cgColor
        dot.layer?.borderWidth = 2
        window.contentView = dot
    }

    /// Show centered on a top-left Point.
    func show(at point: Point) {
        let bl = ScreenGeometry.toBottomLeft(point)
        window.setFrameOrigin(NSPoint(x: bl.x - size / 2, y: bl.y - size / 2))
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }
}
