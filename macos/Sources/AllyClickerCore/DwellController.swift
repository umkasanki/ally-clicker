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
    /// `nil` when the app has no way to ask the system — then we believe our own
    /// state, which is what this class did before the port existed.
    private let buttons: ButtonStateReading?
    /// `nil` when the app cannot ask — then injection is assumed to work, which
    /// is what this class did before the port existed.
    private let permission: PermissionReading?

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

    /// Called right after an action is injected — a click, and BOTH the mouse-down
    /// that starts a drag and the mouse-up that ends it — with the fire point, for
    /// audio/visual feedback. Not called for intercepted actions handled by `willFire`.
    public var onFired: ((DwellEngine.Action, Point) -> Void)?

    public init(settings: Settings,
                sampler: CursorSampling,
                mapper: ZoneMapping,
                injector: MouseInjecting,
                buttons: ButtonStateReading? = nil,
                permission: PermissionReading? = nil) {
        self.engine = DwellEngine(settings: settings)
        self.sampler = sampler
        self.mapper = mapper
        self.injector = injector
        self.buttons = buttons
        self.permission = permission
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

    /// Hand control back after a takeover mode (auto-scroll, panel move): re-arm the
    /// default action so Left resumes being the resting state, and tell the UI.
    public func armDefaultIfEnabled() {
        if let action = engine.armDefaultIfEnabled() {
            onUIEffect?(.setArmed(action))
        }
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

    /// Called when a drag we believed was in progress turns out not to be —
    /// the button is no longer down and we did not release it. The app uses it
    /// to put the UI back; there is nothing to inject, because nothing is held.
    public var onDragLost: (() -> Void)?

    /// Called when the right to inject events is found to be missing, with the
    /// armed action that was given up. The app shows it; there is nothing to
    /// inject, because injection is exactly what is not available.
    public var onInjectionRefused: (() -> Void)?

    /// Advance one tick. The app calls this from a timer every trackerIntervalMs.
    public func advance(dt: TimeInterval) {
        // Are we allowed to act at all? Without the grant every event we post is
        // accepted and does nothing, and dwelling on a button would arm an
        // action that can never fire — the user waiting for a click that the
        // application believes it made. Giving up the armed action says so in
        // the only language the panel has.
        if let permission, !permission.canInjectEvents {
            if engine.armed != nil {
                engine.clearArmed()
                onUIEffect?(.setArmed(nil))
                onInjectionRefused?()
            }
            return
        }

        // Before anything else: does the world still agree that we are dragging?
        //
        // Everything downstream of a held button assumes it is really held. If
        // our `mouseUp` was swallowed — the target application died under it, a
        // modal panel took the events, the system dropped it — we would go on
        // streaming drag events at a button nobody is pressing, and the armed
        // action would never come back. Cheap to ask, and it is the only check
        // here that can contradict us.
        if engine.dragActive, let buttons, !buttons.isLeftPressed {
            engine.forceReleaseDrag()
            onDragLost?()
        }

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
            onFired?(action, point)
        case .dragMouseDown(let point):
            injector.mouseDown(at: point)
            onFired?(.leftDrag, point)   // feedback at the start of a drag, not only the end
        case .dragMouseMoved(let point):
            injector.mouseDragged(at: point)
        case .dragMouseUp(let point):
            injector.mouseUp(at: point)
            onFired?(.leftDrag, point)
        case .runCommand(let command):
            onCommand?(command)
        case .setArmed, .dwellProgress, .clearProgress:
            onUIEffect?(effect)
        }
    }
}
