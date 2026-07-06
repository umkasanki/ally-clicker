import AppKit
import AllyClickerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private var settings = Settings()

    private var panel: PanelViewController!
    private var controller: DwellController!
    private var runner: DwellRunner!

    // Tracks whether DRAG was armed just before the cursor entered the panel
    // (swipe-reset clears it), so dwelling ON/OFF can enter panel-move mode.
    private var lastArmed: DwellEngine.Action? = nil
    private var dragArmedClearedAt: Date? = nil

    private func dragWasRecentlyArmed() -> Bool {
        guard let t = dragArmedClearedAt else { return false }
        return Date().timeIntervalSince(t) < 3.0
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        BackgroundCursor.enable()   // allow cursor changes while never-active
        settings = settingsStore.load()
        // Always show the panel; if access is missing, guide the user to grant it
        // (clicks won't inject until then) instead of hiding the whole UI.
        if !hasAccessibilityPermission() {
            showAccessibilityAlert()
        }

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
            injector: CGMouseInjector()
        )

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

        controller.onCommand = { [weak self] command in
            guard let self else { return }
            switch command {
            case .togglePanel:
                // If DRAG was armed just before entering the panel, move the panel
                // instead of toggling it (hands-free reposition).
                if self.dragWasRecentlyArmed() {
                    self.dragArmedClearedAt = nil
                    self.enterMoveMode()
                } else {
                    self.panel.showCommand(command)
                    self.panel.toggleCollapsed()
                }
            case .launchKeyboard:
                self.panel.showCommand(command)
                KeyboardLauncher.launch(self.settings.commands.keyboard)
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
        NSLog("AllyClicker: panel shown, window frame = \(NSStringFromRect(panel.window.frame))")

        runner = DwellRunner(controller: controller, intervalMs: settings.stillness.trackerIntervalMs)
        runner.start()
        NSLog("AllyClicker: dwell runner started")
    }

    /// Pause dwelling and let the panel follow the cursor until dropped.
    private func enterMoveMode() {
        runner.stop()          // no clicks while repositioning
        panel.setArmed(nil)    // clear any pill
        panel.beginMove()      // resumes via onMoveEnded
    }

    // MARK: - Accessibility permission

    private func hasAccessibilityPermission() -> Bool {
        // prompt:true — on a fresh/unmatched grant, macOS adds THIS signed binary
        // to the Accessibility list and shows the system dialog.
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = """
            AllyClicker needs Accessibility access to move and click the mouse for you.

            Open System Settings → Privacy & Security → Accessibility, enable \
            AllyClicker, then relaunch the app.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
}
