using System.Text;
using System.Text.Json;

namespace AllyClicker.Core;

/// <summary>
/// Behavioural settings. Port of <c>macos/Sources/AllyClickerCore/Settings.swift</c>.
/// </summary>
/// <remarks>
/// Defaults are the user's real tuned values, taken from their Point-N-Click 3.0.3.2
/// registry — not invented. Timings are stored as milliseconds; the <c>…Seconds</c>
/// properties are what drives timers.
///
/// The types are immutable records edited through <c>with</c> expressions. Swift models
/// them as structs, so assignment copies; a mutable C# class would have made a "copy"
/// share state with the original and let a settings-window edit leak into the running
/// engine before the user pressed Apply.
///
/// Decoding is deliberately forgiving — see <see cref="Json"/>. A file written by an
/// older build keeps the user's tuned values instead of silently resetting.
/// </remarks>
public sealed record Settings
{
    public Timing Timing { get; init; } = new();
    public Stillness Stillness { get; init; } = new();
    public Clicks Clicks { get; init; } = new();
    public AutoScroll AutoScroll { get; init; } = new();
    public Appearance Appearance { get; init; } = new();
    public PanelSettings Panel { get; init; } = new();
    public Commands Commands { get; init; } = new();
    public Calibration Calibration { get; init; } = new();

    /// <summary>
    /// Effective desktop auto-click dwell (seconds): the adaptive value when calibration
    /// is on and usable, otherwise the manual one.
    /// </summary>
    public double EffectiveDwellMouseSeconds
    {
        get
        {
            var computed = Calibration.ComputedDwellMs(Stillness.Sensitivity);
            return computed is { } ms ? ms / 1000.0 : Timing.DwellTimeMouseSeconds;
        }
    }

    public static Settings FromJson(string json)
    {
        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;

        return new Settings
        {
            Timing = Timing.FromJson(Json.Section(root, "timing")),
            Stillness = Stillness.FromJson(Json.Section(root, "stillness")),
            Clicks = Clicks.FromJson(Json.Section(root, "clicks")),
            AutoScroll = AutoScroll.FromJson(Json.Section(root, "autoScroll")),
            Appearance = Appearance.FromJson(Json.Section(root, "appearance")),
            Panel = PanelSettings.FromJson(Json.Section(root, "panel")),
            Commands = Commands.FromJson(Json.Section(root, "commands")),
            Calibration = Calibration.FromJson(Json.Section(root, "calibration")),
        };
    }

    public string ToJson()
    {
        var buffer = new MemoryStream();
        using (var writer = new Utf8JsonWriter(buffer, new JsonWriterOptions { Indented = true }))
        {
            writer.WriteStartObject();
            writer.WritePropertyName("timing"); this.Timing.Write(writer);
            writer.WritePropertyName("stillness"); this.Stillness.Write(writer);
            writer.WritePropertyName("clicks"); this.Clicks.Write(writer);
            writer.WritePropertyName("autoScroll"); this.AutoScroll.Write(writer);
            writer.WritePropertyName("appearance"); this.Appearance.Write(writer);
            writer.WritePropertyName("panel"); this.Panel.Write(writer);
            writer.WritePropertyName("commands"); this.Commands.Write(writer);
            writer.WritePropertyName("calibration"); this.Calibration.Write(writer);
            writer.WriteEndObject();
        }
        return Encoding.UTF8.GetString(buffer.ToArray());
    }
}

// MARK: - Timing

public sealed record Timing
{
    /// <summary>Dwell on a panel button before it is selected (ms).</summary>
    public int DwellTimeMs { get; init; } = 320;

    /// <summary>How long the cursor must stay still before an auto-click fires (ms).</summary>
    public int DwellTimeMouseMs { get; init; } = 195;

    /// <summary>DRAG phase 1: dwell at the start point before mouseDown (ms).</summary>
    public int AutoSelectDownMs { get; init; } = 320;

    /// <summary>DRAG phase 2: dwell at the end point before mouseUp (ms).</summary>
    public int AutoSelectUpMs { get; init; } = 210;

    public double DwellTimeSeconds => DwellTimeMs / 1000.0;
    public double DwellTimeMouseSeconds => DwellTimeMouseMs / 1000.0;
    public double AutoSelectDownSeconds => AutoSelectDownMs / 1000.0;
    public double AutoSelectUpSeconds => AutoSelectUpMs / 1000.0;

