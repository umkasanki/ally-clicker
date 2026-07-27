import AppKit
import SwiftUI
import AllyClickerCore

// Hosts the SwiftUI settings form in a normal (activating) window — unlike the
// panel, this window takes focus so the user can operate the controls.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var model: SettingsModel?
    private let frameKey = "AllyClickerSettingsFrame"

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
        self.model = model
        let hosting = NSHostingController(rootView: SettingsView(model: model))

        let win = NSWindow(contentViewController: hosting)
        win.title = "AllyClicker Settings"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.appearance = NSAppearance(named: .darkAqua)   // match the panel's dark look
        win.delegate = self                               // red-X close ⇒ flush pending auto-save
        // Restore the exact saved frame (both axes); center only on first ever run.
        if let saved = UserDefaults.standard.string(forKey: frameKey) {
            win.setFrame(NSRectFromString(saved), display: false)
        } else {
            win.center()
        }
        window = win

        NSApp.activate(ignoringOtherApps: true)   // .accessory app must come forward
        win.makeKeyAndOrderFront(nil)
    }

    private func close() {
        window?.close()
        window = nil
        model = nil
    }

    // Closing with the title-bar button: flush any pending debounced auto-save so a
    // just-made edit isn't lost, persist the window frame, and drop the model so the
    // next open rebuilds a fresh one from current settings.
    func windowWillClose(_ notification: Notification) {
        model?.flush()
        if let win = notification.object as? NSWindow {
            UserDefaults.standard.set(NSStringFromRect(win.frame), forKey: frameKey)
        }
        window = nil
        model = nil
    }
}
