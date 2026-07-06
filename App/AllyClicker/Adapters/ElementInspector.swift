import ApplicationServices
import AllyClickerCore

// Inspects the accessibility element under the cursor to decide MIDDLE behavior:
// over a link → plain middle click (open in new tab); otherwise → auto-scroll.
// Uses the Accessibility API (top-left global coordinates, same as our Point).
// Requires Accessibility permission (already granted for clicks).

enum ElementInspector {
    /// True if the element under `point` (or a near ancestor) is a hyperlink.
    static func isLink(at point: Point) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element)
        guard err == .success, var current = element else { return false }

        // Walk a few ancestors: a link's text/image child is what's hit-tested.
        for _ in 0..<6 {
            if role(of: current) == "AXLink" || subrole(of: current) == "AXLink" {
                return true
            }
            guard let parent = parent(of: current) else { break }
            current = parent
        }
        return false
    }

    private static func role(of el: AXUIElement) -> String? {
        string(el, kAXRoleAttribute)
    }

    private static func subrole(of el: AXUIElement) -> String? {
        string(el, kAXSubroleAttribute)
    }

    private static func string(_ el: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func parent(of el: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &value) == .success,
              let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }
}
