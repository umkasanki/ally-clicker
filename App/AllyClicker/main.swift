import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no Dock icon — runs as menu bar / background app
let delegate = AppDelegate()
app.delegate = delegate
app.run()
