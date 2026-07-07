import AppKit
import SwiftUI
import AllyClickerCore

// Hosts the SwiftUI settings form in a normal (activating) window — unlike the
// panel, this window takes focus so the user can operate the controls.
final class SettingsWindowController {
    private var window: NSWindow?

    /// Open (or focus) the settings window for the given settings.
    /// `onApply` receives the edited settings to persist + apply live.
    func show(settings: Settings, onApply: @escaping (Settings) -> Void) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let model = SettingsModel(settings: settings, onApply: onApply,
                                  onClose: { [weak self] in self?.close() })
        let hosting = NSHostingController(rootView: SettingsView(model: model))

        let win = NSWindow(contentViewController: hosting)
        win.title = "AllyClicker Settings"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.center()
        window = win

        NSApp.activate(ignoringOtherApps: true)   // .accessory app must come forward
        win.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.close()
        window = nil
    }
}
