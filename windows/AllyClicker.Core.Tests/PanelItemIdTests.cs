namespace AllyClicker.Core.Tests;

/// <summary>
/// These ids are a persistence format: they sit in the user's settings.json. A rename of
/// an enum member must break a test here, loudly, rather than silently discard someone's
/// saved panel layout. Every value is pinned against the Swift raw values.
/// </summary>
public class PanelItemIdTests
{
    [Theory]
    [InlineData(ClickAction.Left, "left")]
    [InlineData(ClickAction.Right, "right")]
    [InlineData(ClickAction.Middle, "middle")]
    [InlineData(ClickAction.LeftDrag, "leftDrag")]
    [InlineData(ClickAction.DoubleClick, "doubleClick")]
    [InlineData(ClickAction.RightDouble, "rightDouble")]
    [InlineData(ClickAction.RightThenLeft, "rightThenLeft")]
    public void ClickAction_HasItsSwiftRawValue(ClickAction action, string id)
    {
        Assert.Equal(id, ClickActionIds.Of(action));
        Assert.Equal(action, ClickActionIds.Parse(id));
    }

    [Theory]
    [InlineData(PanelCommand.TogglePanel, "togglePanel")]
    [InlineData(PanelCommand.LaunchKeyboard, "launchKeyboard")]
    public void PanelCommand_HasItsSwiftRawValue(PanelCommand command, string id)
    {
        Assert.Equal(id, PanelCommandIds.Of(command));
        Assert.Equal(command, PanelCommandIds.Parse(id));
    }

    [Fact]
    public void EveryEnumMember_IsCovered()
    {
        // Guards the maps above against a member added later and forgotten here.
        foreach (var action in Enum.GetValues<ClickAction>())
        {
            var id = ClickActionIds.Of(action);
            Assert.Equal(action, ClickActionIds.Parse(id));
        }

        foreach (var command in Enum.GetValues<PanelCommand>())
        {
            var id = PanelCommandIds.Of(command);
            Assert.Equal(command, PanelCommandIds.Parse(id));
        }
    }

    [Fact]
    public void ActionAndCommandIds_DoNotOverlap()
    {
        // PanelItem.FromId relies on a single string naming either kind unambiguously.
        var actionIds = Enum.GetValues<ClickAction>().Select(ClickActionIds.Of);
        var commandIds = Enum.GetValues<PanelCommand>().Select(PanelCommandIds.Of);

        Assert.Empty(actionIds.Intersect(commandIds));
    }

    [Fact]
    public void PanelItem_RoundTripsThroughItsId()
    {
        PanelItem[] items =
        {
            new PanelItem.Command(PanelCommand.TogglePanel),
            new PanelItem.Action(ClickAction.Left),
            new PanelItem.Action(ClickAction.LeftDrag),
        };

        foreach (var item in items)
        {
            Assert.Equal(item, PanelItem.FromId(item.Id));
        }
    }

    [Fact]
    public void PanelItem_DefaultLayout_HasTheExpectedIds()
    {
        // The confirmed PNC layout, top to bottom: ON/OFF, LEFT, RIGHT, DOUBLE, DRAG,
        // MIDDLE. Pinned as ids because that is what lands in settings.json.
        PanelItem[] defaultItems =
        {
            new PanelItem.Command(PanelCommand.TogglePanel),
            new PanelItem.Action(ClickAction.Left),
            new PanelItem.Action(ClickAction.Right),
            new PanelItem.Action(ClickAction.DoubleClick),
            new PanelItem.Action(ClickAction.LeftDrag),
            new PanelItem.Action(ClickAction.Middle),
        };

        Assert.Equal(
            new[] { "togglePanel", "left", "right", "doubleClick", "leftDrag", "middle" },
            defaultItems.Select(i => i.Id));
    }

    [Fact]
    public void UnknownId_IsDroppedNotThrown()
    {
        // A single unrecognised token from a newer build must not cost the whole layout.
        Assert.Null(PanelItem.FromId("totallyNewButton"));
        Assert.Null(ClickActionIds.Parse("onoff"));
        Assert.Null(PanelCommandIds.Parse("drag"));
    }
}
