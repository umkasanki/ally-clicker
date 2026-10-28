import AppKit

// App Nap off for the life of the process. AllyClicker has no Dock icon and is
// never the active application, which is exactly what App Nap looks for — and
// a napping app's timers are slowed and coalesced. The dwell loop ticks every
// 5 ms and is this user's only way to click; a coalesced timer is a click that
// comes late. Both mechanisms, as SmartNav Lite does: the defaults key, and the
// documented activity. Latency-critical keeps timers from being coalesced; idle
// system sleep stays allowed, so the Mac still sleeps.
UserDefaults.standard.set(true, forKey: "NSAppSleepDisabled")
let activity = ProcessInfo.processInfo.beginActivity(
    options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
    reason: "Dwell clicking is the user's only way to click and must not be throttled")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no Dock icon — runs as menu bar / background app
let delegate = AppDelegate()
app.delegate = delegate
withExtendedLifetime(activity) { app.run() }
