import AppKit

// Light audio feedback for panel/click actions. Uses the built-in macOS system
// sounds (no bundled assets). Gated by Settings.appearance.audio.
final class SoundPlayer {
    var enabled: Bool = true

    /// Playback volume 0.0–1.0.
    var volume: Float = 1.0 {
        didSet { click?.volume = volume; arm?.volume = volume }
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
    private let arm = NSSound(named: NSSound.Name("Pop"))

    /// A click / drag-release fired.
    func playClick() { play(click) }

    /// A panel button was armed (selected).
    func playArm() { play(arm) }

    private func play(_ sound: NSSound?) {
        guard enabled, let sound else { return }
        if sound.isPlaying { sound.stop() }
        sound.play()
    }

    /// Custom click sounds bundled in Resources/Sounds, beyond the macOS built-ins.
    static let bundledClickSounds = ["Tock", "Tap"]

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
