import Foundation

/// Persists Settings as JSON. By default writes to the app support directory;
/// a custom directory can be injected (used by tests).
public final class SettingsStore {
    private let fileURL: URL

    /// Errors from the last save(), if any. nil means the last save succeeded.
    /// Surfaced (rather than silently swallowed) so the app can warn the user —
    /// losing laboriously-tuned dwell timings would be a real problem.
    public private(set) var lastSaveError: Error?

    public init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("settings.json")
    }

    private static func defaultDirectory() -> URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("AllyClicker")
    }

    public func load() -> Settings {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? Settings.load(from: data) else {
            return Settings()
        }
        return settings
    }

    /// Save settings. Returns true on success; on failure stores the error in
    /// `lastSaveError` and returns false.
    @discardableResult
    public func save(_ settings: Settings) -> Bool {
        do {
            let data = try settings.jsonData()
            try data.write(to: fileURL, options: .atomic)
            lastSaveError = nil
            return true
        } catch {
            lastSaveError = error
            return false
        }
    }
}