    internal static Timing FromJson(JsonElement e)
    {
        var d = new Timing();
        return new Timing
        {
            DwellTimeMs = Json.Int(e, "dwellTimeMs", d.DwellTimeMs),
            DwellTimeMouseMs = Json.Int(e, "dwellTimeMouseMs", d.DwellTimeMouseMs),
            AutoSelectDownMs = Json.Int(e, "autoSelectDownMs", d.AutoSelectDownMs),
            AutoSelectUpMs = Json.Int(e, "autoSelectUpMs", d.AutoSelectUpMs),
        };
    }

    internal void Write(Utf8JsonWriter w)
    {
        w.WriteStartObject();
        w.WriteNumber("dwellTimeMs", DwellTimeMs);
        w.WriteNumber("dwellTimeMouseMs", DwellTimeMouseMs);
        w.WriteNumber("autoSelectDownMs", AutoSelectDownMs);
        w.WriteNumber("autoSelectUpMs", AutoSelectUpMs);
        w.WriteEndObject();
    }
}

// MARK: - Stillness detection

public sealed record Stillness
{
    /// <summary>
    /// Movement tolerance in points. 1 = tightest. Crucial for head trackers — the
    /// head always trembles slightly, and without tolerance dwell never completes.
    /// </summary>
    public int Sensitivity { get; init; } = 1;

    /// <summary>Cursor sampling interval (ms). 5 = 200 Hz, matching PNC.</summary>
    public int TrackerIntervalMs { get; init; } = 5;

    /// <summary>
    /// Minimum movement (points) counting as "moved to a new target". Used twice:
    /// after a fire, to stop a parked cursor machine-gunning clicks; and after a
    /// drag's mouseDown, to prevent a zero-length drag.
    /// </summary>
    public int MoveRadiusPx { get; init; } = 10;

    internal static Stillness FromJson(JsonElement e)
    {
        var d = new Stillness();
        return new Stillness
        {
            Sensitivity = Json.Int(e, "sensitivity", d.Sensitivity),
            TrackerIntervalMs = Json.Int(e, "trackerIntervalMs", d.TrackerIntervalMs),
            MoveRadiusPx = Json.Int(e, "moveRadiusPx", d.MoveRadiusPx),
        };
    }

    internal void Write(Utf8JsonWriter w)
    {
        w.WriteStartObject();
        w.WriteNumber("sensitivity", Sensitivity);
        w.WriteNumber("trackerIntervalMs", TrackerIntervalMs);
        w.WriteNumber("moveRadiusPx", MoveRadiusPx);
        w.WriteEndObject();
    }
}

// MARK: - Click behaviour

/// <summary>
/// Click behaviour only. Which buttons appear is <see cref="PanelSettings.Items"/>.
/// </summary>
public sealed record Clicks
{
    /// <summary>After any action fires, revert the armed action to left click.</summary>
    public bool DefaultLeft { get; init; } = true;

    /// <summary>Cancel the armed action after one execution, rather than repeating.</summary>
    public bool AutoCancel { get; init; } = true;

    /// <summary>
    /// Auto-disarm after this many seconds without cursor movement. 0 = never.
    /// </summary>
    /// <remarks>
    /// Off by default on purpose: the armed action must persist until the user swipes
    /// it away or picks another. A silent timeout reads as the app switching itself
    /// off — e.g. while reading a page without moving — and confused more than it
    /// protected. Kept for anyone who wants it.
    /// </remarks>
    public int IdleDisarmSeconds { get; init; } = 0;

    internal static Clicks FromJson(JsonElement e)
    {
        var d = new Clicks();
        return new Clicks
        {
            DefaultLeft = Json.Bool(e, "defaultLeft", d.DefaultLeft),
            AutoCancel = Json.Bool(e, "autoCancel", d.AutoCancel),
            IdleDisarmSeconds = Json.Int(e, "idleDisarmSeconds", d.IdleDisarmSeconds),
        };
    }

    internal void Write(Utf8JsonWriter w)
    {
        w.WriteStartObject();
        w.WriteBoolean("defaultLeft", DefaultLeft);
        w.WriteBoolean("autoCancel", AutoCancel);
        w.WriteNumber("idleDisarmSeconds", IdleDisarmSeconds);
        w.WriteEndObject();
    }
}

