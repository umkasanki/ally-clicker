namespace AllyClicker.Core;

/// <summary>
/// What the app should do this tick. Port of <c>DwellEngine.Effect</c>.
/// </summary>
/// <remarks>
/// Same closed-hierarchy shape as <see cref="Zone"/>, and for the same reason: the
/// engine returns a list of these and the ported tests assert on that list as a whole,
/// which only works because records compare by value.
/// </remarks>
public abstract record Effect
{
    private Effect() { }

    /// <summary>The armed action changed (null = nothing armed).</summary>
    public sealed record SetArmed(ClickAction? Action) : Effect;

    /// <summary>
    /// Dwell countdown 0...1 on a panel button.
    /// </summary>
    /// <remarks>
    /// Emitted for completeness, but the panel deliberately does NOT draw a countdown
    /// indicator — user preference, they are used to working without one (spec §2).
    /// Kept so the feature can be switched on later without touching the engine.
    /// </remarks>
    public sealed record DwellProgress(ClickAction Button, double Fraction) : Effect;

    public sealed record ClearProgress : Effect
    {
        public static readonly ClearProgress Instance = new();
    }

    /// <summary>Perform the click.</summary>
    public sealed record Fire(ClickAction Action, Point At) : Effect;

    /// <summary>DRAG phase 1 committed: press and hold.</summary>
    public sealed record DragMouseDown(Point At) : Effect;

    /// <summary>DRAG held and the cursor moved — stream a drag event so apps see it.</summary>
    public sealed record DragMouseMoved(Point At) : Effect;

    /// <summary>DRAG phase 2 committed, or cancelled: release.</summary>
    public sealed record DragMouseUp(Point At) : Effect;

    /// <summary>A one-shot panel command fired (ON/OFF, KEYBOARD).</summary>
    public sealed record RunCommand(PanelCommand Command) : Effect;
}
