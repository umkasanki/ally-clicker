import Foundation
import AllyClickerCore

// Emits a golden fixture: for each input document, what this implementation actually
// decodes it into. The C# port is checked against this file, so parity stops being a
// matter of reading the Swift carefully and becomes a mechanical comparison.
//
// Usage (from macos/, no Mac needed):
//   docker run --rm -v "$PWD":/pkg -w /pkg swift:6.0 \
//       swift run SettingsGolden > ../windows/AllyClicker.Core.Tests/Fixtures/settings-golden.json
//
// Cases deliberately cover the places where a naive port silently diverges: absent keys,
// explicit nulls, out-of-range values that are clamped during decoding, and the panel
// layout normalisation rules.

struct Case {
    let name: String
    let note: String
    let input: String
}

let cases: [Case] = [
    Case(name: "defaults",
         note: "Empty document — every field falls back to its default.",
         input: "{}"),

    Case(name: "partial-timing",
         note: "Only some timing fields present; the rest keep defaults, other sections untouched.",
         input: #"{ "timing": { "dwellTimeMs": 500 } }"#),

    Case(name: "unknown-keys-ignored",
         note: "Keys from a newer build are ignored rather than fatal.",
         input: #"{ "timing": { "dwellTimeMs": 400, "somethingNew": 1 }, "brandNewSection": { "x": 2 } }"#),

    Case(name: "explicit-null-falls-back",
         note: "An explicit null is treated as absent (decodeIfPresent). This is where System.Text.Json would throw instead.",
         input: #"{ "timing": { "dwellTimeMs": null }, "panel": { "width": null } }"#),

    Case(name: "positionX-null-stays-nil",
         note: "positionX is genuinely optional — null means 'dock to the right edge', not a default number.",
         input: #"{ "panel": { "positionX": null, "positionY": 300 } }"#),

    Case(name: "positionX-set",
         note: "positionX carries a value once the user has dragged the panel.",
         input: #"{ "panel": { "positionX": 42, "positionY": 300 } }"#),

    Case(name: "clamp-intensity-high",
         note: "Hand-edited scroll intensity above the allowed range is clamped at decode time.",
         input: #"{ "autoScroll": { "intensity": 50 } }"#),

    Case(name: "clamp-intensity-low",
         note: "Below range clamps up, so scrolling can never be inverted or frozen.",
         input: #"{ "autoScroll": { "intensity": 0.001 } }"#),

    Case(name: "clamp-audio-volume",
         note: "Volume clamps into 0...1.",
         input: #"{ "appearance": { "audioVolume": 7.5 } }"#),

    Case(name: "clamp-audio-volume-negative",
         note: "Negative volume clamps to 0.",
         input: #"{ "appearance": { "audioVolume": -3 } }"#),

    Case(name: "clamp-icon-scale",
         note: "Icon scale clamps into 0.5...2.0.",
         input: #"{ "appearance": { "iconScale": 10 } }"#),

    Case(name: "clamp-icon-scale-low",
         note: "Tiny icon scale clamps up rather than vanishing.",
         input: #"{ "appearance": { "iconScale": 0.01 } }"#),

    Case(name: "panel-unknown-item-dropped",
         note: "An unrecognised button id is dropped; the rest of the layout AND the geometry survive.",
         input: #"{ "panel": { "width": 70, "items": ["left", "totallyNewButton", "right"] } }"#),

    Case(name: "panel-duplicates-dropped",
         note: "Duplicates collapse, first occurrence wins.",
         input: #"{ "panel": { "items": ["left", "right", "left", "middle", "right"] } }"#),

    Case(name: "panel-keyboard-stripped",
         note: "KEYBOARD is being moved to its own panel, so it is stripped wherever it appears.",
         input: #"{ "panel": { "items": ["togglePanel", "launchKeyboard", "left"] } }"#),

    Case(name: "panel-onoff-pinned-first",
         note: "ON/OFF is optional, but when present it is always the first button.",
         input: #"{ "panel": { "items": ["left", "right", "togglePanel", "middle"] } }"#),

    Case(name: "panel-empty-falls-back-to-defaults",
         note: "An empty layout would leave nothing to click, so the default layout returns.",
         input: #"{ "panel": { "items": [] } }"#),

    Case(name: "panel-all-unknown-falls-back",
         note: "Same when every id is unrecognised.",
         input: #"{ "panel": { "items": ["nope", "alsoNope"] } }"#),

    Case(name: "panel-items-absent-keeps-defaults",
         note: "Absent items key is not the same as an empty list, but lands in the same place.",
         input: #"{ "panel": { "width": 60 } }"#),

    Case(name: "keyboard-custom-app",
         note: "KeyboardTarget persists as a tagged object; path only exists for the custom mode.",
         input: #"{ "commands": { "keyboard": { "mode": "customApp", "path": "/Applications/Some.app" } } }"#),

    Case(name: "keyboard-custom-app-without-path",
         note: "Custom mode with no path decodes to an empty path rather than throwing.",
         input: #"{ "commands": { "keyboard": { "mode": "customApp" } } }"#),

    Case(name: "keyboard-viewer",
         note: "The other named mode.",
         input: #"{ "commands": { "keyboard": { "mode": "keyboardViewer" } } }"#),

    Case(name: "keyboard-unknown-mode-falls-back",
         note: "An unknown mode falls back to the safe default instead of throwing.",
         input: #"{ "commands": { "keyboard": { "mode": "somethingElse" } } }"#),

    Case(name: "icon-style-system",
         note: "Enum stored by its raw value.",
         input: #"{ "appearance": { "iconStyle": "system" } }"#),

    Case(name: "orientation-horizontal",
         note: "The other panel orientation.",
         input: #"{ "panel": { "orientation": "horizontal" } }"#),

    Case(name: "legacy-idle-disarm",
         note: "Upgrades from before idleDisarmSeconds defaulted to 0 keep the old value — a real case from the user's own file.",
         input: #"{ "clicks": { "idleDisarmSeconds": 120 } }"#),

    Case(name: "calibration-enabled",
         note: "Adaptive dwell: the computed value replaces the manual one, so effectiveDwellMouseSeconds changes.",
         input: #"{ "calibration": { "enabled": true, "averageVelocity": 400, "multiplier": 76 }, "stillness": { "sensitivity": 1 } }"#),

    Case(name: "calibration-enabled-but-unmeasured",
         note: "Enabled with no measurement falls back to the manual dwell.",
         input: #"{ "calibration": { "enabled": true, "averageVelocity": 0 } }"#),
]

do {
    var out: [[String: Any]] = []

    for c in cases {
        let inputData = Data(c.input.utf8)
        let settings = try Settings.load(from: inputData)
        let encoded = try settings.jsonData()

        out.append([
            "name": c.name,
            "note": c.note,
            "input": try JSONSerialization.jsonObject(with: inputData),
            "output": try JSONSerialization.jsonObject(with: encoded),
            // Derived values that no amount of field-by-field comparison would catch,
            // because they come from the formula rather than from the document.
            "effectiveDwellMouseSeconds": settings.effectiveDwellMouseSeconds,
        ])
    }

    let json = try JSONSerialization.data(
        withJSONObject: out,
        options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(json)
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("SettingsGolden failed: \(error)\n".utf8))
    exit(1)
}
