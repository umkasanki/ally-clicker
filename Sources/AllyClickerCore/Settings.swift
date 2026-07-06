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
    public var calibration = Calibration()

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        timing      = try c.decodeIfPresent(Timing.self,      forKey: .timing)      ?? d.timing
        stillness   = try c.decodeIfPresent(Stillness.self,   forKey: .stillness)   ?? d.stillness
        clicks      = try c.decodeIfPresent(Clicks.self,      forKey: .clicks)      ?? d.clicks
        autoScroll  = try c.decodeIfPresent(AutoScroll.self,  forKey: .autoScroll)  ?? d.autoScroll
        appearance  = try c.decodeIfPresent(Appearance.self,  forKey: .appearance)  ?? d.appearance
        panel       = try c.decodeIfPresent(Panel.self,       forKey: .panel)       ?? d.panel
        commands    = try c.decodeIfPresent(Commands.self,    forKey: .commands)    ?? d.commands
        calibration = try c.decodeIfPresent(Calibration.self, forKey: .calibration) ?? d.calibration
    }

    /// Effective desktop auto-click dwell time (seconds).
    /// If calibration is enabled and valid, use the PNC-style adaptive formula;
    /// otherwise fall back to the manual `timing.dwellTimeMouseMs`.
    public var effectiveDwellMouseSeconds: TimeInterval {
        if let ms = calibration.computedDwellMs(sensitivity: stillness.sensitivity) {
            return Double(ms) / 1000
        }
        return timing.dwellTimeMouseSeconds
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
    /// Click *behavior* only. Which buttons appear on the panel is configured by
    /// `panel.items`, not here.
    public struct Clicks: Codable, Equatable {
        /// After any action fires, revert armed action to left click.
        public var defaultLeft: Bool = true
        /// Cancel the armed action after one execution (vs. repeat forever).
        public var autoCancel: Bool = true

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Clicks()
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
        /// User-facing speed multiplier applied to the final scroll delta.
        /// <1 slower (for less precise users), >1 faster. 0.5 is a comfortable default.
        public var intensity: Double = 0.5

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = AutoScroll()
            deadZonePx      = try c.decodeIfPresent(Double.self, forKey: .deadZonePx)      ?? d.deadZonePx
            base            = try c.decodeIfPresent(Double.self, forKey: .base)            ?? d.base
            boost           = try c.decodeIfPresent(Double.self, forKey: .boost)           ?? d.boost
            maxSpeedPerTick = try c.decodeIfPresent(Double.self, forKey: .maxSpeedPerTick) ?? d.maxSpeedPerTick
            intensity       = try c.decodeIfPresent(Double.self, forKey: .intensity)       ?? d.intensity
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
    /// Panel layout & geometry. `items` is the ordered, user-configurable list of
    /// buttons — its order IS the on-screen order; adding/removing an item adds or
    /// removes the button.
    public struct Panel: Codable, Equatable {
        public var width: Int = 70
        /// Top-left position of the panel (points from the top of the screen).
        public var positionY: Int = 204
        /// Top-left X (points from the left). nil = dock to the right edge (default).
        /// Set once the user drags the panel, so its place is remembered.
        public var positionX: Int? = nil
        /// Ordered buttons shown on the panel. Defaults to the confirmed PNC layout.
        public var items: [PanelItem] = Panel.defaultItems

        /// Confirmed default layout (top → bottom): ON/OFF, LEFT, RIGHT, DOUBLE,
        /// DRAG, MIDDLE, KEYBOARD.
        public static let defaultItems: [PanelItem] = [
            .command(.togglePanel),
            .action(.left),
            .action(.right),
            .action(.doubleClick),
            .action(.leftDrag),
            .action(.middle),
            .command(.launchKeyboard),
        ]

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Panel()
            width     = try c.decodeIfPresent(Int.self, forKey: .width)     ?? d.width
            positionY = try c.decodeIfPresent(Int.self, forKey: .positionY) ?? d.positionY
            positionX = try c.decodeIfPresent(Int.self, forKey: .positionX)
            // Decode items leniently: unknown ids (e.g. from a newer build) are
            // dropped rather than throwing — a single bad token must NOT discard the
            // whole Panel (which would also lose width/positionY). Then normalize.
            if let ids = try c.decodeIfPresent([String].self, forKey: .items) {
                items = Panel.normalize(ids.compactMap(PanelItem.init(id:)))
            } else {
                items = d.items
            }
        }

        /// Guarantee a usable layout: drop duplicates (keeping first occurrence),
        /// ensure ON/OFF is present (so the user can always recover the panel), and
        /// fall back to the default layout if the result would be empty. This is an
        /// accessibility safeguard — an empty or ON/OFF-less panel could lock the
        /// hands-free user out.
        public static func normalize(_ items: [PanelItem]) -> [PanelItem] {
            var seen = Set<PanelItem>()
            var result = items.filter { seen.insert($0).inserted }
            if result.isEmpty { return defaultItems }
            if !result.contains(.command(.togglePanel)) {
                result.insert(.command(.togglePanel), at: 0)
            }
            return result
        }
    }
}

