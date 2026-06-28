import XCTest
@testable import AllyClickerCore

final class SettingsTests: XCTestCase {

    func testDefaultsMatchPNCValues() {
        let s = Settings()
        XCTAssertEqual(s.timing.dwellTimeMs, 320)
        XCTAssertEqual(s.timing.dwellTimeMouseMs, 195)
        XCTAssertEqual(s.stillness.sensitivity, 1)
        XCTAssertTrue(s.clicks.defaultLeft)
        XCTAssertTrue(s.clicks.autoCancel)
    }

    func testSecondsConversion() {
        let t = Settings.Timing()
        XCTAssertEqual(t.dwellTimeSeconds, 0.320, accuracy: 0.0001)
        XCTAssertEqual(t.dwellTimeMouseSeconds, 0.195, accuracy: 0.0001)
        XCTAssertEqual(t.autoSelectUpSeconds, 0.210, accuracy: 0.0001)
    }

    func testJSONRoundTrip() throws {
        var s = Settings()
        s.timing.dwellTimeMs = 500
        s.clicks.defaultLeft = false
        s.stillness.sensitivity = 4

        let data = try s.jsonData()
        let decoded = try Settings.load(from: data)

        XCTAssertEqual(decoded, s)
        XCTAssertEqual(decoded.timing.dwellTimeMs, 500)
        XCTAssertEqual(decoded.clicks.defaultLeft, false)
        XCTAssertEqual(decoded.stillness.sensitivity, 4)
    }

    func testEmptyJSONDecodesToAllDefaults() throws {
        let data = "{}".data(using: .utf8)!
        let decoded = try Settings.load(from: data)
        XCTAssertEqual(decoded, Settings())
    }

    func testPartialJSONKeepsKnownValuesAndDefaultsTheRest() throws {
        // Only one nested field provided — simulates an old config missing newer keys.
        let json = """
        { "timing": { "dwellTimeMs": 600 } }
        """.data(using: .utf8)!
        let decoded = try Settings.load(from: json)

        XCTAssertEqual(decoded.timing.dwellTimeMs, 600, "Provided value is kept")
        // Everything not present falls back to defaults — not wiped.
        XCTAssertEqual(decoded.timing.dwellTimeMouseMs, Settings().timing.dwellTimeMouseMs)
        XCTAssertEqual(decoded.stillness, Settings().stillness)
        XCTAssertEqual(decoded.clicks, Settings().clicks)
        XCTAssertEqual(decoded.autoScroll, Settings().autoScroll)
    }

    func testMissingNestedFieldDoesNotResetSibling() throws {
        // clicks present but missing newer "autoCancel" key → keep others, default it.
        let json = """
        { "clicks": { "defaultLeft": false } }
        """.data(using: .utf8)!
        let decoded = try Settings.load(from: json)

        XCTAssertFalse(decoded.clicks.defaultLeft)
        XCTAssertTrue(decoded.clicks.autoCancel, "Absent field defaults, siblings preserved")
    }

    // MARK: - Configurable panel layout

    func testDefaultPanelLayoutMatchesScreenshot() {
        XCTAssertEqual(Settings().panel.items, [
            .command(.togglePanel),
            .action(.left), .action(.right), .action(.leftDrag),
            .action(.doubleClick), .action(.middle),
            .command(.launchKeyboard),
        ])
    }

    func testPanelItemsRoundTripPreservingOrder() throws {
        var s = Settings()
        // Reorder + drop some + keep commands.
        s.panel.items = [
            .command(.togglePanel),
            .action(.middle),
            .action(.left),
            .command(.launchKeyboard),
        ]
        let decoded = try Settings.load(from: try s.jsonData())
        XCTAssertEqual(decoded.panel.items, s.panel.items, "Order and membership preserved")
    }

    func testPanelItemEncodesAsStableString() throws {
        let data = try JSONEncoder().encode(PanelItem.action(.leftDrag))
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"leftDrag\"")
    }

    func testUnknownPanelItemIdDroppedWithoutLosingGeometry() throws {
        // A newer build wrote an unknown button id; an older build must keep the
        // recognized items AND width/positionY instead of resetting the whole Panel.
        let json = """
        { "panel": { "width": 99, "positionY": 5,
                     "items": ["left", "totallyNewButton", "right"] } }
        """.data(using: .utf8)!
        let decoded = try Settings.load(from: json)

        XCTAssertEqual(decoded.panel.width, 99, "Geometry preserved despite a bad item")
        XCTAssertEqual(decoded.panel.positionY, 5)
        XCTAssertTrue(decoded.panel.items.contains(.action(.left)))
        XCTAssertTrue(decoded.panel.items.contains(.action(.right)))
        XCTAssertFalse(decoded.panel.items.contains { $0.id == "totallyNewButton" })
    }

    func testPanelNormalizeDedupesEnsuresOnOffAndFallsBack() {
        // Duplicates removed (first occurrence kept).
        let deduped = Settings.Panel.normalize([
            .command(.togglePanel), .action(.left), .action(.left), .action(.right)
        ])
        XCTAssertEqual(deduped, [.command(.togglePanel), .action(.left), .action(.right)])

        // Missing ON/OFF gets re-inserted at the front (recovery safeguard).
        let withOnOff = Settings.Panel.normalize([.action(.left)])
        XCTAssertEqual(withOnOff.first, .command(.togglePanel))

        // Empty → default layout, never an unusable empty panel.
        XCTAssertEqual(Settings.Panel.normalize([]), Settings.Panel.defaultItems)
    }

    func testActionAndCommandRawValuesAreDisjoint() {
        let actions = Set(DwellEngine.Action.allCases.map(\.rawValue))
        let commands = Set(DwellEngine.Command.allCases.map(\.rawValue))
        XCTAssertTrue(actions.isDisjoint(with: commands),
                      "PanelItem id resolution relies on Action/Command rawValues never colliding")
    }

    func testKeyboardTargetMissingModeFallsBackWithoutNukingSiblings() throws {
        let json = """
        { "timing": { "dwellTimeMs": 700 }, "commands": { "path": "x" } }
        """.data(using: .utf8)!
        let decoded = try Settings.load(from: json)

        XCTAssertEqual(decoded.commands.keyboard, .accessibilityKeyboard, "Malformed keyboard → safe default")
        XCTAssertEqual(decoded.timing.dwellTimeMs, 700, "Sibling settings preserved")
    }

    // MARK: - Keyboard target (three modes)

    func testKeyboardDefaultsToAccessibilityKeyboard() {
        XCTAssertEqual(Settings().commands.keyboard, .accessibilityKeyboard)
    }

    func testKeyboardTargetRoundTripAllModes() throws {
        for target in [Settings.KeyboardTarget.accessibilityKeyboard,
                       .keyboardViewer,
                       .customApp(path: "/Applications/MyKeyboard.app")] {
            var s = Settings()
            s.commands.keyboard = target
            let decoded = try Settings.load(from: try s.jsonData())
            XCTAssertEqual(decoded.commands.keyboard, target)
        }
    }
}
