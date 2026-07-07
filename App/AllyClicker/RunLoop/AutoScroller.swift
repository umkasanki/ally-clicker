import AppKit
import AllyClickerCore

// Drives auto-scroll mode: after MIDDLE fires, the cursor's offset from the anchor
// produces scroll events (farther = faster). Wraps the pure AutoScrollController
// with a 60fps timer, cursor sampling, scroll injection, and an anchor dot.

final class AutoScroller {
    private let controller: AutoScrollController
    private let injector: CGMouseInjector
    private let anchor = AnchorIndicator()
    private var timer: DispatchSourceTimer?

    private let stillRadius: Double
    private let dwellSeconds: TimeInterval
    private let tick = 0.016

    // Dwell-to-exit tracking: keep scrolling while the cursor moves (zigzag), but
    // when it holds still for the dwell time, fire a left click and exit.
    private var lastCursor: Point = .zero
    private var stillElapsed: TimeInterval = 0
    private var hasScrolled = false   // arm exit only after leaving the dead zone

    /// Return true to exit auto-scroll (e.g. cursor entered the panel).
    var shouldExit: ((Point) -> Bool)?
    /// Called when auto-scroll ends, so the app can resume dwelling.
    var onExit: (() -> Void)?

    var isActive: Bool { timer != nil }

    init(config: Settings.AutoScroll, stillRadius: Double, dwellSeconds: TimeInterval,
         injector: CGMouseInjector) {
        self.controller = AutoScrollController(config: config)
        self.stillRadius = stillRadius
        self.dwellSeconds = dwellSeconds
        self.injector = injector
    }

    func start(at point: Point) {
        guard timer == nil else { return }   // idempotent
        controller.activate(at: point)
        anchor.show(at: point)
        lastCursor = point
        stillElapsed = 0
        hasScrolled = false

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(16))  // ~60fps
        t.setEventHandler { [weak self] in self?.step() }
        t.resume()
        timer = t
    }

    private func step() {
        let cursor = ScreenGeometry.toTopLeft(NSEvent.mouseLocation)
        if shouldExit?(cursor) == true { stop(); return }

        // Physical stillness (independent of scroll offset): moving resets it.
        if cursor.distance(to: lastCursor) <= stillRadius {
            stillElapsed += tick
        } else {
            stillElapsed = 0
        }
        lastCursor = cursor

        // Holding still after having scrolled → left click at that point + exit.
        if hasScrolled, stillElapsed >= dwellSeconds {
            injector.click(.left, at: cursor)
            stop()
            return
        }

        if let d = controller.tick(cursor: cursor), d.dx != 0 || d.dy != 0 {
            hasScrolled = true
            injector.scroll(dx: d.dx, dy: d.dy)
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        controller.deactivate()
        anchor.hide()
        onExit?()
    }
}
