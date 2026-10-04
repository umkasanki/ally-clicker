import AppKit

// Light audio feedback for panel/click actions. Uses the built-in macOS system
// sounds (no bundled assets). Gated by Settings.appearance.audio.
final class SoundPlayer {
    var enabled: Bool = true

    /// Playback volume 0.0–1.0 for the click.
    var volume: Float = 1.0 {
        didSet { click?.volume = volume }
    }

    /// Volume for the arming sound, apart from the click's so the confirmation
    /// can sit under it rather than beside it.
    var armVolume: Float = 0.3 {
        didSet { arm?.volume = armVolume }
    }

    /// Arming sound name; `silentArmSound` means play nothing.
    var armSoundName: String = "Purr" {
        didSet {
            guard armSoundName != oldValue else { return }
            arm = SoundPlayer.makeArmSound(armSoundName)
            arm?.volume = armVolume
        }
    }

    /// Click sound name (a bundled .wav or a macOS system sound); reloads on change.
    var clickSoundName: String = "Tink" {
        didSet {
            guard clickSoundName != oldValue else { return }
            click = SoundPlayer.makeClickSound(clickSoundName) ?? click
            click?.volume = volume
        }
    }

    // Prebuilt instances; stop+play lets rapid actions retrigger without lag.
    private var click = SoundPlayer.makeClickSound("Tink")
    private var arm = SoundPlayer.makeArmSound("Purr")

    /// A click / drag-release fired.
    func playClick() { play(click) }

    /// A panel button was armed (selected).
    func playArm() { play(arm) }

    private func play(_ sound: NSSound?) {
        guard enabled, let sound else { return }
        if sound.isPlaying { sound.stop() }
        sound.play()
    }

    /// The loudest these cues are ever allowed to be, as a fraction of the system
    /// sound's own level.
    ///
    /// They are confirmations, not alarms: the useful range runs from silence to
    /// quiet, and a slider whose top end startles you has wasted most of its
    /// travel. NSSound takes a linear amplitude while hearing is logarithmic, so
    /// at full level the entire usable range was crammed into the first few
    /// percent — 5% was comfortable, 20% was too loud to work beside. Capped
    /// here, the whole slider is usable and that comfortable setting sits at the
    /// 25% mark with headroom left above it.
    static let maxVolume: Float = 0.20

    /// Turn a stored 0...1 setting into the level actually handed to NSSound.
    /// Everything that plays one of these sounds goes through here, the previews
    /// in Settings included — a preview louder than the real thing is worse than
    /// no preview at all.
    static func level(_ setting: Double) -> Float {
        Float(min(max(setting, 0), 1)) * maxVolume
    }

    /// The arming-sound entry that means silence.
    static let silentArmSound = "None"

    /// Resolve an arming sound. The list offered in Settings leaves out the
    /// click's own family (`Tink`, `Tap`, `Tock`), because two clicks in a row
    /// read as one event — but a sound the user added themselves is their call.
    static func makeArmSound(_ name: String) -> NSSound? {
        guard name != silentArmSound else { return nil }
        return resolve(name)
    }

    /// Resolve a click sound. Same lookup as arming: the two cues differ in which
    /// names Settings offers, not in where a name is looked up.
    static func makeClickSound(_ name: String) -> NSSound? { resolve(name) }

    /// Sounds shipped in Resources/Sounds, beyond the macOS built-ins.
    static let bundledClickSounds = ["Tock", "Tap", "Press", "Tick", "Select"]

    // MARK: - The user's own sounds

    /// Where sounds the user adds are kept. Outside the bundle so they survive a
    /// reinstall, and outside the repository so nobody has to wonder what licence
    /// a file in it carries — the sounds that prompted this feature came from a
    /// commercial keyboard whose licence forbids redistributing its parts.
    static var userSoundsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AllyClicker/Sounds", isDirectory: true)
    }

    /// What NSSound can actually open. OGG and FLAC are not on the list, and a
    /// name in the picker that plays nothing is worse than no name at all.
    static let playableExtensions = ["wav", "aiff", "aif", "mp3", "m4a", "caf"]

    /// Names of the user's own sounds, alphabetically. Read fresh rather than
    /// cached: the folder is theirs to change behind our back.
    static func userSoundNames() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: userSoundsDirectory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { playableExtensions.contains($0.pathExtension.lowercased()) }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private static func userSoundURL(_ name: String) -> URL? {
        for ext in playableExtensions {
            let url = userSoundsDirectory.appendingPathComponent(name).appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    /// The user's own file first, then one we ship, then a macOS system sound.
    ///
    /// A name that resolves to nothing stays silent and keeps its place in the
    /// setting: delete the file and the cue goes quiet, put it back and it
    /// returns. Quietly substituting another sound would hide the loss.
    private static func resolve(_ name: String) -> NSSound? {
        if let url = userSoundURL(name) {
            return NSSound(contentsOf: url, byReference: false)
        }
        if bundledClickSounds.contains(name),
           let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") {
            return NSSound(contentsOf: url, byReference: false)
        }
        return NSSound(named: NSSound.Name(name))
    }

    /// Copy a chosen file into the user's sounds folder and return the name it
    /// landed under. Copied rather than referenced, so the setting keeps working
    /// after the original is moved or deleted.
    ///
    /// A name that would shadow one of ours gets a number appended: one entry in
    /// the picker must never mean two different sounds.
    static func importUserSound(from source: URL) throws -> String {
        let dir = userSoundsDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = source.pathExtension
        let base = source.deletingPathExtension().lastPathComponent
        var name = base
        var n = 2
        while bundledClickSounds.contains(name)
                || name == silentArmSound
                || userSoundURL(name) != nil {
            name = "\(base) \(n)"
            n += 1
        }
        try FileManager.default.copyItem(
            at: source, to: dir.appendingPathComponent(name).appendingPathExtension(ext))
        return name
    }
}
