import Foundation

// MARK: - Point
//
// Platform-independent 2D point. The core engine deliberately avoids CoreGraphics
// (which does not exist on Linux) so it can be unit-tested anywhere. The macOS app
// layer converts between CGPoint and Point at the adapter boundary.

public struct Point: Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Point(x: 0, y: 0)

    /// Euclidean distance to another point.
    public func distance(to other: Point) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

// MARK: - Rect
//
// Enough of a rectangle to decide where a panel may sit, in the same
// platform-independent spirit as `Point`: the app converts from NSRect at the
// boundary. Bottom-left origin, matching AppKit, because that is the only
// consumer and converting twice would invite the sign error it is meant to
// prevent.

public struct Rect: Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }

    /// Wholly inside `other`.
    public func fits(in other: Rect) -> Bool {
        x >= other.x && y >= other.y && maxX <= other.maxX && maxY <= other.maxY
    }
}

// MARK: - Where the panel may sit

public enum PanelPlacement {

    /// Does the panel fit, whole, inside any of these visible areas?
    ///
    /// Whole, not merely overlapping: half a panel off the edge is as unusable
    /// as all of it, and harder to notice.
    public static func fits(_ frame: Rect, in visibleFrames: [Rect]) -> Bool {
        visibleFrames.contains { frame.fits(in: $0) }
    }

    /// Where the panel goes when its remembered position cannot be honoured:
    /// against the right edge, centred vertically — or centred along the top
    /// when it is lying horizontally.
    public static func rescueOrigin(horizontal: Bool, panelW: Double, panelH: Double,
                                    screenFrame: Rect) -> Point {
        horizontal
            ? Point(x: screenFrame.midX - panelW / 2, y: screenFrame.maxY - panelH)
            : Point(x: screenFrame.maxX - panelW, y: screenFrame.midY - panelH / 2)
    }

    /// The origin to place the panel at, given what the user last chose.
    ///
    /// A remembered position is only worth honouring if it still lands somewhere
    /// visible. This application's user changes desktop size often — the
    /// monitor's cable moves between two machines and three buttons switch its
    /// resolution — so a position saved on a wide desktop is routinely off the
    /// right edge of a narrow one.
    public static func origin(savedX: Int?, savedY: Int, horizontal: Bool,
                              panelW: Double, panelH: Double,
                              screenFrame: Rect, visibleFrames: [Rect]) -> Point {
        if let savedX {
            let saved = Point(x: screenFrame.x + Double(savedX),
                              y: screenFrame.maxY - Double(savedY) - panelH)
            let frame = Rect(x: saved.x, y: saved.y, width: panelW, height: panelH)
            if fits(frame, in: visibleFrames) { return saved }
            return rescueOrigin(horizontal: horizontal, panelW: panelW, panelH: panelH,
                                screenFrame: screenFrame)
        }
        if horizontal {
            return Point(x: screenFrame.midX - panelW / 2, y: screenFrame.maxY - panelH)
        }
        return Point(x: screenFrame.maxX - panelW,
                     y: screenFrame.maxY - Double(savedY) - panelH)
    }
}
