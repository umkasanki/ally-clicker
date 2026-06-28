import Foundation

// MARK: - Settings
//
// Behavioral settings model. Defaults are the user's real tuned values extracted
// from Point-N-Click 3.0.3.2 Windows registry (HKCU:\Software\Point-N-Click).
//
// Timing values stored as milliseconds (Int). Use `…Seconds` computed properties
// when driving timers.
//
// DECODING IS RESILIENT TO MISSING KEYS: every struct implements init(from:) with
// decodeIfPresent, falling back to its default value. This means a settings.json
// written by an older build (missing fields added later) still loads, preserving
// the user's tuned values instead of silently resetting everything to defaults.

public struct Settings: Codable, Equatable {
    public var timing = Timing()
    public var stillness = Stillness()
    public var clicks = Clicks()
    public var autoScroll = AutoScroll()
    public var appearance = Appearance()
    public var panel = Panel()
    public var commands = Commands()

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        timing     = try c.decodeIfPresent(Timing.self,     forKey: .timing)     ?? d.timing
        stillness  = try c.decodeIfPresent(Stillness.self,  forKey: .stillness)  ?? d.stillness
        clicks     = try c.decodeIfPresent(Clicks.self,     forKey: .clicks)     ?? d.clicks
        autoScroll = try c.decodeIfPresent(AutoScroll.self, forKey: .autoScroll) ?? d.autoScroll
        appearance = try c.decodeIfPresent(Appearance.self, forKey: .appearance) ?? d.appearance
        panel      = try c.decodeIfPresent(Panel.self,      forKey: .panel)      ?? d.panel
        commands   = try c.decodeIfPresent(Commands.self,   forKey: .commands)   ?? d.commands
    }
}

// MARK: - Timing

extension Settings {
    public struct Timing: Codable, Equatable {
        /// How long to dwell on a panel button before it is selected (ms).
        public var dwellTimeMs: Int = 320
        /// How long the cursor must stay still before an auto-click fires (ms).
        public var dwellTimeMouseMs: Int = 195

        /// DRAG phase 1: how long to dwell at the start point before mouseDown (ms).
        public var autoSelectDownMs: Int = 320
        /// DRAG phase 2: how long to dwell at the end point before mouseUp (ms).
        public var autoSelectUpMs: Int = 210

        public var dwellTimeSeconds: TimeInterval { Double(dwellTimeMs) / 1000 }
        public var dwellTimeMouseSeconds: TimeInterval { Double(dwellTimeMouseMs) / 1000 }
        public var autoSelectDownSeconds: TimeInterval { Double(autoSelectDownMs) / 1000 }
        public var autoSelectUpSeconds: TimeInterval { Double(autoSelectUpMs) / 1000 }

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Timing()
            dwellTimeMs      = try c.decodeIfPresent(Int.self, forKey: .dwellTimeMs)      ?? d.dwellTimeMs
            dwellTimeMouseMs = try c.decodeIfPresent(Int.self, forKey: .dwellTimeMouseMs) ?? d.dwellTimeMouseMs
            autoSelectDownMs = try c.decodeIfPresent(Int.self, forKey: .autoSelectDownMs) ?? d.autoSelectDownMs
            autoSelectUpMs   = try c.decodeIfPresent(Int.self, forKey: .autoSelectUpMs)   ?? d.autoSelectUpMs
        }
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
        /// Minimum cursor movement (px) that counts as "moved to a new target".
        /// Used in two places:
        ///  • after a fire, the cursor must move this far before anything fires
        ///    again (so a parked cursor does not machine-gun clicks);
        ///  • after a drag's mouseDown, the cursor must move this far before the
        ///    mouseUp phase can begin (prevents a zero-length drag).
        public var moveRadiusPx: Int = 10

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Stillness()
            sensitivity       = try c.decodeIfPresent(Int.self, forKey: .sensitivity)       ?? d.sensitivity
            trackerIntervalMs = try c.decodeIfPresent(Int.self, forKey: .trackerIntervalMs) ?? d.trackerIntervalMs
            moveRadiusPx      = try c.decodeIfPresent(Int.self, forKey: .moveRadiusPx)      ?? d.moveRadiusPx
        }
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

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Clicks()
            left        = try c.decodeIfPresent(Bool.self, forKey: .left)        ?? d.left
            leftDrag    = try c.decodeIfPresent(Bool.self, forKey: .leftDrag)    ?? d.leftDrag
            right       = try c.decodeIfPresent(Bool.self, forKey: .right)       ?? d.right
            middle      = try c.decodeIfPresent(Bool.self, forKey: .middle)      ?? d.middle
            doubleClick = try c.decodeIfPresent(Bool.self, forKey: .doubleClick) ?? d.doubleClick
            defaultLeft = try c.decodeIfPresent(Bool.self, forKey: .defaultLeft) ?? d.defaultLeft
            autoCancel  = try c.decodeIfPresent(Bool.self, forKey: .autoCancel)  ?? d.autoCancel
        }
    }
}

// MARK: - Auto-scroll

extension Settings {
    /// Tunable parameters for the middle-click auto-scroll mode.
    /// Algorithm ported from LinearMouse (MIT). Constants are tunable; the
    /// real-world feel must be validated on a Mac.
    public struct AutoScroll: Codable, Equatable {
        /// Movement within this radius (px) of the anchor produces no scroll.
        public var deadZonePx: Double = 10
        /// Constant scroll speed added once outside the dead zone (px/tick).
        public var base: Double = 0
        /// Multiplier on sqrt(distance beyond dead zone) — controls ramp-up.
        public var boost: Double = 3
        /// Maximum scroll delta per tick (px), to cap runaway speed.
        public var maxSpeedPerTick: Double = 160

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = AutoScroll()
            deadZonePx      = try c.decodeIfPresent(Double.self, forKey: .deadZonePx)      ?? d.deadZonePx
            base            = try c.decodeIfPresent(Double.self, forKey: .base)            ?? d.base
            boost           = try c.decodeIfPresent(Double.self, forKey: .boost)           ?? d.boost
            maxSpeedPerTick = try c.decodeIfPresent(Double.self, forKey: .maxSpeedPerTick) ?? d.maxSpeedPerTick
        }
    }
}

// MARK: - Appearance

extension Settings {
    public struct Appearance: Codable, Equatable {
        public var audio: Bool = true
        /// Panel opacity 0–255 (255 = fully opaque).
        public var transparency: Int = 255

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Appearance()
            audio        = try c.decodeIfPresent(Bool.self, forKey: .audio)        ?? d.audio
            transparency = try c.decodeIfPresent(Int.self,  forKey: .transparency) ?? d.transparency
        }
    }
}

// MARK: - Panel geometry

extension Settings {
    /// Window geometry — narrow vertical strip docked to screen edge.
    public struct Panel: Codable, Equatable {
        public var width: Int = 70
        public var positionY: Int = 204

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Panel()
            width     = try c.decodeIfPresent(Int.self, forKey: .width)     ?? d.width
            positionY = try c.decodeIfPresent(Int.self, forKey: .positionY) ?? d.positionY
        }
    }
}

// MARK: - Commands (one-shot panel buttons)

extension Settings {
    public struct Commands: Codable, Equatable {
        /// App launched by the KEYBOARD button. Empty = use the OS on-screen keyboard
        /// (resolved by the macOS app layer). A path or bundle id otherwise.
        public var keyboardAppPath: String = ""

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Commands()
            keyboardAppPath = try c.decodeIfPresent(String.self, forKey: .keyboardAppPath) ?? d.keyboardAppPath
        }
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
