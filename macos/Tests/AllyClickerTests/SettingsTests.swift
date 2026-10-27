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

    func testDefaultPanelLayout() {
        // KEYBOARD is intentionally absent (moving to a separate panel).
        XCTAssertEqual(Settings().panel.items, [
            .command(.togglePanel),
            .action(.left), .action(.right), .action(.doubleClick),
            .action(.leftDrag), .action(.middle),
        ])
    }

    func testPanelPositionRoundTrip() throws {
        var s = Settings()
        XCTAssertNil(s.panel.positionX, "Defaults to nil = dock right edge")
        s.panel.positionX = 300
        s.panel.positionY = 120
        let decoded = try Settings.load(from: try s.jsonData())
        XCTAssertEqual(decoded.panel.positionX, 300)
        XCTAssertEqual(decoded.panel.positionY, 120)
    }

    func testPanelItemsRoundTripPreservingOrder() throws {
        var s = Settings()
        // Reorder + drop some. (KEYBOARD is stripped by normalize, so it's not
        // used here — the round trip must preserve exactly this custom order.)
        s.panel.items = [
            .command(.togglePanel),
            .action(.middle),
            .action(.left),
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

    func testPanelNormalizeDedupesAndFallsBack() {
        // Duplicates removed (first occurrence kept).
        let deduped = Settings.Panel.normalize([
            .command(.togglePanel), .action(.left), .action(.left), .action(.right)
        ])
        XCTAssertEqual(deduped, [.command(.togglePanel), .action(.left), .action(.right)])

        // ON/OFF is optional: a layout without it is kept as-is (not re-inserted).
        let withoutOnOff = Settings.Panel.normalize([.action(.left), .action(.right)])
        XCTAssertEqual(withoutOnOff, [.action(.left), .action(.right)])

        // But when present, ON/OFF is pinned to the front regardless of input order.
        let pinned = Settings.Panel.normalize([.action(.left), .command(.togglePanel), .action(.right)])
        XCTAssertEqual(pinned, [.command(.togglePanel), .action(.left), .action(.right)])

        // KEYBOARD is stripped (moving to a separate panel).
        let noKeyboard = Settings.Panel.normalize([.action(.left), .command(.launchKeyboard)])
        XCTAssertEqual(noKeyboard, [.action(.left)])

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

    /// Point-N-Click does not click when its scroll stops. Ours did, and on a page
    /// full of links holding still to stop opened whatever was under the cursor —
    /// landing in a task instead of stopping on the board. Measured against PNC on
    /// 2026-10-27 and matched to it, the same standard as the defaults above.
    func testScrollExitDoesNotClickByDefault() {
        XCTAssertFalse(Settings.AutoScroll().clickOnExit)
    }

    /// Settings saved before the key existed decode without it. They must not come
    /// back with the click switched on, which is what a plain `decode` would do if
    /// the default ever flipped.
    func testSettingsSavedBeforeTheKeyKeepTheClickOff() throws {
        let json = #"{"deadZonePx":10,"base":0,"boost":3,"maxSpeedPerTick":160,"intensity":0.5}"#
        let decoded = try JSONDecoder().decode(Settings.AutoScroll.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.clickOnExit)
        XCTAssertEqual(decoded.intensity, 0.5, accuracy: 0.0001)
    }

    /// 0 by default: the exit stays as quick as it was before the setting existed.
    func testScrollExitDelayIsZeroByDefault() {
        XCTAssertEqual(Settings.AutoScroll().exitDelayMs, 0)
    }

    /// Settings saved before the key existed come back with no extra delay.
    func testSettingsSavedBeforeTheKeyHaveNoScrollExitDelay() throws {
        let json = #"{"deadZonePx":10,"base":0,"boost":3,"maxSpeedPerTick":160,"intensity":0.5}"#
        let decoded = try JSONDecoder().decode(Settings.AutoScroll.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.exitDelayMs, 0)
    }

    /// A hand-edited value outside 0–2 s is pulled back into range rather than
    /// trapping the user in scroll mode, or going negative.
    func testScrollExitDelayIsClampedToTwoSeconds() throws {
        func decode(_ ms: Int) throws -> Int {
            let json = #"{"intensity":0.5,"exitDelayMs":\#(ms)}"#
            return try JSONDecoder().decode(Settings.AutoScroll.self, from: Data(json.utf8)).exitDelayMs
        }
        XCTAssertEqual(try decode(60_000), 2000)
        XCTAssertEqual(try decode(-500), 0)
        XCTAssertEqual(try decode(800), 800)
    }

    /// The value survives a save and a load.
    func testScrollExitDelayRoundTrips() throws {
        var s = Settings.AutoScroll()
        s.exitDelayMs = 1200
        let back = try JSONDecoder().decode(Settings.AutoScroll.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.exitDelayMs, 1200)
    }
}
