import AppKit
import AllyClickerCore

// Launches the KEYBOARD target chosen in settings.
//   • accessibilityKeyboard — toggle the macOS Accessibility Keyboard (show/hide)
//   • keyboardViewer        — macOS Keyboard Viewer
//   • customApp(path:)       — any third-party app by path/bundle id

enum KeyboardLauncher {
    // The Accessibility Keyboard is served by "Assistive Control.app". It runs
    // only when the feature is enabled in Accessibility settings, and its
    // visibility is driven by this universalaccess pref (verified on-device).
    private static let assistiveBundleID = "com.apple.inputmethod.AssistiveControl"
    private static let uaDomain = "com.apple.universalaccess" as CFString
    private static let vkKey = "virtualKeyboardOnOff" as CFString

    static func launch(_ target: Settings.KeyboardTarget) {
        switch target {
        case .accessibilityKeyboard: toggleAccessibilityKeyboard()
        case .keyboardViewer:        openKeyboardViewer()
        case .customApp(let path):   launchCustom(path: path)
        }
    }

    // MARK: - Accessibility Keyboard (default)

    private static func toggleAccessibilityKeyboard() {
        guard isAssistiveControlRunning() else {
            // Feature not enabled → toggling the pref would do nothing. Guide the user.
            promptToEnableAccessibilityKeyboard()
            return
        }
        let shown = CFPreferencesCopyValue(vkKey, uaDomain,
                                           kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Bool ?? false
        let next = (shown ? kCFBooleanFalse : kCFBooleanTrue)
        CFPreferencesSetValue(vkKey, next, uaDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(uaDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    private static func isAssistiveControlRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: assistiveBundleID).isEmpty
    }

    private static func promptToEnableAccessibilityKeyboard() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Keyboard is off"
        alert.informativeText = """
            Turn it on in System Settings → Accessibility → Keyboard → \
            Accessibility Keyboard. After that, this button shows and hides it.
            """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Keyboard")!
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Other targets

    private static func openKeyboardViewer() {
        let url = URL(fileURLWithPath: "/System/Library/Input Methods/KeyboardViewer.app")
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    private static func launchCustom(path: String) {
        guard !path.isEmpty else { return }
        if path.hasPrefix("/") {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: .init())
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: path) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
        }
    }
}
