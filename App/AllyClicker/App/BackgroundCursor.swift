import AppKit

// macOS only lets the ACTIVE app control the cursor, and AllyClicker is a
// nonactivating accessory app by design. The private connection property
// "SetsCursorInBackground" lets a background app set the cursor anyway — the
// same approach used by launcher-style utilities. Private API: fine for this
// personal-use app, would need removal for App Store distribution.

@_silgen_name("_CGSDefaultConnection")
private func _CGSDefaultConnection() -> Int32

@_silgen_name("CGSSetConnectionProperty")
private func CGSSetConnectionProperty(_ cid: Int32, _ targetCID: Int32,
                                      _ key: CFString, _ value: CFTypeRef) -> CGError

enum BackgroundCursor {
    /// Call once at startup to allow NSCursor changes while in the background.
    static func enable() {
        let connection = _CGSDefaultConnection()
        let result = CGSSetConnectionProperty(
            connection, connection,
            "SetsCursorInBackground" as CFString,
            kCFBooleanTrue)
        NSLog("AllyClicker: SetsCursorInBackground -> \(result.rawValue)")
    }
}
