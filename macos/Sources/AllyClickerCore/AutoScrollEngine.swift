import Foundation

// MARK: - AutoScrollEngine
//
// Pure math for middle-click auto-scroll. Given the anchor point (set when the
// user activated scroll) and the current cursor, it returns the scroll delta for
// this tick. Non-linear ramp ported from LinearMouse (MIT):
//
//   speed = base + sqrt(distance - deadZone) * boost   (clamped to maxSpeedPerTick)
//
// The square root is generalised to a power (Acceleration): the ramp is
// normalised at accelerationReferencePx, so 0.5 is exactly the formula above and
// a higher power is slower near the anchor and faster far from it.
//
// Each axis is computed independently, so diagonal scrolling works naturally.
// This engine is sign-agnostic about scroll direction in the screen sense — it
// returns a delta whose sign follows the cursor offset (cursor below/right of the
// anchor → positive). The macOS adapter decides how that maps to a CGScrollWheel
// event (natural vs. reversed scrolling).

public struct AutoScrollEngine {
    public var config: Settings.AutoScroll

    public init(config: Settings.AutoScroll = Settings.AutoScroll()) {
        self.config = config
    }

    /// Scroll delta for this tick. dx follows horizontal offset, dy vertical.
    public func delta(anchor: Point, cursor: Point) -> (dx: Double, dy: Double) {
        (dx: axisDelta(cursor.x - anchor.x),
         dy: axisDelta(cursor.y - anchor.y))
    }

    private func axisDelta(_ offset: Double) -> Double {
        let distance = abs(offset)
        guard distance > config.deadZonePx else { return 0 }
        let adjusted = distance - config.deadZonePx
        let ref = Settings.AutoScroll.accelerationReferencePx
        let ramp = ref.squareRoot() * pow(adjusted / ref, config.accelerationExponent)
        let raw = (config.base + ramp * config.boost) * config.intensity
        // Clamp LAST so maxSpeedPerTick always bounds the final delta, whatever
        // the intensity multiplier is (prevents runaway scroll).
        let speed = min(raw, config.maxSpeedPerTick)
        return offset < 0 ? -speed : speed
    }
}