// MARK: - Auto-scroll

/// <summary>
/// Middle-click auto-scroll tuning. Algorithm ported from LinearMouse (MIT).
/// </summary>
public sealed record AutoScroll
{
    /// <summary>Movement within this radius of the anchor produces no scroll.</summary>
    public double DeadZonePx { get; init; } = 10;

    /// <summary>Constant speed added once outside the dead zone (px/tick).</summary>
    public double Base { get; init; } = 0;

    /// <summary>Multiplier on sqrt(distance beyond the dead zone) — the ramp-up.</summary>
    public double Boost { get; init; } = 3;

    /// <summary>Cap on scroll delta per tick (px), against runaway speed.</summary>
    public double MaxSpeedPerTick { get; init; } = 160;

    /// <summary>
    /// User-facing speed multiplier. Below 1 is slower, above 1 faster.
    /// Clamped to 0.05...5.0 at decode time so a hand-edited file cannot invert or
    /// explode scrolling.
    /// </summary>
    public double Intensity { get; init; } = 0.5;

    public const double IntensityMin = 0.05;
    public const double IntensityMax = 5.0;

    internal static AutoScroll FromJson(JsonElement e)
    {
        var d = new AutoScroll();
        return new AutoScroll
        {
            DeadZonePx = Json.Double(e, "deadZonePx", d.DeadZonePx),
            Base = Json.Double(e, "base", d.Base),
            Boost = Json.Double(e, "boost", d.Boost),
            MaxSpeedPerTick = Json.Double(e, "maxSpeedPerTick", d.MaxSpeedPerTick),
            Intensity = Json.Clamp(
                Json.Double(e, "intensity", d.Intensity), IntensityMin, IntensityMax),
        };
    }

    internal void Write(Utf8JsonWriter w)
    {
        w.WriteStartObject();
        w.WriteNumber("deadZonePx", DeadZonePx);
        w.WriteNumber("base", Base);
        w.WriteNumber("boost", Boost);
        w.WriteNumber("maxSpeedPerTick", MaxSpeedPerTick);
        w.WriteNumber("intensity", Intensity);
        w.WriteEndObject();
    }
}

// MARK: - Appearance

public sealed record Appearance
{
    public bool Audio { get; init; } = true;

    /// <summary>Feedback volume, clamped to 0...1 at decode time.</summary>
    public double AudioVolume { get; init; } = 1.0;

    /// <summary>Name of the system sound played on click.</summary>
    public string ClickSound { get; init; } = "Tink";

    /// <summary>Brief expanding ripple at the cursor when a click or drag fires.</summary>
    public bool ClickFeedback { get; init; } = true;

    /// <summary>Panel opacity 0–255 (255 = opaque).</summary>
    public int Transparency { get; init; } = 255;

    public IconStyle IconStyle { get; init; } = IconStyle.Custom;

    /// <summary>
    /// Icon size multiplier per button. Clamped to 0.5...2.0 at decode time so a
    /// hand-edited value cannot shrink icons to nothing or blow them up.
    /// </summary>
    public double IconScale { get; init; } = 1.0;

    public const double IconScaleMin = 0.5;
    public const double IconScaleMax = 2.0;

    internal static Appearance FromJson(JsonElement e)
    {
        var d = new Appearance();
        return new Appearance
        {
            Audio = Json.Bool(e, "audio", d.Audio),
            AudioVolume = Json.Clamp(Json.Double(e, "audioVolume", d.AudioVolume), 0, 1),
            ClickSound = Json.String(e, "clickSound", d.ClickSound),
            ClickFeedback = Json.Bool(e, "clickFeedback", d.ClickFeedback),
            Transparency = Json.Int(e, "transparency", d.Transparency),
            IconStyle = IconStyleIds.Parse(Json.String(e, "iconStyle", IconStyleIds.Of(d.IconStyle)))
                        ?? d.IconStyle,
            IconScale = Json.Clamp(
                Json.Double(e, "iconScale", d.IconScale), IconScaleMin, IconScaleMax),
        };
    }

