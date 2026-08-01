namespace AllyClicker.Core.Tests;

/// <summary>
/// What the golden fixture cannot see.
/// </summary>
/// <remarks>
/// The fixture only ever exercises decode-then-encode. These cases cover the paths that
/// reach the model some other way: objects built in code, <c>with</c> edits, equality,
/// and Normalize called directly — which is how the panel editor will call it in W5.
/// </remarks>
public class SettingsBehaviourTests
{
    // MARK: - The shared default layout

    [Fact]
    public void DefaultItems_CannotBeMutatedThroughItsInterface()
    {
        // DefaultItems is static and shared by every Settings instance. If the exposed
        // list is a plain array behind IReadOnlyList, a cast reaches the backing store
        // and one stray write corrupts the default layout for the whole process.
        Assert.False(
            PanelSettings.DefaultItems is PanelItem[],
            "DefaultItems is castable back to its backing array and can be written through.");
    }

    [Fact]
    public void DefaultItems_HasTheConfirmedLayout()
    {
        Assert.Equal(
            new[] { "togglePanel", "left", "right", "doubleClick", "leftDrag", "middle" },
            PanelSettings.DefaultItems.Select(i => i.Id));
    }

    // MARK: - Value semantics

    [Fact]
    public void With_LeavesTheOriginalUntouched()
    {
        // The reason the records are immutable: a settings-window edit must not reach the
        // running engine until Apply.
        var original = new Settings();
        var edited = original with { Timing = original.Timing with { DwellTimeMs = 999 } };

        Assert.Equal(320, original.Timing.DwellTimeMs);
        Assert.Equal(999, edited.Timing.DwellTimeMs);
        Assert.NotEqual(original, edited);
    }

    [Fact]
    public void Equality_IsByValue_AcrossNestedSections()
    {
        Assert.Equal(new Settings(), new Settings());

        var a = new Settings { Panel = new PanelSettings { Width = 70 } };
        var b = new Settings { Panel = new PanelSettings { Width = 70 } };
        Assert.Equal(a, b);
        Assert.NotEqual(a, new Settings());
    }

    [Fact]
    public void PanelSettings_EqualityAndHashCode_AgreeOnItemLists()
    {
        // Hand-written Equals/GetHashCode: they must stay consistent, or a Settings used
        // as a dictionary key starts missing its own entries.
        var a = new PanelSettings { Items = new PanelItem[] { new PanelItem.Action(ClickAction.Left) } };
        var b = new PanelSettings { Items = new PanelItem[] { new PanelItem.Action(ClickAction.Left) } };
        var c = new PanelSettings { Items = new PanelItem[] { new PanelItem.Action(ClickAction.Right) } };

        Assert.Equal(a, b);
        Assert.Equal(a.GetHashCode(), b.GetHashCode());
        Assert.NotEqual(a, c);
        Assert.True(a == b);
        Assert.False(a.Equals(null));
    }

    // MARK: - Encoding an object that was never decoded

    [Fact]
    public void ToJson_RoundTrips_ForAnObjectBuiltInCode()
    {
        // The fixture always decodes first, so this direction is otherwise untested.
        var settings = new Settings
        {
            Timing = new Timing { DwellTimeMs = 400, AutoSelectUpMs = 111 },
            Panel = new PanelSettings
            {
                Width = 64,
                PositionX = 12,
                Orientation = Orientation.Horizontal,
                Items = new PanelItem[]
                {
                    new PanelItem.Command(PanelCommand.TogglePanel),
                    new PanelItem.Action(ClickAction.Middle),
                },
            },
            Commands = new Commands { Keyboard = new KeyboardTarget.CustomApp("/opt/kbd") },
            Appearance = new Appearance { IconStyle = IconStyle.System, IconScale = 1.75 },
        };

        var restored = Settings.FromJson(settings.ToJson());

        Assert.Equal(settings, restored);
    }

