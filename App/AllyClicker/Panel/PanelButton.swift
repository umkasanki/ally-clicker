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
        let image = item.projectIcon ?? NSImage(systemSymbolName: item.sfSymbolName,
                                                accessibilityDescription: item.id)
        NSLog("AllyClicker: button \(item.id) icon=\(item.projectIcon != nil ? "custom" : "sf-fallback")")
        iconView.image = image
        iconView.contentTintColor = .labelColor
        addSubview(iconView)
    }

    // Frame-based layout (no Auto Layout inside the borderless panel).
    override func layout() {
        super.layout()
        let size: CGFloat = iconSize
        iconView.frame = NSRect(x: (bounds.width - size) / 2,
                                y: (bounds.height - size) / 2,
                                width: size, height: size)
    }

    /// Per-button glyph sizes: ON/OFF is the primary control (largest),
    /// KEYBOARD slightly larger than the click glyphs.
    private var iconSize: CGFloat {
        switch item {
        case .command(.togglePanel):    return 48
        case .command(.launchKeyboard): return 42
        default:                        return 36
        }
    }

    // The button itself is transparent — the container draws the panel background
    // and owns the sliding red pill (see PanelViewController). The button only
    // hosts the icon and switches its tint.
    override func draw(_ dirtyRect: NSRect) {
        iconView.contentTintColor = isArmed ? .white : .labelColor
        super.draw(dirtyRect)
    }
}

extension PanelItem {
    /// Project icon (vector PDF from Resources/icons), template-tinted.
    /// nil → fall back to an SF Symbol.
    var projectIcon: NSImage? {
        guard let name = projectIconName,
              let url = Bundle.main.url(forResource: name, withExtension: "pdf",
                                        subdirectory: "icons"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true  // monochrome glyph → tintable via contentTintColor
        return image
    }

    private var projectIconName: String? {
        switch self {
        case .action(.left):        return "click-left"
        case .action(.right):       return "click-right"
        case .action(.leftDrag):    return "drag"
        case .action(.doubleClick): return "click-double"
        case .action(.middle):      return "wheel"
        case .command(.togglePanel):    return "power"
        case .command(.launchKeyboard): return "keyboard"
        default:                    return nil
        }
    }

    /// SF Symbol fallback for items without a project icon.
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