    internal void Write(Utf8JsonWriter w)
    {
        w.WriteStartObject();
        w.WriteBoolean("audio", Audio);
        w.WriteNumber("audioVolume", AudioVolume);
        w.WriteString("clickSound", ClickSound);
        w.WriteBoolean("clickFeedback", ClickFeedback);
        w.WriteNumber("transparency", Transparency);
        w.WriteString("iconStyle", IconStyleIds.Of(IconStyle));
        w.WriteNumber("iconScale", IconScale);
        w.WriteEndObject();
    }
}

// MARK: - Panel geometry and layout

/// <summary>
/// Panel layout and geometry. <see cref="Items"/> is the ordered, user-configurable
/// button list — its order IS the on-screen order.
/// </summary>
/// <remarks>
/// Named PanelSettings rather than Panel so it does not collide with
/// <see cref="Zone.Panel"/> at use sites.
/// </remarks>
public sealed record PanelSettings
{
    /// <summary>Panel width in points. Buttons are square, so also their height.</summary>
    public int Width { get; init; } = 50;

    /// <summary>Top-left Y, in points from the top of the screen.</summary>
    public int PositionY { get; init; } = 204;

    /// <summary>
    /// Top-left X. Null means dock to the right edge, which is the default until the
    /// user drags the panel somewhere — so null is meaningful, not missing.
    /// </summary>
    public int? PositionX { get; init; }

    public Orientation Orientation { get; init; } = Orientation.Vertical;

    /// <summary>Start with only the ON/OFF button showing.</summary>
    public bool LaunchCollapsed { get; init; } = false;

    public IReadOnlyList<PanelItem> Items { get; init; } = DefaultItems;

    /// <summary>
    /// Confirmed default layout, top to bottom: ON/OFF, LEFT, RIGHT, DOUBLE, DRAG,
    /// MIDDLE. KEYBOARD is deliberately absent — it moves to its own panel, and
    /// <see cref="Normalize"/> strips it from any layout.
    /// </summary>
    public static readonly IReadOnlyList<PanelItem> DefaultItems = new PanelItem[]
    {
        new PanelItem.Command(PanelCommand.TogglePanel),
        new PanelItem.Action(ClickAction.Left),
        new PanelItem.Action(ClickAction.Right),
        new PanelItem.Action(ClickAction.DoubleClick),
        new PanelItem.Action(ClickAction.LeftDrag),
        new PanelItem.Action(ClickAction.Middle),
    };

    internal static PanelSettings FromJson(JsonElement e)
    {
        var d = new PanelSettings();
        var ids = Json.StringArrayOrNull(e, "items");

        return new PanelSettings
        {
            Width = Json.Int(e, "width", d.Width),
            PositionY = Json.Int(e, "positionY", d.PositionY),
            PositionX = Json.IntOrNull(e, "positionX"),
            Orientation = OrientationIds.Parse(
                Json.String(e, "orientation", OrientationIds.Of(d.Orientation))) ?? d.Orientation,
            LaunchCollapsed = Json.Bool(e, "launchCollapsed", d.LaunchCollapsed),
            // Unknown ids are dropped, not fatal: one stray token from a newer build
            // must not discard the whole panel — which would take width and position
            // down with it.
            Items = ids is null
                ? d.Items
                : Normalize(ids.Select(PanelItem.FromId).OfType<PanelItem>()),
        };
    }

    /// <summary>
    /// Guarantees a usable layout: drops duplicates keeping the first occurrence,
    /// strips KEYBOARD, falls back to the default layout if nothing survives, and
    /// pins ON/OFF to the front when present.
    /// </summary>
    /// <remarks>
    /// ON/OFF is not forced in — the user may remove it. The panel then cannot be
    /// collapsed or dragged, but it is re-addable and Settings stays reachable from
    /// the tray icon, so this cannot lock anyone out.
    /// </remarks>
    public static IReadOnlyList<PanelItem> Normalize(IEnumerable<PanelItem> items)
    {
        var result = new List<PanelItem>();
        foreach (var item in items)
        {
            if (item is PanelItem.Command { Which: PanelCommand.LaunchKeyboard }) continue;
            if (result.Contains(item)) continue;
            result.Add(item);
        }

        if (result.Count == 0) return DefaultItems;

        var onOff = new PanelItem.Command(PanelCommand.TogglePanel);
        var index = result.IndexOf(onOff);
        if (index > 0)
        {
            result.RemoveAt(index);
            result.Insert(0, onOff);
        }

        return result;
    }

