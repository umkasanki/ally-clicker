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

    /// Resolve an arming sound. Always a macOS system sound — the click's own
    /// family (`Tink`, `Tap`, `Tock`) is deliberately not offered here, because
    /// two clicks in a row read as one event.
    static func makeArmSound(_ name: String) -> NSSound? {
        guard name != silentArmSound else { return nil }
        return NSSound(named: NSSound.Name(name))
    }

    /// Custom click sounds bundled in Resources/Sounds, beyond the macOS built-ins.
    static let bundledClickSounds = ["Tock", "Tap", "Press", "Tick", "Select"]

    /// Resolve a click-sound name: a bundled `.wav` if we ship one, else a macOS
    /// system sound. Used by the player and by the settings preview.
    static func makeClickSound(_ name: String) -> NSSound? {
        if bundledClickSounds.contains(name),
           let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds") {
            return NSSound(contentsOf: url, byReference: false)
        }
        return NSSound(named: NSSound.Name(name))
    }
}
