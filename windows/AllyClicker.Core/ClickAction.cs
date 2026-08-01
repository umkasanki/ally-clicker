namespace AllyClicker.Core;

/// <summary>
/// Which click type is selected / will fire.
/// </summary>
/// <remarks>
/// Port of <c>DwellEngine.Action</c>. Renamed from "Action" because that name collides
/// with <c>System.Action</c> at every use site in C#.
/// </remarks>
public enum ClickAction
{
    Left,
    Right,
    Middle,
    LeftDrag,
    DoubleClick,

    // Not implemented in the injector yet — see backlog item I4. Present so the
    // persisted layout of an older/newer build still round-trips.
    RightDouble,
    RightThenLeft,
}

/// <summary>
/// Stable persistence ids for <see cref="ClickAction"/>.
/// </summary>
/// <remarks>
/// These strings live in the user's settings.json and MUST match the Swift raw values
/// (which are the case names) exactly. The mapping is written out by hand rather than
/// derived from a naming policy on purpose: a rename of an enum member would silently
/// change the persisted id, and the user's saved layout would quietly disappear.
/// ClickActionIdTests pins every one of them.
/// </remarks>
public static class ClickActionIds
{
    public static string Of(ClickAction action) => action switch
    {
        ClickAction.Left => "left",
        ClickAction.Right => "right",
        ClickAction.Middle => "middle",
        ClickAction.LeftDrag => "leftDrag",
        ClickAction.DoubleClick => "doubleClick",
        ClickAction.RightDouble => "rightDouble",
        ClickAction.RightThenLeft => "rightThenLeft",
        _ => throw new ArgumentOutOfRangeException(nameof(action), action, null),
    };

    /// <summary>Returns null for an unknown id — callers drop it rather than throwing.</summary>
    public static ClickAction? Parse(string id) => id switch
    {
        "left" => ClickAction.Left,
        "right" => ClickAction.Right,
        "middle" => ClickAction.Middle,
        "leftDrag" => ClickAction.LeftDrag,
        "doubleClick" => ClickAction.DoubleClick,
        "rightDouble" => ClickAction.RightDouble,
        "rightThenLeft" => ClickAction.RightThenLeft,
        _ => null,
    };
}
