import XCTest
@testable import AllyClickerCore

final class SettingsStoreTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AllyClickerTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testLoadReturnsDefaultsWhenNoFile() {
        let store = SettingsStore(directory: tempDir)
        XCTAssertEqual(store.load(), Settings())
    }

    func testSaveThenLoadRoundTrip() {
        let store = SettingsStore(directory: tempDir)
        var s = Settings()
        s.timing.dwellTimeMs = 450
        s.clicks.defaultLeft = false
        s.autoScroll.boost = 5

        XCTAssertTrue(store.save(s))
        XCTAssertNil(store.lastSaveError)

        // A fresh store pointed at the same dir should read the persisted values.
        let reloaded = SettingsStore(directory: tempDir).load()
        XCTAssertEqual(reloaded, s)
        XCTAssertEqual(reloaded.timing.dwellTimeMs, 450)
        XCTAssertEqual(reloaded.clicks.defaultLeft, false)
        XCTAssertEqual(reloaded.autoScroll.boost, 5)
    }

    func testSaveWritesFileToDisk() {
        let store = SettingsStore(directory: tempDir)
        store.save(Settings())
        let file = tempDir.appendingPathComponent("settings.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testCorruptFileFallsBackToDefaults() throws {
        let file = tempDir.appendingPathComponent("settings.json")
        try "{ not valid json".write(to: file, atomically: true, encoding: .utf8)
        let store = SettingsStore(directory: tempDir)
        XCTAssertEqual(store.load(), Settings())
    }
}
