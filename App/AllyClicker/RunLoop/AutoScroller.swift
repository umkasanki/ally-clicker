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

    /// Return true to exit auto-scroll (e.g. cursor entered the panel).
    var shouldExit: ((Point) -> Bool)?
    /// Called when auto-scroll ends, so the app can resume dwelling.
    var onExit: (() -> Void)?

    var isActive: Bool { timer != nil }

    init(config: Settings.AutoScroll, injector: CGMouseInjector) {
        self.controller = AutoScrollController(config: config)
        self.injector = injector
    }

    func start(at point: Point) {
        controller.activate(at: point)
        anchor.show(at: point)

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(16))  // ~60fps
        t.setEventHandler { [weak self] in self?.step() }
        t.resume()
        timer = t
    }

    private func step() {
        let cursor = ScreenGeometry.toTopLeft(NSEvent.mouseLocation)
        if shouldExit?(cursor) == true { stop(); return }
        if let d = controller.tick(cursor: cursor), d.dx != 0 || d.dy != 0 {
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
