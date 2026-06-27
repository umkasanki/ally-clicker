import Foundation

public final class SettingsStore {
    private let fileURL: URL

    public init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("AllyClicker")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("settings.json")
    }

    public func load() -> Settings {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? Settings.load(from: data) else {
            return Settings()
        }
        return settings
    }

    public func save(_ settings: Settings) {
        guard let data = try? settings.jsonData() else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
