import AppKit
import AllyClickerCore

// A single panel button. Shows an icon and two visual states:
//   • normal — plain background
//   • armed  — red background (the currently selected click action)
// No dwell countdown is rendered (out of scope by user preference, spec §2).

final class PanelButton: NSView {
    let item: PanelItem

    private let iconView = NSImageView()

    var isArmed: Bool = false {
        didSet { needsDisplay = true }
    }

    init(item: PanelItem) {
        self.item = item
        super.init(frame: .zero)
        wantsLayer = true
        setupIcon()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func setupIcon() {
        iconView.imageScaling = .scaleProportionallyUpOrDown
        let image = NSImage(systemSymbolName: item.sfSymbolName,
                            accessibilityDescription: item.id)
        NSLog("AllyClicker: button \(item.id) symbol \(item.sfSymbolName) image=\(image == nil ? "NIL" : "ok")")
        iconView.image = image
        iconView.contentTintColor = .labelColor
        addSubview(iconView)
    }

    // Frame-based layout (no Auto Layout inside the borderless panel).
    override func layout() {
        super.layout()
        let size: CGFloat = 30
        iconView.frame = NSRect(x: (bounds.width - size) / 2,
                                y: (bounds.height - size) / 2,
                                width: size, height: size)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Background per state — semantic colors resolve via the window's darkAqua
        // appearance, so this stays native-dark without hardcoded colors.
        (isArmed ? NSColor.systemRed : NSColor.windowBackgroundColor).setFill()
        bounds.fill()
        // Icon tint: white when armed for contrast, else primary label color.
        iconView.contentTintColor = isArmed ? .white : .labelColor
        super.draw(dirtyRect)
    }
}

// SF Symbol mapping — placeholder glyphs. The prepared custom icons
// (references/point-n-click/icons) get wired via the asset catalog in Xcode later.
extension PanelItem {
    var sfSymbolName: String {
        switch self {
        case .action(.left):        return "cursorarrow.click"
        case .action(.right):       return "cursorarrow.click.2"
        case .action(.leftDrag):    return "hand.draw"
        case .action(.doubleClick): return "cursorarrow.click.badge.clock"
        case .action(.middle):      return "circle.circle"
        case .action(.rightDouble): return "cursorarrow.click.2"
        case .action(.rightThenLeft): return "cursorarrow.and.square.on.square.dashed"
        case .command(.togglePanel):    return "power"
        case .command(.launchKeyboard): return "keyboard"
        }
    }
}
