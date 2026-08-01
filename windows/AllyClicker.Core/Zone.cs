namespace AllyClicker.Core;

/// <summary>
/// Where the cursor is right now. Port of <c>DwellEngine.Zone</c>.
/// </summary>
/// <remarks>
/// Swift models this as an enum with associated values, which C# has no direct
/// equivalent for. A closed hierarchy of records is the nearest thing: the private
/// constructor means only the nested cases below can derive from it (so a switch over
/// them really is exhaustive, as in Swift), and record value-equality is what lets the
/// ported tests compare zones and effects directly instead of picking them apart.
/// </remarks>
public abstract record Zone
{
    private Zone() { }

    /// <summary>Anywhere outside the panel — the only zone the engine fires clicks in.</summary>
    public sealed record Desktop : Zone
    {
        /// <summary>Cached: the sampler reports this on almost every tick.</summary>
        public static readonly Desktop Instance = new();
    }

    /// <summary>
    /// Over the panel. <paramref name="Button"/> is null for panel chrome (the gap
    /// between buttons), otherwise the arming click button under the cursor.
    /// </summary>
    public sealed record Panel(ClickAction? Button) : Zone;

    /// <summary>Over a one-shot command button (ON/OFF, KEYBOARD).</summary>
    public sealed record Command(PanelCommand Which) : Zone;
}