    [Fact]
    public void ToJson_OmitsPositionX_WhenItIsNull()
    {
        // Absent — not null — is what the panel reads as "dock to the right edge".
        var json = new Settings().ToJson();

        Assert.DoesNotContain("positionX", json);
        Assert.Null(Settings.FromJson(json).Panel.PositionX);
    }

    [Fact]
    public void DecodedValues_SurviveTheJsonDocumentBeingDisposed()
    {
        // FromJson disposes its JsonDocument on the way out, and a JsonElement is only a
        // window onto that document's buffer. If any element escaped instead of being
        // read eagerly, these reads would return garbage rather than the tuned values.
        var settings = Settings.FromJson(
            """{ "appearance": { "clickSound": "Pop" }, "panel": { "items": ["left"] } }""");

        GC.Collect();
        GC.WaitForPendingFinalizers();

        Assert.Equal("Pop", settings.Appearance.ClickSound);
        Assert.Equal("left", settings.Panel.Items.Single().Id);
    }

    // MARK: - Normalize, called the way the panel editor will call it

    [Fact]
    public void Normalize_PinsOnOffFirst_WithoutReorderingTheRest()
    {
        var result = PanelSettings.Normalize(new PanelItem[]
        {
            new PanelItem.Action(ClickAction.Left),
            new PanelItem.Action(ClickAction.Right),
            new PanelItem.Command(PanelCommand.TogglePanel),
            new PanelItem.Action(ClickAction.Middle),
        });

        Assert.Equal(new[] { "togglePanel", "left", "right", "middle" }, result.Select(i => i.Id));
    }

    [Fact]
    public void Normalize_LeavesOnOffAloneWhenAbsent()
    {
        // ON/OFF is optional: removing it costs collapse and drag, but the tray icon
        // still reaches Settings, so it cannot lock anyone out.
        var result = PanelSettings.Normalize(new PanelItem[]
        {
            new PanelItem.Action(ClickAction.Left),
            new PanelItem.Action(ClickAction.Middle),
        });

        Assert.Equal(new[] { "left", "middle" }, result.Select(i => i.Id));
    }

    [Fact]
    public void Normalize_DropsDuplicatesKeepingFirstPosition()
    {
        var result = PanelSettings.Normalize(new PanelItem[]
        {
            new PanelItem.Action(ClickAction.Left),
            new PanelItem.Action(ClickAction.Right),
            new PanelItem.Action(ClickAction.Left),
            new PanelItem.Action(ClickAction.Middle),
        });

        Assert.Equal(new[] { "left", "right", "middle" }, result.Select(i => i.Id));
    }

    [Fact]
    public void Normalize_StripsKeyboard_AndFallsBackWhenNothingSurvives()
    {
        Assert.Equal(
            new[] { "togglePanel", "left" },
            PanelSettings.Normalize(new PanelItem[]
            {
                new PanelItem.Command(PanelCommand.TogglePanel),
                new PanelItem.Command(PanelCommand.LaunchKeyboard),
                new PanelItem.Action(ClickAction.Left),
            }).Select(i => i.Id));

        // A layout of nothing but KEYBOARD leaves an empty panel — fall back instead.
        Assert.Equal(
            PanelSettings.DefaultItems.Select(i => i.Id),
            PanelSettings.Normalize(new PanelItem[]
            {
                new PanelItem.Command(PanelCommand.LaunchKeyboard),
            }).Select(i => i.Id));

        Assert.Equal(
            PanelSettings.DefaultItems.Select(i => i.Id),
            PanelSettings.Normalize(Array.Empty<PanelItem>()).Select(i => i.Id));
    }

    [Fact]
    public void Normalize_DoesNotHandBackTheSharedDefaultForCallersToEdit()
    {
        // The empty case returns DefaultItems itself. If a caller can write to what it
        // gets back, the fallback path is a way to corrupt the shared default.
        var fallback = PanelSettings.Normalize(Array.Empty<PanelItem>());

        Assert.False(
            fallback is PanelItem[],
            "The fallback layout is castable back to a writable array.");
    }
}
