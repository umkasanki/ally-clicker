namespace AllyClicker.Core;

/// <summary>
/// One-shot panel commands — buttons that perform an immediate action on dwell instead
/// of arming a click. Port of <c>DwellEngine.Command</c>.
/// </summary>
public enum PanelCommand
{
    /// <summary>ON/OFF — collapse / expand the panel.</summary>
    TogglePanel,

    /// <summary>KEYBOARD — launch the configured app.</summary>
    LaunchKeyboard,
}

/// <summary>
/// Stable persistence ids for <see cref="PanelCommand"/>. Same contract as
/// <see cref="ClickActionIds"/>: hand-written, pinned by tests, must match Swift.
/// </summary>
public static class PanelCommandIds
{
    public static string Of(PanelCommand command) => command switch
    {
        PanelCommand.TogglePanel => "togglePanel",
        PanelCommand.LaunchKeyboard => "launchKeyboard",
        _ => throw new ArgumentOutOfRangeException(nameof(command), command, null),
    };

    /// <summary>Returns null for an unknown id — callers drop it rather than throwing.</summary>
    public static PanelCommand? Parse(string id) => id switch
    {
        "togglePanel" => PanelCommand.TogglePanel,
        "launchKeyboard" => PanelCommand.LaunchKeyboard,
        _ => null,
    };
}
