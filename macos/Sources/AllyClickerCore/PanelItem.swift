import Foundation

// MARK: - PanelItem
//
// One button slot on the panel. The panel layout is a user-configurable ordered
// list of these — adding/removing a button = editing Settings.panel.items.
//
// A panel button is either an arming click action (left, right, drag, double,
// middle…) or a one-shot command (ON/OFF, KEYBOARD). PanelItem unifies both so a
// single ordered list describes the whole panel.

public enum PanelItem: Equatable, Hashable {
    case action(DwellEngine.Action)
    case command(DwellEngine.Command)

    /// Stable string id used for persistence (matches the underlying raw values,
    /// which are unique across Action and Command).
    public var id: String {
        switch self {
        case .action(let a):  return a.rawValue
        case .command(let c): return c.rawValue
        }
    }

    public init?(id: String) {
        if let a = DwellEngine.Action(rawValue: id) { self = .action(a); return }
        if let c = DwellEngine.Command(rawValue: id) { self = .command(c); return }
        return nil
    }
}

// Persist as a single stable string ("left", "drag", "onoff"…) for clean JSON.
extension PanelItem: Codable {
    public init(from decoder: Decoder) throws {
        let id = try decoder.singleValueContainer().decode(String.self)
        guard let item = PanelItem(id: id) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown panel item id: \(id)"))
        }
        self = item
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(id)
    }
}
