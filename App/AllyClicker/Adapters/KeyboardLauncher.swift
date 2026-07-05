import AppKit
import AllyClickerCore

// Launches the KEYBOARD target chosen in settings. Three modes:
//   • accessibilityKeyboard — macOS built-in Accessibility Keyboard
//   • keyboardViewer        — macOS Keyboard Viewer
//   • customApp(path:)       — any third-party app by path/bundle id

enum KeyboardLauncher {
    static func launch(_ target: Settings.KeyboardTarget) {
        switch target {
        case .accessibilityKeyboard:
            // The Accessibility Keyboard is toggled via the system; the most reliable
            // scriptable entry point is the Keyboard Viewer input source. As a first
            // cut we open the Accessibility Keyboard settings pane if direct toggle
            // isn't available. TODO: verify the exact toggle on-device (may need an
            // AppleScript to System Events or the "com.apple.KeyboardViewer" input source).
            openInputSourceKeyboard()
        case .keyboardViewer:
            openInputSourceKeyboard()
        case .customApp(let path):
            launchCustom(path: path)
        }
    }

    private static func openInputSourceKeyboard() {
        // Keyboard Viewer lives in the input-menu; this launches the viewer app.
        let url = URL(fileURLWithPath: "/System/Library/Input Methods/KeyboardViewer.app")
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config)
    }

    private static func launchCustom(path: String) {
        guard !path.isEmpty else { return }
        let url: URL
        if path.hasPrefix("/") {
            url = URL(fileURLWithPath: path)
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        } else {
            // Treat as a bundle identifier.
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: path) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
            }
        }
    }
}