    internal void Write(Utf8JsonWriter w)
    {
        w.WriteStartObject();
        w.WriteNumber("width", Width);
        w.WriteNumber("positionY", PositionY);
        // Omitted entirely when null — Swift's optional encodes as an absent key,
        // and "absent" is what the panel reads as "dock right".
        if (PositionX is { } x) w.WriteNumber("positionX", x);
        w.WriteString("orientation", OrientationIds.Of(Orientation));
        w.WriteBoolean("launchCollapsed", LaunchCollapsed);
        w.WriteStartArray("items");
        foreach (var item in Items) w.WriteStringValue(item.Id);
        w.WriteEndArray();
        w.WriteEndObject();
    }

    // Records compare reference-typed members by reference, which would make two
    // otherwise-identical panels unequal. The ported tests rely on value equality.
    public bool Equals(PanelSettings? other) =>
        other is not null
        && Width == other.Width
        && PositionY == other.PositionY
        && PositionX == other.PositionX
        && Orientation == other.Orientation
        && LaunchCollapsed == other.LaunchCollapsed
        && Items.SequenceEqual(other.Items);

    public override int GetHashCode()
    {
        var hash = new HashCode();
        hash.Add(Width);
        hash.Add(PositionY);
        hash.Add(PositionX);
        hash.Add(Orientation);
        hash.Add(LaunchCollapsed);
        foreach (var item in Items) hash.Add(item);
        return hash.ToHashCode();
    }
}

// MARK: - Commands

public sealed record Commands
{
    /// <summary>
    /// What the KEYBOARD button launches. Defaults to the built-in accessibility
    /// keyboard — the likeliest fit for a hands-free user.
    /// </summary>
    public KeyboardTarget Keyboard { get; init; } = KeyboardTarget.AccessibilityKeyboard.Instance;

    internal static Commands FromJson(JsonElement e) => new()
    {
        Keyboard = KeyboardTarget.FromJson(Json.Section(e, "keyboard")),
    };

    internal void Write(Utf8JsonWriter w)
    {
        w.WriteStartObject();
        w.WritePropertyName("keyboard");
        Keyboard.Write(w);
        w.WriteEndObject();
    }
}

// MARK: - Adaptive dwell calibration

/// <summary>
/// Adaptive dwell, confirmed by the PNC author: PNC does not set the desktop dwell
/// directly, it computes it from a per-user baseline speed measurement.
/// </summary>
/// <remarks>
/// <c>DwellTimeMouse = multiplier * sensitivity / averageVelocity</c>. Slower movers
/// get a longer dwell — that auto-adaptation is what makes PNC comfortable for hours.
/// The arithmetic lives here; measuring the baseline speed belongs to the app.
/// <see cref="Multiplier"/> is a placeholder and must be re-tuned against real
/// measured velocities. Off by default, so the manual value is used.
/// </remarks>
public sealed record Calibration
{
    public bool Enabled { get; init; } = false;

    /// <summary>Per-user cursor speed from the baseline test (points/sec). 0 = unmeasured.</summary>
    public double AverageVelocity { get; init; } = 0;

    public double Multiplier { get; init; } = 76;

    internal static Calibration FromJson(JsonElement e)
    {
        var d = new Calibration();
        return new Calibration
        {
            Enabled = Json.Bool(e, "enabled", d.Enabled),
            AverageVelocity = Json.Double(e, "averageVelocity", d.AverageVelocity),
            Multiplier = Json.Double(e, "multiplier", d.Multiplier),
        };
    }

    /// <summary>
    /// Dwell in ms from the formula, or null when calibration cannot produce a usable
    /// value (off, or velocity not measured yet). Floored at 1ms.
    /// </summary>
    public int? ComputedDwellMs(int sensitivity)
    {
        if (!Enabled || AverageVelocity <= 0) return null;
        var ms = Multiplier * sensitivity / AverageVelocity;
        // Swift's Int(...) truncates toward zero, which is not what a C# cast to int
        // does for negatives — but the floor at 1 makes the two agree anyway.
        return Math.Max(1, (int)ms);
    }

    internal void Write(Utf8JsonWriter w)
    {
        w.WriteStartObject();
        w.WriteBoolean("enabled", Enabled);
        w.WriteNumber("averageVelocity", AverageVelocity);
        w.WriteNumber("multiplier", Multiplier);
        w.WriteEndObject();
    }
}
