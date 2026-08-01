using System.Text.Json;

namespace AllyClicker.Core;

/// <summary>
/// What the KEYBOARD button launches. Persists as <c>{ "mode": "…", "path": "…" }</c>,
/// with the path present only for the custom mode.
/// </summary>
public abstract record KeyboardTarget
{
    private KeyboardTarget() { }

    /// <summary>The platform's built-in accessibility keyboard.</summary>
    public sealed record AccessibilityKeyboard : KeyboardTarget
    {
        public static readonly AccessibilityKeyboard Instance = new();
    }

    /// <summary>The standard on-screen virtual keyboard.</summary>
    public sealed record KeyboardViewer : KeyboardTarget
    {
        public static readonly KeyboardViewer Instance = new();
    }

    /// <summary>A third-party app, by path or identifier.</summary>
    public sealed record CustomApp(string Path) : KeyboardTarget;

    internal static KeyboardTarget FromJson(JsonElement e)
    {
        // The mode is read leniently on purpose: Swift wraps it in `try?`, so an absent,
        // unknown or wrong-typed mode all land on the safe default rather than taking
        // the whole settings file down with them.
        var mode = ReadModeLeniently(e);

        return mode switch
        {
            "keyboardViewer" => KeyboardViewer.Instance,
            // The path, unlike the mode, is not lenient — a wrong-typed path throws,
            // matching the Swift decoder.
            "customApp" => new CustomApp(Json.String(e, "path", "")),
            _ => AccessibilityKeyboard.Instance,
        };
    }

    private static string ReadModeLeniently(JsonElement e)
    {
        try
        {
            return Json.String(e, "mode", "accessibilityKeyboard");
        }
        catch (JsonException)
        {
            return "accessibilityKeyboard";
        }
    }

    internal void Write(Utf8JsonWriter w)
    {
        w.WriteStartObject();
        switch (this)
        {
            case AccessibilityKeyboard:
                w.WriteString("mode", "accessibilityKeyboard");
                break;
            case KeyboardViewer:
                w.WriteString("mode", "keyboardViewer");
                break;
            case CustomApp custom:
                w.WriteString("mode", "customApp");
                w.WriteString("path", custom.Path);
                break;
            default:
                throw new InvalidOperationException($"Unhandled keyboard target: {this}");
        }
        w.WriteEndObject();
    }
}
