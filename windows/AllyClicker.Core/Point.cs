namespace AllyClicker.Core;

/// <summary>
/// Platform-independent 2D point.
/// </summary>
/// <remarks>
/// The core deliberately avoids <c>System.Windows.Point</c> and the Win32 <c>POINT</c>
/// struct, exactly as the Swift twin avoids CoreGraphics: that is what keeps the engine
/// unit-testable off Windows. The app layer converts at the adapter boundary.
/// Port of <c>macos/Sources/AllyClickerCore/Geometry.swift</c>.
/// </remarks>
public readonly record struct Point(double X, double Y)
{
    public static readonly Point Zero = new(0, 0);

    /// <summary>Euclidean distance to another point.</summary>
    public double DistanceTo(Point other)
    {
        var dx = X - other.X;
        var dy = Y - other.Y;
        return Math.Sqrt(dx * dx + dy * dy);
    }
}
