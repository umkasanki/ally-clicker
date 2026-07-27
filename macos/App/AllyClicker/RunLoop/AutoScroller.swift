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

    // Exit = same gesture as a normal dwell-click: you scroll by MOVING the cursor
    // ("водишь курсором"); when you stop moving (frame-to-frame stillness within
    // stillRadius) for the dwell time, a left click fires and scroll ends.
    private var lastCursor: Point = .zero
    private var stillElapsed: TimeInterval = 0
    private var hasScrolled = false   // arm exit only after actually scrolling once

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

        // Stillness = stopped moving the cursor (same threshold as dwell-click).
        if cursor.distance(to: lastCursor) <= stillRadius {
            stillElapsed += tick
        } else {
            stillElapsed = 0
        }
        lastCursor = cursor

        // Stopped after scrolling → left click here + exit (like a normal dwell).
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