// MARK: - Commands (one-shot panel buttons)

extension Settings {
    /// What the KEYBOARD button launches. The user picks one of three targets.
    public enum KeyboardTarget: Equatable {
        /// macOS built-in Accessibility Keyboard (Settings → Accessibility → Keyboard).
        case accessibilityKeyboard
        /// macOS Keyboard Viewer (the standard on-screen virtual keyboard).
        case keyboardViewer
        /// A third-party app, by file path or bundle identifier.
        case customApp(path: String)
    }

    public struct Commands: Codable, Equatable {
        /// Target launched by the KEYBOARD button. Defaults to the built-in
        /// Accessibility Keyboard (the most likely fit for a hands-free user).
        public var keyboard: KeyboardTarget = .accessibilityKeyboard

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Commands()
            keyboard = try c.decodeIfPresent(KeyboardTarget.self, forKey: .keyboard) ?? d.keyboard
        }
    }
}

// KeyboardTarget persists as { "mode": "...", "path": "..." } — path only for custom.
extension Settings.KeyboardTarget: Codable {
    private enum CodingKeys: String, CodingKey { case mode, path }
    private enum Mode: String, Codable { case accessibilityKeyboard, keyboardViewer, customApp }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Missing/unknown mode falls back to the safe default rather than throwing
        // (consistent with the resilient-decode doctrine).
        switch (try? c.decodeIfPresent(Mode.self, forKey: .mode)) ?? .accessibilityKeyboard {
        case .accessibilityKeyboard: self = .accessibilityKeyboard
        case .keyboardViewer:        self = .keyboardViewer
        case .customApp:             self = .customApp(path: try c.decodeIfPresent(String.self, forKey: .path) ?? "")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .accessibilityKeyboard: try c.encode(Mode.accessibilityKeyboard, forKey: .mode)
        case .keyboardViewer:        try c.encode(Mode.keyboardViewer, forKey: .mode)
        case .customApp(let path):
            try c.encode(Mode.customApp, forKey: .mode)
            try c.encode(path, forKey: .path)
        }
    }
}

// MARK: - Adaptive dwell calibration
//
// Confirmed by the PNC author: PNC does not set the desktop dwell time directly —
// it computes it from a per-user baseline speed measurement:
//
//     DwellTimeMouse = Int(DwellMultiplier * Sensitivity_Twips / AverageVelocity)
//
// Slower movers get a longer dwell, faster movers a shorter one — that
// auto-adaptation is what makes PNC comfortable for hours. We keep this as pure
// arithmetic in the core; the baseline speed test (measuring averageVelocity) and
// the calibration UI live in the macOS app. Units are re-derived for macOS
// (twips → points); `multiplier` must be re-tuned on a Mac so a user's measured
// velocity lands near their comfortable dwell. Disabled by default → manual fallback.

extension Settings {
    public struct Calibration: Codable, Equatable {
        /// When false, the manual `timing.dwellTimeMouseMs` is used (default).
        public var enabled: Bool = false
        /// Per-user cursor speed from the baseline test (points/sec). 0 = not measured.
        public var averageVelocity: Double = 0
        /// Responsiveness scalar. Placeholder; must be tuned during macOS calibration
        /// so real measured velocities produce comfortable dwell times.
        public var multiplier: Double = 76

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Calibration()
            enabled         = try c.decodeIfPresent(Bool.self,   forKey: .enabled)         ?? d.enabled
            averageVelocity = try c.decodeIfPresent(Double.self, forKey: .averageVelocity) ?? d.averageVelocity
            multiplier      = try c.decodeIfPresent(Double.self, forKey: .multiplier)      ?? d.multiplier
        }

        /// Computed dwell (ms) from the formula, or nil if calibration can't produce
        /// a usable value (disabled, or velocity not yet measured). Clamped to ≥ 1ms.
        public func computedDwellMs(sensitivity: Int) -> Int? {
            guard enabled, averageVelocity > 0 else { return nil }
            let ms = multiplier * Double(sensitivity) / averageVelocity
            return max(1, Int(ms))
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
