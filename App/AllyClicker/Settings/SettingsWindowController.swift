import AppKit
import SwiftUI
import AllyClickerCore

// Hosts the SwiftUI settings form in a normal (activating) window — unlike the
// panel, this window takes focus so the user can operate the controls.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    /// Open (or focus) the settings window for the given settings.
    /// `onApply` receives the edited settings to persist + apply live.
    func show(settings: AllyClickerCore.Settings, onApply: @escaping (AllyClickerCore.Settings) -> Void) {
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
        win.appearance = NSAppearance(named: .darkAqua)   // match the panel's dark look
        win.delegate = self                               // red-X close ⇒ reset like Cancel
        // Remember the window's position across opens; center only on first ever run.
        win.setFrameAutosaveName("AllyClickerSettingsWindow")
        if !win.setFrameUsingName("AllyClickerSettingsWindow") { win.center() }
        window = win

        NSApp.activate(ignoringOtherApps: true)   // .accessory app must come forward
        win.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.close()
        window = nil
    }

    // Closing with the title-bar button discards edits (like Cancel) and lets the
    // next open rebuild a fresh model from current settings — no stale copy.
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
