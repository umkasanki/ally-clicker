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
