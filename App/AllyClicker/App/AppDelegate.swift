import AppKit
import AllyClickerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private var settings = Settings()

    private var panel: PanelViewController!
    private var controller: DwellController!
    private var runner: DwellRunner!
    private let injector = CGMouseInjector()
    private var autoScroller: AutoScroller!

    // Tracks the armed action (and when a DRAG arm was cleared by a swipe), so
    // dwelling ON/OFF with DRAG intent enters panel-move mode instead of toggling.
    private var lastArmed: DwellEngine.Action? = nil
    private var dragArmedClearedAt: Date? = nil

    /// Intent to move the panel: DRAG is armed right now (user moved within the
    /// panel from the DRAG button to ON/OFF, armed never cleared), OR it was just
    /// cleared by a swipe on the way in (overshoot to desktop and back).
    private func dragIntended() -> Bool {
        if lastArmed == .leftDrag { return true }
        if let t = dragArmedClearedAt { return Date().timeIntervalSince(t) < 3.0 }
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        BackgroundCursor.enable()   // allow cursor changes while never-active
        settings = settingsStore.load()
        // Request Accessibility if missing: the system adds AllyClicker to the list
        // and shows its own "Open System Settings" dialog. The panel still appears;
        // clicks just won't inject until access is granted.
        requestAccessibilityIfNeeded()
        startDwelling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Never leave a synthetic button stuck down.
        controller?.releaseHeldButton()
        runner?.stop()
    }

    // MARK: - Wiring

    private func startDwelling() {
        panel = PanelViewController(settings: settings)

        controller = DwellController(
            settings: settings,
            sampler: CursorSampler(),
            mapper: panel,
            injector: injector
        )

        autoScroller = AutoScroller(config: settings.autoScroll, injector: injector)
        autoScroller.shouldExit = { [weak self] cursor in
            // Brush the panel to stop scrolling (same muscle memory as swipe-reset).
            guard let self else { return true }
            if case .desktop = self.panel.zone(at: cursor) { return false }
            return true
        }
        autoScroller.onExit = { [weak self] in self?.runner.start() }

        controller.willFire = { [weak self] action, point in
            guard let self, action == .middle else { return false }
            self.enterAutoScroll(at: point)
            return true   // handled — no middle click injected
        }

        controller.onUIEffect = { [weak self] effect in
            guard let self else { return }
            if case .setArmed(let action) = effect {
                // DRAG armed → cleared (cursor entered panel) = intent to move.
                if action == nil, self.lastArmed == .leftDrag {
                    self.dragArmedClearedAt = Date()
                }
                self.lastArmed = action
                self.panel.setArmed(action)
            }
            // dwellProgress / clearProgress intentionally ignored (spec §2).
        }

        controller.onZone = { [weak self] zone in self?.updateCursor(zone: zone) }

        controller.onCommand = { [weak self] command in
            guard let self else { return }
            switch command {
            case .togglePanel:
                // If DRAG is the current intent, move the panel instead of toggling.
                if self.dragIntended() {
                    self.dragArmedClearedAt = nil
                    self.enterMoveMode()
                } else {
                    self.panel.showCommand(command)
                    self.panel.toggleCollapsed()
                }
            case .launchKeyboard:
                // Deferred: KEYBOARD action is on hold. Button stays on the panel
                // but does nothing for now (KeyboardLauncher kept for later).
                self.panel.showCommand(command)
            }
        }

        panel.armedProvider = { [weak controller] in controller?.armed }
        panel.onPositionChanged = { [weak self] x, y in
            guard let self else { return }
            self.settings.panel.positionX = x
            self.settings.panel.positionY = y
            self.settingsStore.save(self.settings)
        }
        panel.onMoveEnded = { [weak self] in self?.runner.start() }
        panel.setArmed(controller.armed)
        panel.show()

        runner = DwellRunner(controller: controller, intervalMs: settings.stillness.trackerIntervalMs)
        runner.start()
    }

    // MARK: - Cursor

    private var appliedPanelCursor = false

    private func updateCursor(zone: DwellEngine.Zone) {
        if panel.isMoving { return }   // the move loop owns the cursor
        if let c = CursorPolicy.cursor(zone: zone, dragIntent: dragIntended()) {
            c.set()
            appliedPanelCursor = true
        } else if appliedPanelCursor {
            // Reset once when leaving the panel to the desktop (don't clobber other
            // apps' cursors every tick).
            NSCursor.arrow.set()
            appliedPanelCursor = false
        }
    }

    /// Pause dwelling and enter auto-scroll from the given anchor point.
    private func enterAutoScroll(at point: Point) {
        runner.stop()             // no dwell clicks while scrolling
        controller.clearArmed()   // MIDDLE consumed
        lastArmed = nil
        autoScroller.start(at: point)   // resumes runner via onExit
    }

    /// Pause dwelling and let the panel follow the cursor until dropped.
    private func enterMoveMode() {
        runner.stop()             // no clicks while repositioning
        controller.clearArmed()  // clear engine armed (also clears pill via onUIEffect)
        lastArmed = nil
        dragArmedClearedAt = nil
        panel.beginMove()         // resumes via onMoveEnded
    }

    // MARK: - Accessibility permission

    /// prompt:true — if not yet trusted, macOS adds this signed binary to the
    /// Accessibility list and shows its own "Open System Settings" dialog.
    @discardableResult
    private func requestAccessibilityIfNeeded() -> Bool {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }
}
