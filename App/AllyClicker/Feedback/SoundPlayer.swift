import AppKit

// Light audio feedback for panel/click actions. Uses the built-in macOS system
// sounds (no bundled assets). Gated by Settings.appearance.audio.
final class SoundPlayer {
    var enabled: Bool = true

    // Prebuilt instances; stop+play lets rapid actions retrigger without lag.
    private let click = NSSound(named: NSSound.Name("Tink"))
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
}
