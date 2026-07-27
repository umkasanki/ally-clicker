import AppKit
import AllyClickerCore

// Visual click feedback: a brief expanding, fading ring at the cursor when an
// action fires — the on-screen echo of a click (complements the sound). Inspired
// by DwellClick's halo, drawn live with Core Animation in a click-through overlay.
final class ClickFeedback {
    var enabled: Bool = true

    private let window: NSPanel
    private let size: CGFloat = 56          // overlay box; ring expands within it

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

        let host = NSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        host.wantsLayer = true
        window.contentView = host
    }

    /// Flash a ripple centered on a top-left Point (where the action fired).
    func flash(at point: Point) {
        guard enabled, let host = window.contentView?.layer else { return }
        let bl = ScreenGeometry.toBottomLeft(point)
        window.setFrameOrigin(NSPoint(x: bl.x - size / 2, y: bl.y - size / 2))
        window.orderFrontRegardless()

        let d = size * 0.8
        let ring = CAShapeLayer()
        ring.frame = NSRect(x: 0, y: 0, width: size, height: size)
        ring.path = CGPath(ellipseIn: NSRect(x: (size - d) / 2, y: (size - d) / 2, width: d, height: d), transform: nil)
        ring.fillColor = NSColor.systemRed.withAlphaComponent(0.18).cgColor
        ring.strokeColor = NSColor.systemRed.withAlphaComponent(0.9).cgColor
        ring.lineWidth = 3
        host.addSublayer(ring)

        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.25
        grow.toValue = 1.0
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        let group = CAAnimationGroup()
        group.animations = [grow, fade]
        group.duration = 0.4
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ring.opacity = 0   // resting state after the animation

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            ring.removeFromSuperlayer()
            if host.sublayers?.isEmpty ?? true { self?.window.orderOut(nil) }
        }
        ring.add(group, forKey: "ripple")
        CATransaction.commit()
    }
}
