import Foundation

// MARK: - Settings
//
// Behavioral settings model. Defaults are the user's real tuned values extracted
// from Point-N-Click 3.0.3.2 Windows registry (HKCU:\Software\Point-N-Click).
//
// Timing values stored as milliseconds (Int). Use `…Seconds` computed properties
// when driving timers.

public struct Settings: Codable, Equatable {
    public var timing = Timing()
    public var stillness = Stillness()
    public var clicks = Clicks()
    public var appearance = Appearance()
    public var panel = Panel()

    public init() {}
}

// MARK: - Timing

extension Settings {
    public struct Timing: Codable, Equatable {
        /// How long to dwell on a panel button before it is selected (ms).
        public var dwellTimeMs: Int = 320
        /// Dwell time for the Exit button — shorter than regular buttons (ms).
        public var dwellTimeExitMs: Int = 210
        /// How long the cursor must stay still before an auto-click fires (ms).
        public var dwellTimeMouseMs: Int = 195

        /// DRAG phase 1: how long to dwell at the start point before mouseDown (ms).
        public var autoSelectDownMs: Int = 320
        /// DRAG phase 2: how long to dwell at the end point before mouseUp (ms).
        public var autoSelectUpMs: Int = 210

        public var dwellTimeSeconds: TimeInterval { Double(dwellTimeMs) / 1000 }
        public var dwellTimeExitSeconds: TimeInterval { Double(dwellTimeExitMs) / 1000 }
        public var dwellTimeMouseSeconds: TimeInterval { Double(dwellTimeMouseMs) / 1000 }
        public var autoSelectDownSeconds: TimeInterval { Double(autoSelectDownMs) / 1000 }
        public var autoSelectUpSeconds: TimeInterval { Double(autoSelectUpMs) / 1000 }

        public init() {}
    }
}

// MARK: - Stillness detection

extension Settings {
    public struct Stillness: Codable, Equatable {
        /// Movement tolerance in pixels. 1 = tightest. Higher = more jitter-tolerant.
        /// Crucial for head trackers: the head always trembles slightly.
        public var sensitivity: Int = 1
        /// Cursor sampling interval (ms). 5ms = 200 Hz — matches PNC.
        public var trackerIntervalMs: Int = 5
        /// Minimum cursor movement (px) after a drag's mouseDown before the
        /// mouseUp phase can begin. Prevents a zero-length "drag" when the user
        /// hasn't moved off the start point yet.
        public var dragMoveThresholdPx: Int = 10

        public init() {}
    }
}

// MARK: - Click configuration

extension Settings {
    public struct Clicks: Codable, Equatable {
        /// Which actions are enabled in the panel.
        public var left: Bool = true
        public var leftDrag: Bool = true
        public var right: Bool = true
        public var middle: Bool = true
        public var doubleClick: Bool = true

        /// After any action fires, revert armed action to left click.
        public var defaultLeft: Bool = true
        /// Cancel the armed action after one execution (vs. repeat forever).
        public var autoCancel: Bool = true

        public init() {}
    }
}

// MARK: - Appearance

extension Settings {
    public struct Appearance: Codable, Equatable {
        public var audio: Bool = true
        /// Panel opacity 0–255 (255 = fully opaque).
        public var transparency: Int = 255

        public init() {}
    }
}

// MARK: - Panel geometry

extension Settings {
    /// Window geometry — narrow vertical strip docked to screen edge.
    public struct Panel: Codable, Equatable {
        public var width: Int = 70
        public var positionY: Int = 204

        public init() {}
    }
}

// MARK: - Persistence

extension Settings {
    public static func load(from data: Data) throws -> Settings {
        try JSONDecoder().decode(Settings.self, from: data)
    }

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
