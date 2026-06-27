import Foundation

// MARK: - PNCSettings
//
// Behavioral settings model for a macOS dwell-click / virtual-mouse tool.
//
// Reconstructed from Point-N-Click 3.0.3.2 (Windows), registry key
// HKCU:\Software\Point-N-Click. This struct intentionally mirrors the original
// configuration so the proven behavior can be ported 1:1. The Windows
// low-level layer (mouse sensing + click injection) must be rewritten for
// macOS (see the project brief), but THIS model — the parameters and how they
// relate — is operating-system independent.
//
// Codable keys match pnc-settings-model.json, so the JSON can be loaded
// directly with JSONDecoder().decode(PNCSettings.self, from: data).
//
// NOTE ON UNITS: timing values are stored as milliseconds (Int), exactly as
// the source stored them. The original UI showed them divided by 1000
// (e.g. 320 -> "0.32 Seconds"). Use the `…Seconds` computed properties when
// driving Timer / DispatchSource on macOS.

struct PNCSettings: Codable, Equatable {
    var timing = Timing()
    var stillness = StillnessDetection()
    var clicks = ClickActions()
    var repeatOptions = RepeatOptions()
    var appearance = Appearance()
    var panel = PanelGeometry()

    /// Version of the Windows app these defaults were taken from.
    var sourceVersion: String = "3.0.3.2"
}

// MARK: - Timing

extension PNCSettings {
    /// Dwell-time thresholds. Stored in milliseconds to match the source.
    struct Timing: Codable, Equatable {
        /// How long the cursor must rest on a button before it is selected.
        var dwellTimeMs: Int = 320
        /// Same as `dwellTimeMs`, but for the Exit button (kept shorter).
        var dwellTimeExitMs: Int = 210
        /// How long the mouse must stay still before an auto-click fires.
        var dwellTimeMouseMs: Int = 195
        /// "Use timer" value. Units unconfirmed (likely tenths of a second or
        /// internal ticks). Verify against the running app before relying on it.
        var useTimer: Int = 30
        /// Reset counterpart to `useTimer`. Units unconfirmed (see above).
        var useTimerReset: Int = 10

        // Convenience accessors in seconds (TimeInterval) for use with Timer.
        var dwellTimeSeconds: TimeInterval { Double(dwellTimeMs) / 1000 }
        var dwellTimeExitSeconds: TimeInterval { Double(dwellTimeExitMs) / 1000 }
        var dwellTimeMouseSeconds: TimeInterval { Double(dwellTimeMouseMs) / 1000 }
    }
}

// MARK: - Stillness detection
//
// This is the core of the auto-click engine and is fully OS-independent.
// The idea: poll the cursor position every `trackerIntervalMs`. While the
// cursor stays within the `sensitivity` tolerance, the dwell timer keeps
// running; if it moves beyond tolerance, the timer resets. `averageVelocity`
// is the value measured during the app's "speed test" calibration.

extension PNCSettings {
    struct StillnessDetection: Codable, Equatable {
        /// Movement tolerance ("Units" in the Windows UI). Higher = more
        /// tolerant of cursor jitter. 1 is the tightest setting. Almost
        /// certainly a pixel radius; confirm during calibration.
        var sensitivity: Int = 1
        /// How often the cursor position is sampled, in milliseconds.
        var trackerIntervalMs: Int = 5
        /// Calibration flags from the baseline/speed test. Meaning of the bit
        /// field is unconfirmed; treat as opaque calibration state for now.
        var baselineFlags: Int = 3
        /// Average cursor velocity measured during calibration.
        var averageVelocity: Double = 0.39
    }
}

// MARK: - Click actions
//
// Which click types the tool can inject. On macOS these map to CGEvent mouse
// events (see brief). Booleans reflect which actions are enabled in the panel.

extension PNCSettings {
    struct ClickActions: Codable, Equatable {
        var left: Bool = true
        var left2: Bool = true          // secondary / alternate left action
        var leftDrag: Bool = true
        var right: Bool = true
        var rightDouble: Bool = false
        var rightDrag: Bool = false
        var middle: Bool = true
        var middle2: Bool = false        // secondary / alternate middle action
        var middleDrag: Bool = false
        var rightLeft: Bool = false      // combined right-then-left action
        /// Whether left click is the default action after a selection.
        var defaultLeft: Bool = true
        /// Auto-cancel a pending action if the user moves away.
        var autoCancel: Bool = true
    }
}

// MARK: - Repeat options

extension PNCSettings {
    struct RepeatOptions: Codable, Equatable {
        var repeatMove: Bool = false
        var repeatNoMove: Bool = false
        var fastRepeat: Bool = false
        /// RAMB = "Repeat A Mouse Button" (auto-repeat of a held button).
        /// Meaning inferred; confirm behavior against the Windows app.
        var ramb: Bool = false
    }
}

// MARK: - Appearance & feedback

extension PNCSettings {
    struct Appearance: Codable, Equatable {
        /// Audible feedback on select/click.
        var audio: Bool = true
        /// Visual feedback (countdown / highlight).
        var visual: Bool = false
        /// Panel opacity, 0–255 (255 = fully opaque).
        var transparency: Int = 255
        /// Indicator colors stored as integer color values (Windows OLE color).
        var redColor: Int = 255
        var yellowColor: Int = 65535
        /// Lay the button panel out in a single row/column.
        var singleRow: Bool = true
        /// Hide the panel while active / not in use.
        var activeHide: Bool = true
        var autoHide: Bool = false
        var autoDock: Bool = false
        /// Opacity for the RAMB panel, 0–255.
        var rambTransparency: Int = 255
    }
}

// MARK: - Panel geometry
//
// Window position/size from the source. NOT meant to be ported literally to
// macOS (different screen coordinate system), but it documents the original
// layout: a narrow vertical strip (~70 pt wide) docked to the screen edge.

extension PNCSettings {
    struct PanelGeometry: Codable, Equatable {
        var minWidth: Int = 35
        var minHeight: Int = 106
        var maxWidth: Int = 150
        var maxHeight: Int = 829
        var formWidth: Int = 70
        var formHeight: Int = 350
        var formTop: Int = 204
        var formLeft: Int = 1404
    }
}

// MARK: - Loading / saving helpers

extension PNCSettings {
    /// Decode from JSON data (e.g. the bundled pnc-settings-model.json).
    static func load(from data: Data) throws -> PNCSettings {
        try JSONDecoder().decode(PNCSettings.self, from: data)
    }

    /// Encode to pretty-printed JSON.
    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
