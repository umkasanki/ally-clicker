import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AllyClickerCore

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    // Curated short macOS system sounds for the click cue.
    // The three bundled first: picked for this job and trimmed for it. The
    // macOS built-ins stay as a fallback.
    private let builtInClickSounds = ["Press", "Tick", "Select", "Tap", "Tock",
                                      "Blip", "Snap", "Knock", "Pluck", "Soft", "Thud",
                                      "Tink", "Pop", "Morse", "Bottle", "Purr"]
    // No "Tink", "Tap" or "Tock" here: those are the click's own family, and
    // arming is supposed to sound like a different event, not a quieter click.
    private let builtInArmSounds = ["Soft", "Tap", "Blip", "Tock", "Snap", "Knock",
                                    "Pluck", "Thud", "Purr", "Bottle", "Blow", "Morse",
                                    "Frog", "Pop", SoundPlayer.silentArmSound]

    // The user's own sounds come after ours in both lists, so the familiar
    // entries never move when a file is added or removed.
    private var clickSounds: [String] { builtInClickSounds + userSounds }
    private var armSounds: [String] { builtInArmSounds + userSounds }
    @State private var userSounds: [String] = SoundPlayer.userSoundNames()
    @State private var soundPreview: NSSound?   // retained so the preview finishes playing

    // Int(ms) binding shown/edited in seconds.
    private func seconds(_ ms: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(ms.wrappedValue) / 1000 },
                set: { ms.wrappedValue = Int(($0 * 1000).rounded()) })
    }
    // Int binding as Double (for ValueControl).
    private func asDouble(_ i: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(i.wrappedValue) }, set: { i.wrappedValue = Int($0.rounded()) })
    }
    // Int(seconds) binding shown/edited in minutes.
    private func minutes(_ s: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(s.wrappedValue) / 60 },
                set: { s.wrappedValue = Int(($0 * 60).rounded()) })
    }
    // 0.0–1.0 binding shown/edited as a percentage.
    private func percent01(_ b: Binding<Double>) -> Binding<Double> {
        Binding(get: { (b.wrappedValue * 100).rounded() },
                set: { b.wrappedValue = $0 / 100 })
    }

    private enum Tab { case behavior, panel, effects, about }
    @State private var tab: Tab = .behavior

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                behaviorTab
                    .tabItem { Label("Behavior", systemImage: "slider.horizontal.3") }
                    .tag(Tab.behavior)
                PanelEditorView(model: model)
                    .tabItem { Label("Panel", systemImage: "square.grid.3x1.below.line.grid.1x2") }
                    .tag(Tab.panel)
                effectsTab
                    .tabItem { Label("Effects", systemImage: "wand.and.sparkles") }
                    .tag(Tab.effects)
                AboutView()
                    .tabItem { Label("About", systemImage: "info.circle") }
                    .tag(Tab.about)
            }
            .padding(.top, 8)
            // Changes auto-save; the footer just offers reset + close.
            if tab != .about {
                Divider()
                HStack {
                    Button("Reset to defaults") { model.resetToDefaults() }
                    Spacer()
                    Button("Done") { model.done() }.keyboardShortcut(.defaultAction)
                }
                .padding(12)
            }
        }
        .frame(width: 740, height: 720)
    }

    private var behaviorTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                    section("Clicking", intro: "Arm an action on the panel, then hold the cursor still over your target. When it stays put for the AutoMouse Delay, the action fires at that spot.") {
                        ValueControl(title: "AutoMouse Delay", value: seconds($model.settings.timing.dwellTimeMouseMs),
                                     range: 0.10...1.50, step: 0.01, unit: "s", decimals: 2,
                                     help: "How long to hold the cursor still on the screen before the armed action fires.")
                        ValueControl(title: "Panel button", value: seconds($model.settings.timing.dwellTimeMs),
                                     range: 0.10...1.50, step: 0.01, unit: "s", decimals: 2,
                                     help: "How long to dwell on a panel button to select it.")
                        toggleRow("Default to Left Click", $model.settings.clicks.defaultLeft,
                                  help: "After any action fires, automatically re-arm Left click.")
                        toggleRow("Automatic Cancel", $model.settings.clicks.autoCancel,
                                  help: "Clear the armed action after one execution (otherwise it repeats on each stop).")
                        ValueControl(title: "Idle-disarm", value: minutes($model.settings.clicks.idleDisarmSeconds),
                                     range: 0...15, step: 1, unit: "min",
                                     help: "Optional safety: clear the armed action after this long with no cursor movement. 0 = never (default) — the armed action then stays until you swipe it away or pick another.")
                    }
                    section("Drag", intro: "With Drag armed, hold still at the start point until the button presses down (Drag press), move to the destination, then hold still again until it releases (Drag release). Used for dragging and selecting.") {
                        ValueControl(title: "Drag press", value: seconds($model.settings.timing.autoSelectDownMs),
                                     range: 0.10...1.50, step: 0.01, unit: "s", decimals: 2,
                                     help: "Dwell at the start point before Drag presses the mouse button down.")
                        ValueControl(title: "Drag release", value: seconds($model.settings.timing.autoSelectUpMs),
                                     range: 0.10...1.50, step: 0.01, unit: "s", decimals: 2,
                                     help: "Dwell at the end point before Drag releases the mouse button.")
                    }
                    section("Scroll & Links", intro: "The MIDDLE action does two things depending on where the cursor is. Over a link: opens it in a new tab (middle click). Over empty page area: starts auto-scroll — an anchor drops where you stopped, and the page scrolls in the direction you move the cursor away from it, the farther out the faster. Move back toward the anchor to slow down. To stop, hold the cursor still anywhere — a left click fires and scrolling ends.") {
                        ValueControl(title: "Intensity", value: $model.settings.autoScroll.intensity,
                                     range: 0.25...3.0, step: 0.25, unit: "×", decimals: 2,
                                     help: "Scroll speed multiplier. Lower = slower and easier to control; higher = faster.")
                    }
                    section("Cursor precision", intro: "How steady the cursor must be to count as \"holding still\". These apply to every action above — raise them if head-tracker tremor triggers actions too early or ends drags by accident.") {
                        ValueControl(title: "Jitter tolerance", value: asDouble($model.settings.stillness.sensitivity),
                                     range: 1...10, step: 1,
                                     help: "How much cursor tremor still counts as holding still. Higher = more forgiving for shaky control.")
                        ValueControl(title: "Move threshold", value: asDouble($model.settings.stillness.moveRadiusPx),
                                     range: 4...30, step: 1, unit: "pt",
                                     help: "Minimum movement (points) counted as a real move — resets timers and ends a drag's first phase.")
                    }
                    section("Startup") {
                        toggleRow("Launch at login", $model.launchAtLogin,
                                  help: "Start AllyClicker automatically when you log in. Applies immediately.")
                    }
            }
            .padding(20)
        }
    }

    private var effectsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("Sound", intro: "Confirmation cues you can hear — helpful when you can't feel the mouse button.") {
                    toggleRow("Sound feedback", $model.settings.appearance.audio,
                              help: "Play a short sound when you arm a panel button and when a click fires.")
                }
                section("Click sound", intro: "Played when a click or drag fires.") {
                    soundRow("Sound", selection: $model.settings.appearance.clickSound,
                             options: clickSounds, preview: previewClickSound)
                    ValueControl(title: "Volume", value: percent01($model.settings.appearance.audioVolume),
                                 range: 0...100, step: 5, unit: "%",
                                 help: "Loudness of the click sound.")
                }
                .disabled(!model.settings.appearance.audio)
                .opacity(model.settings.appearance.audio ? 1 : 0.5)
                section("Arming sound", intro: "Played when the dwell lands on a panel button, a moment before the click. It is the second cue of the pair, so it belongs under the click rather than beside it — \"None\" turns it off.") {
                    soundRow("Sound", selection: $model.settings.appearance.armSound,
                             options: armSounds, preview: previewArmSound)
                    ValueControl(title: "Volume", value: percent01($model.settings.appearance.armVolume),
                                 range: 0...100, step: 5, unit: "%",
                                 help: "Loudness of the arming sound.")
                }
                .disabled(!model.settings.appearance.audio)
                .opacity(model.settings.appearance.audio ? 1 : 0.5)
                section("Visual feedback", intro: "A cue you can see, independent of the sounds above.") {
                    toggleRow("Visual click feedback", $model.settings.appearance.clickFeedback,
                              help: "Show a brief ripple at the cursor when a click or drag fires.")
                }
            }
            .padding(20)
        }
    }

    /// One "pick a sound, hear it" row — the same control for the click and for
    /// arming, so the two groups cannot drift apart in looks or behaviour.
    private func soundRow(_ title: String,
                          selection: Binding<String>,
                          options: [String],
                          preview: @escaping (String) -> Void) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 15)).frame(width: 175, alignment: .leading)
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 150)
            .onChange(of: selection.wrappedValue) { _, name in preview(name) }
            Button { preview(selection.wrappedValue) } label: {
                Image(systemName: "play.circle")
            }
            .buttonStyle(.borderless)
            .help("Preview")
            Button { addSound(into: selection, preview: preview) } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .help("Add a sound file of your own")
            Button { NSWorkspace.shared.open(SoundPlayer.userSoundsDirectory) } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Open the folder holding your own sounds")
            Spacer()
        }
    }

    /// Let the user pick an audio file, copy it in, and select it straight away —
    /// adding a sound you then have to find in a list is two steps where one will
    /// do, and this list is aimed at with a head tracker.
    private func addSound(into selection: Binding<String>, preview: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = SoundPlayer.playableExtensions
            .compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.message = "Pick a sound file. It is copied into AllyClicker, so moving the original later is safe."
        guard panel.runModal() == .OK, let source = panel.url else { return }
        // Refuse here rather than let a silent name into the list: NSSound opens
        // WAV, AIFF, MP3, M4A and CAF, and nothing else.
        guard NSSound(contentsOf: source, byReference: false) != nil else {
            report("That file cannot be played",
                   "AllyClicker can use WAV, AIFF, MP3, M4A and CAF. OGG and FLAC are not supported by macOS here.")
            return
        }
        do {
            let name = try SoundPlayer.importUserSound(from: source)
            userSounds = SoundPlayer.userSoundNames()
            selection.wrappedValue = name
            preview(name)
        } catch {
            report("Could not add the sound", error.localizedDescription)
        }
    }

    private func report(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }

    private func previewArmSound(_ name: String) {
        let s = SoundPlayer.makeArmSound(name)
        s?.volume = SoundPlayer.level(model.settings.appearance.armVolume)
        soundPreview = s
        s?.play()
    }

    private func previewClickSound(_ name: String) {
        let s = SoundPlayer.makeClickSound(name)
        s?.volume = SoundPlayer.level(model.settings.appearance.audioVolume)
        soundPreview = s
        s?.play()
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, intro: String = "", @ViewBuilder _ content: @escaping () -> Content) -> some View {
        SettingsSection(title: title, intro: intro, content: content)
    }

    private func toggleRow(_ title: String, _ isOn: Binding<Bool>, help: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle(title, isOn: isOn).font(.system(size: 15))
            Text(help)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
