import AppKit
import AllyClickerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private var settings = Settings()

    private var panel: PanelViewController!
    private var controller: DwellController!
    private var runner: DwellRunner!

    func applicationDidFinishLaunching(_ notification: Notification) {
        BackgroundCursor.enable()   // allow cursor changes while never-active
        settings = settingsStore.load()
        let granted = hasAccessibilityPermission()
        NSLog("AllyClicker: launch, accessibility granted = \(granted)")
        if !granted {
            // DEBUG: don't gate the UI — show the panel anyway so we can verify
            // rendering/coordinates. Clicks simply won't inject until access is granted.
            NSLog("AllyClicker: WARNING no accessibility — panel shown for UI test, clicks disabled")
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
            if case .setArmed(let action) = effect {
                self?.panel.setArmed(action)
            }
            // dwellProgress / clearProgress intentionally ignored (spec §2).
        }

        controller.onCommand = { [weak self] command in
            guard let self else { return }
            self.panel.showCommand(command)   // slide the pill under the command button
            switch command {
            case .togglePanel:    self.panel.toggleCollapsed()
            case .launchKeyboard: KeyboardLauncher.launch(self.settings.commands.keyboard)
            }
        }

        panel.setArmed(controller.armed)
        panel.show()
        NSLog("AllyClicker: panel shown, window frame = \(NSStringFromRect(panel.window.frame))")

        runner = DwellRunner(controller: controller, intervalMs: settings.stillness.trackerIntervalMs)
        runner.start()
        NSLog("AllyClicker: dwell runner started")
    }

    // MARK: - Accessibility permission

    private func hasAccessibilityPermission() -> Bool {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([prompt: false] as CFDictionary)
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
