namespace AllyClicker.Core.Tests;

/// <summary>
/// W1 representation spike. Swift models Zone, Effect and PanelItem as enums with
/// associated values; C# has no equivalent, and the choice made here fixes the shape of
/// DwellEngine, DwellController and all 75 ported tests. These cases exist to judge that
/// choice at the call site before the rest of the port is written on top of it.
/// </summary>
public class RepresentationTests
{
    // The ported engine tests assert on whole effect lists. That only works if effects
    // compare by value — which is the main reason for records over a class hierarchy.

    [Fact]
    public void Effects_CompareByValue()
    {
        Assert.Equal(new Effect.SetArmed(ClickAction.Left), new Effect.SetArmed(ClickAction.Left));
        Assert.NotEqual<Effect>(new Effect.SetArmed(ClickAction.Left), new Effect.SetArmed(ClickAction.Right));
        Assert.NotEqual<Effect>(new Effect.SetArmed(ClickAction.Left), new Effect.SetArmed(null));

        Assert.Equal(
            new Effect.Fire(ClickAction.Middle, new Point(10, 20)),
            new Effect.Fire(ClickAction.Middle, new Point(10, 20)));
    }

    [Fact]
    public void EffectLists_CompareAsWholes()
    {
        // The shape a ported DwellEngine test will actually take.
        var effects = new Effect[]
        {
            new Effect.SetArmed(ClickAction.Left),
            new Effect.Fire(ClickAction.Left, new Point(100, 200)),
            Effect.ClearProgress.Instance,
        };

        Assert.Equal(new Effect[]
        {
            new Effect.SetArmed(ClickAction.Left),
            new Effect.Fire(ClickAction.Left, new Point(100, 200)),
            new Effect.ClearProgress(),
        }, effects);
    }

    [Fact]
    public void Zones_CompareByValue_AndDistinguishChromeFromButton()
    {
        Assert.Equal(Zone.Desktop.Instance, new Zone.Desktop());

        // panel(button: nil) — chrome — is a different zone from a button.
        Assert.NotEqual<Zone>(new Zone.Panel(null), new Zone.Panel(ClickAction.Left));
        Assert.Equal(new Zone.Panel(null), new Zone.Panel(null));

        Assert.NotEqual<Zone>(new Zone.Panel(ClickAction.Left), Zone.Desktop.Instance);
        Assert.Equal(
            new Zone.Command(PanelCommand.TogglePanel),
            new Zone.Command(PanelCommand.TogglePanel));
    }

    [Fact]
    public void PatternMatching_ReadsLikeTheSwiftSwitch()
    {
        // Stands in for the app layer's effect router, which is where this shape has to
        // stay legible: positional deconstruction gives the same feel as Swift's
        // `case .fire(let action, let at)`.
        static string Describe(Effect effect) => effect switch
        {
            Effect.SetArmed(null) => "disarm",
            Effect.SetArmed(var action) => $"arm {action}",
            Effect.Fire(var action, var at) => $"fire {action} at {at.X},{at.Y}",
            Effect.DwellProgress(var button, var fraction) => $"progress {button} {fraction}",
            Effect.ClearProgress => "clear",
            Effect.DragMouseDown(var at) => $"down at {at.X},{at.Y}",
            Effect.DragMouseMoved(var at) => $"moved at {at.X},{at.Y}",
            Effect.DragMouseUp(var at) => $"up at {at.X},{at.Y}",
            Effect.RunCommand(var command) => $"run {command}",
            _ => throw new InvalidOperationException($"Unhandled effect: {effect}"),
        };

        Assert.Equal("disarm", Describe(new Effect.SetArmed(null)));
        Assert.Equal("arm Left", Describe(new Effect.SetArmed(ClickAction.Left)));
        Assert.Equal("fire Middle at 10,20", Describe(new Effect.Fire(ClickAction.Middle, new Point(10, 20))));
        Assert.Equal("clear", Describe(Effect.ClearProgress.Instance));
        Assert.Equal("run TogglePanel", Describe(new Effect.RunCommand(PanelCommand.TogglePanel)));
    }

    [Fact]
    public void Hierarchies_AreClosed()
    {
        // The private base constructor is what makes a switch over the cases genuinely
        // exhaustive, the way a Swift enum is. Nothing outside these files can add a case.
        Assert.All(
            new[] { typeof(Zone), typeof(Effect), typeof(PanelItem) },
            t => Assert.Empty(t.GetConstructors()));
    }
}
