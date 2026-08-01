namespace AllyClicker.Core;

// Ports that decouple the pure core from Win32 (ports-and-adapters). The core depends
// only on these; AllyClicker.App supplies the adapters (SendInput, GetCursorPos, panel
// hit-testing). This is what keeps the core buildable and testable on Linux/WSL, where
// no Windows API exists — the same role these protocols play in the Swift build.

/// <summary>
/// Injects synthetic mouse actions at the OS level.
/// </summary>
/// <remarks>
/// Windows adapter wraps <c>SendInput</c>. Every method must be fire-and-forget: the
/// dwell loop calls them directly and must never block on the target app (spec §3.5).
/// </remarks>
public interface IMouseInjector
{
    void Click(ClickAction action, Point at);
    void MouseDown(Point at);

    /// <summary>
    /// Left button held: report a drag to the given point. Needed between MouseDown and
    /// MouseUp so apps register a real drag/selection rather than a click that jumped.
    /// </summary>
    void MouseDragged(Point at);

    void MouseUp(Point at);
}

/// <summary>
/// Reports the current global cursor location. Windows adapter: <c>GetCursorPos</c>,
/// a system call that does not depend on any other app's window.
/// </summary>
public interface ICursorSampler
{
    Point Location { get; }
}

/// <summary>
/// Maps a screen point to the zone the cursor is in.
/// </summary>
/// <remarks>
/// CONTRACT: the buttons the adapter may report are exactly those in the panel's
/// configured item list, in that order. It must NEVER report a button that is not in
/// the list — the engine arms and fires whatever zone it receives, so a button removed
/// from the layout is only really gone once the mapper stops reporting it.
/// </remarks>
public interface IZoneMapper
{
    Zone ZoneAt(Point point);
}
