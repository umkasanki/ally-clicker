import AppKit
import AllyClickerCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private var settings: Settings = Settings()

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = settingsStore.load()
        checkAccessibilityPermission()
    }

    // MARK: - Accessibility permission
    //
    // CGEvent.post requires Accessibility access. Without it, click injection
    // silently does nothing. Check on every launch and guide the user if missing.

    private func checkAccessibilityPermission() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let trusted = AXIsProcessTrustedWithOptions([prompt: false] as CFDictionary)
        if !trusted {
            showAccessibilityAlert()
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = """
            AllyClicker needs Accessibility access to inject mouse clicks on your behalf.

            Open System Settings → Privacy & Security → Accessibility \
            and enable AllyClicker.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
}
