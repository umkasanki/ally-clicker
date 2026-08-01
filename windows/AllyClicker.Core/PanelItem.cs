namespace AllyClicker.Core;

/// <summary>
/// One button slot on the panel. The layout is a user-configurable ordered list of
/// these — adding or removing a button is editing that list. Port of <c>PanelItem</c>.
/// </summary>
/// <remarks>
/// Persisted as a single stable string ("left", "leftDrag", "togglePanel"…) so the JSON
/// stays readable. NB the Swift file's comment illustrates these ids as "drag"/"onoff",
/// which are not the real values — the raw values are the case names. <see cref="Id"/>
/// follows the actual data, not that comment.
/// </remarks>
public abstract record PanelItem
{
    private PanelItem() { }

    public sealed record Action(ClickAction Which) : PanelItem;

    public sealed record Command(PanelCommand Which) : PanelItem;

    /// <summary>
    /// Stable id used for persistence. Unique across actions and commands, which is
    /// what lets a single string identify either kind.
    /// </summary>
    public string Id => this switch
    {
        Action a => ClickActionIds.Of(a.Which),
        Command c => PanelCommandIds.Of(c.Which),
        _ => throw new InvalidOperationException($"Unhandled panel item: {this}"),
    };

    /// <summary>
    /// Parses an id, or returns null if it names neither an action nor a command.
    /// Callers drop unknown ids rather than throwing — one bad token from a newer
    /// build must not discard the whole saved layout.
    /// </summary>
    public static PanelItem? FromId(string id)
    {
        if (ClickActionIds.Parse(id) is { } action) return new Action(action);
        if (PanelCommandIds.Parse(id) is { } command) return new Command(command);
        return null;
    }
}
