namespace AllyClicker.Core;

/// <summary>Which icon set the panel buttons use.</summary>
public enum IconStyle
{
    /// <summary>The project's own vector glyphs.</summary>
    Custom,

    /// <summary>The platform's stock symbol set.</summary>
    System,
}

/// <summary>Panel layout direction.</summary>
public enum Orientation
{
    Vertical,
    Horizontal,
}

/// <summary>Persistence ids — hand-written and test-pinned, like the other id tables.</summary>
public static class IconStyleIds
{
    public static string Of(IconStyle style) => style switch
    {
        IconStyle.Custom => "custom",
        IconStyle.System => "system",
        _ => throw new ArgumentOutOfRangeException(nameof(style), style, null),
    };

    public static IconStyle? Parse(string id) => id switch
    {
        "custom" => IconStyle.Custom,
        "system" => IconStyle.System,
        _ => null,
    };
}

/// <summary>Persistence ids for <see cref="Orientation"/>.</summary>
public static class OrientationIds
{
    public static string Of(Orientation orientation) => orientation switch
    {
        Orientation.Vertical => "vertical",
        Orientation.Horizontal => "horizontal",
        _ => throw new ArgumentOutOfRangeException(nameof(orientation), orientation, null),
    };

    public static Orientation? Parse(string id) => id switch
    {
        "vertical" => Orientation.Vertical,
        "horizontal" => Orientation.Horizontal,
        _ => null,
    };
}
