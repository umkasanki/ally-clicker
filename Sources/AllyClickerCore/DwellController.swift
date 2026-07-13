import Foundation

// MARK: - DwellController
//
// Pure orchestrator that wires the DwellEngine to the port protocols. It owns no
// macOS APIs — only the abstractions — so it is fully unit-testable with mock ports.
//
// Each tick it samples the cursor, classifies the zone, advances the engine, and
// routes the resulting effects:
//   • action effects (fire / drag mouseDown / mouseUp) → the MouseInjecting port
//   • command effects (ON/OFF, KEYBOARD) → onCommand
//   • UI effects (setArmed / dwellProgress / clearProgress) → onUIEffect
//
// Note: the engine only emits `.fire` in the .desktop zone, so the fire point is
// always outside the panel by construction — no "last position outside panel"
// bookkeeping is needed.
//
// THREADING: not thread-safe. Drive `advance(dt:)` from a single thread (the app's
// cursor-sampling timer, normally the main thread). `onUIEffect` is invoked
// synchronously inside `advance`, so it runs on that same thread.

public final class DwellController {
    private var engine: DwellEngine
    private let sampler: CursorSampling
    private let mapper: ZoneMapping
    private let injector: MouseInjecting

    /// Called for UI-facing effects the app must render (armed highlight, countdown).
    public var onUIEffect: ((DwellEngine.Effect) -> Void)?

    /// Called when a one-shot panel command fires (ON/OFF → togglePanel,
    /// KEYBOARD → launchKeyboard). The app performs the actual side effect.
    public var onCommand: ((DwellEngine.Command) -> Void)?

    /// Called every tick with the current cursor zone (for cursor policy, etc.).
    public var onZone: ((DwellEngine.Zone) -> Void)?

    /// Intercepts a fired action before injection. Return true if the app handled
    /// it (e.g. MIDDLE → enter auto-scroll) so no click is injected.
    public var willFire: ((DwellEngine.Action, Point) -> Bool)?

    /// Called right after an action is injected (click, or the mouse-up that
    /// completes a drag) — for audio/haptic feedback. Not called for intercepted
    /// actions handled by `willFire`.
    public var onFired: ((DwellEngine.Action) -> Void)?

    public init(settings: Settings,
                sampler: CursorSampling,
                mapper: ZoneMapping,
                injector: MouseInjecting) {
        self.engine = DwellEngine(settings: settings)
        self.sampler = sampler
        self.mapper = mapper
        self.injector = injector
    }

    /// Currently armed action (for the app to query, e.g. on launch).
    public var armed: DwellEngine.Action? { engine.armed }

    /// Apply updated settings live (e.g. user changed a delay or sensitivity).
    public func updateSettings(_ settings: Settings) {
        engine.settings = settings
    }

    /// Clear the armed action and notify the UI (used when the app takes over,
    /// e.g. entering panel-move mode).
    public func clearArmed() {
        engine.clearArmed()
        onUIEffect?(.setArmed(nil))
    }

    /// Release any button held by an in-progress drag. The app MUST call this on
    /// termination / resign-active so a synthetic button is never left stuck down.
    /// Also invoked automatically on deinit.
    public func releaseHeldButton() {
        if engine.forceReleaseDrag() {
            injector.mouseUp(at: sampler.location)
        }
    }

    deinit {
        releaseHeldButton()
    }

    /// Advance one tick. The app calls this from a timer every trackerIntervalMs.
    public func advance(dt: TimeInterval) {
        let cursor = sampler.location
        let zone = mapper.zone(at: cursor)
        onZone?(zone)
        for effect in engine.tick(cursor: cursor, zone: zone, dt: dt) {
            // If the app takes over a fire (e.g. MIDDLE → auto-scroll), stop
            // processing the rest of this tick's effects — the trailing
            // post-action revert (.setArmed) would otherwise contradict the
            // app's takeover (e.g. clearArmed) and leave a lying pill.
            if case .fire(let action, let point) = effect, willFire?(action, point) == true {
                return
            }
            dispatch(effect)
        }
    }

    private func dispatch(_ effect: DwellEngine.Effect) {
        switch effect {
        case .fire(let action, let point):
            injector.click(action, at: point)
            onFired?(action)
        case .dragMouseDown(let point):
            injector.mouseDown(at: point)
        case .dragMouseMoved(let point):
            injector.mouseDragged(at: point)
        case .dragMouseUp(let point):
            injector.mouseUp(at: point)
            onFired?(.leftDrag)
        case .runCommand(let command):
            onCommand?(command)
        case .setArmed, .dwellProgress, .clearProgress:
            onUIEffect?(effect)
        }
    }
}
