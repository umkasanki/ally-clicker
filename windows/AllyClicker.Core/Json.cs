using System.Text.Json;

namespace AllyClicker.Core;

/// <summary>
/// Reading helpers that reproduce Swift's <c>decodeIfPresent</c> semantics.
/// </summary>
/// <remarks>
/// The whole settings model is decoded by hand rather than by attributes, because the
/// contract differs from System.Text.Json's defaults in one consequential way: Swift
/// treats an explicit <c>null</c> exactly like an absent key and falls back to the
/// default, where STJ throws when binding null to a non-nullable value type. A
/// settings.json carrying a null would take the app down on startup — for a user whose
/// only input device this is, that is not a recoverable situation.
///
/// A wrong-typed value still throws, matching Swift, where <c>decodeIfPresent</c>
/// returns nil only for absent-or-null and raises <c>typeMismatch</c> otherwise.
/// NB that particular rule is read off the Swift source rather than pinned by the golden
/// fixture, which only covers documents that decode successfully.
/// </remarks>
internal static class Json
{
    /// <summary>The property, or null when absent or explicitly null.</summary>
    private static JsonElement? Present(JsonElement parent, string name)
    {
        if (parent.ValueKind != JsonValueKind.Object) return null;
        if (!parent.TryGetProperty(name, out var value)) return null;
        return value.ValueKind == JsonValueKind.Null ? null : value;
    }

    /// <summary>A nested object, or an empty object so its own defaults apply.</summary>
    public static JsonElement Section(JsonElement parent, string name)
    {
        var found = Present(parent, name);
        if (found is { ValueKind: JsonValueKind.Object } obj) return obj;
        if (found is { } wrong) throw Mismatch(name, "object", wrong.ValueKind);
        return EmptyObject;
    }

    public static int Int(JsonElement parent, string name, int fallback) =>
        IntOrNull(parent, name) ?? fallback;

    /// <summary>For genuinely optional numbers, where null carries meaning.</summary>
    public static int? IntOrNull(JsonElement parent, string name)
    {
        if (Present(parent, name) is not { } value) return null;
        if (value.ValueKind != JsonValueKind.Number || !value.TryGetInt32(out var i))
            throw Mismatch(name, "int", value.ValueKind);
        return i;
    }

    public static double Double(JsonElement parent, string name, double fallback)
    {
        if (Present(parent, name) is not { } value) return fallback;
        if (value.ValueKind != JsonValueKind.Number || !value.TryGetDouble(out var d))
            throw Mismatch(name, "double", value.ValueKind);
        return d;
    }

    public static bool Bool(JsonElement parent, string name, bool fallback)
    {
        if (Present(parent, name) is not { } value) return fallback;
        return value.ValueKind switch
        {
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            _ => throw Mismatch(name, "bool", value.ValueKind),
        };
    }

    public static string String(JsonElement parent, string name, string fallback)
    {
        if (Present(parent, name) is not { } value) return fallback;
        if (value.ValueKind != JsonValueKind.String)
            throw Mismatch(name, "string", value.ValueKind);
        return value.GetString()!;
    }

    /// <summary>Null when absent — lets callers distinguish "no list" from "empty list".</summary>
    public static IReadOnlyList<string>? StringArrayOrNull(JsonElement parent, string name)
    {
        if (Present(parent, name) is not { } value) return null;
        if (value.ValueKind != JsonValueKind.Array)
            throw Mismatch(name, "array", value.ValueKind);

        var result = new List<string>();
        foreach (var element in value.EnumerateArray())
        {
            if (element.ValueKind != JsonValueKind.String)
                throw Mismatch(name, "array of strings", element.ValueKind);
            result.Add(element.GetString()!);
        }
        return result;
    }

    /// <summary>Clamp, applied while decoding so a hand-edited file can never arm a bad value.</summary>
    public static double Clamp(double value, double min, double max) =>
        value < min ? min : value > max ? max : value;

    private static readonly JsonElement EmptyObject =
        JsonDocument.Parse("{}").RootElement.Clone();

    private static JsonException Mismatch(string name, string expected, JsonValueKind actual) =>
        new($"Settings key '{name}': expected {expected}, found {actual}.");
}
