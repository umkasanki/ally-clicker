import AppKit

// Menu bar icon — the only entry point for Settings and Quit (the app is an
// LSUIElement with no Dock icon or app menu).
final class StatusBarController {
    private let item: NSStatusItem
    private let onOpenSettings: () -> Void

    init(onOpenSettings: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            // cursorarrow reads optically smaller than neighbouring menu-bar
            // glyphs, so bump its point size to match.
            let config = NSImage.SymbolConfiguration(pointSize: 19, weight: .regular)
            let img = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: "AllyClicker")?
                .withSymbolConfiguration(config)
            img?.isTemplate = true
            button.image = img
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit AllyClicker", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
    }

    @objc private func openSettings() { onOpenSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
