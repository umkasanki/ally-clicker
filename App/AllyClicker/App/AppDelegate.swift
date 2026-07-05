import AppKit
import AllyClickerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private var settings = Settings()

    private var panel: PanelViewController!
    private var controller: DwellController!
    private var runner: DwellRunner!

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = settingsStore.load()

        guard hasAccessibilityPermission() else {
            showAccessibilityAlert()
            return  // без разрешения инъекция не работает — ждём перезапуска после выдачи
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
            switch command {
            case .togglePanel:    self.panel.toggleCollapsed()
            case .launchKeyboard: KeyboardLauncher.launch(self.settings.commands.keyboard)
            }
        }

        panel.setArmed(controller.armed)
        panel.show()

        runner = DwellRunner(controller: controller, intervalMs: settings.stillness.trackerIntervalMs)
        runner.start()
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
